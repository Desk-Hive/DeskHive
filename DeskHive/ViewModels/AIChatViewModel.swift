//
//  AIChatViewModel.swift
//  DeskHive
//
//  RAG-powered chat grounded on project docs.
//  Flow:
//    1. Load all chunks for the selected community.
//    2. On each user message, embed the query with OpenAI.
//    3. Rank chunks by cosine similarity, pick top-K context.
//    4. Send a chat-completion request with context injected as a system message.
//    5. Stream the assistant reply back to the UI.
//

import Foundation
import Combine
import FirebaseFirestore

// MARK: - Message model

struct ChatMessage: Identifiable {
    enum Role { case user, assistant, system }
    let id = UUID()
    let role: Role
    var text: String
    var isStreaming: Bool = false
}

// MARK: - ViewModel

@MainActor
class AIChatViewModel: ObservableObject {

    @Published var messages: [ChatMessage] = []
    @Published var isThinking = false
    @Published var errorMessage: String?
    @Published var chunksReady = false

    private var chunks: [DocChunk] = []
    private let db = Firestore.firestore()

    // ── OpenAI config ────────────────────────────────────────────────────
    // Same key used by EmbeddingService; move to a secure backend in production.
    private let apiKey = EmbeddingService.openAIKey
    private let chatURL = URL(string: "https://api.openai.com/v1/chat/completions")!
    private let chatModel = "gpt-4o-mini"
    private let topK = 6        // how many chunks to inject as context

    // MARK: - Load chunks for a community

    func loadChunks(communityID: String) async {
        chunksReady = false
        errorMessage = nil
        do {
            let docVM = ProjectDocViewModel()
            chunks = try await docVM.fetchChunks(communityID: communityID)
            chunksReady = true
            if chunks.isEmpty {
                messages.append(ChatMessage(
                    role: .assistant,
                    text: "⚠️ No documents have been embedded for this project yet. Ask your Project Lead to upload docs first."))
            } else {
                messages.append(ChatMessage(
                    role: .assistant,
                    text: "Hi! I'm your project AI assistant. I've loaded **\(chunks.count) knowledge chunks** from your project docs. Ask me anything about the project! 🚀"))
            }
        } catch {
            errorMessage = "Failed to load project docs: \(error.localizedDescription)"
            messages.append(ChatMessage(
                role: .assistant,
                text: "❌ Could not load project documents. Please try again later."))
        }
    }

    // MARK: - Send a message

    func send(userText: String) async {
        guard !userText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !isThinking else { return }

        let userMsg = ChatMessage(role: .user, text: userText)
        messages.append(userMsg)
        isThinking = true
        errorMessage = nil

        defer { isThinking = false }

        // 1. Embed the query
        let queryVec: [Float]
        do {
            queryVec = try await EmbeddingService.embed(text: userText)
        } catch let error as EmbeddingError {
            switch error {
            case .networkError(let underlying):
                appendError("Network error: \(underlying.localizedDescription)")
            case .badResponse(let code):
                if code == 401 {
                    appendError("Invalid OpenAI API key. Please contact your admin.")
                } else {
                    appendError("OpenAI API error (HTTP \(code))")
                }
            case .decodingError:
                appendError("Could not parse OpenAI response")
            case .emptyResult:
                appendError("OpenAI returned no embedding")
            }
            return
        } catch {
            appendError("Could not embed your question: \(error.localizedDescription)")
            return
        }

        // 2. Rank chunks
        let contextText: String
        if chunks.isEmpty {
            contextText = "(No project documents are available.)"
        } else {
            let ranked = chunks
                .map { ($0, EmbeddingService.cosineSimilarity(queryVec, $0.embedding)) }
                .sorted { $0.1 > $1.1 }
                .prefix(topK)
                .map { $0.0.text }
            contextText = ranked.enumerated()
                .map { "[\($0.offset + 1)] \($0.element)" }
                .joined(separator: "\n\n")
        }

        // 3. Build messages array for chat API
        let systemPrompt = """
        You are an intelligent assistant for the DeskHive workspace app. \
        You answer questions strictly based on the project documents provided below. \
        If the answer is not found in the documents, say so clearly instead of guessing. \
        Be concise, professional, and helpful. Format your answers with markdown when useful.

        --- PROJECT DOCUMENT CONTEXT ---
        \(contextText)
        --- END OF CONTEXT ---
        """

        var apiMessages: [[String: String]] = [
            ["role": "system", "content": systemPrompt]
        ]
        // Include recent conversation history (last 10 turns) for continuity
        let history = messages.dropLast() // exclude the user msg we just added
        let recent = history.suffix(10)
        for msg in recent {
            switch msg.role {
            case .user:      apiMessages.append(["role": "user",      "content": msg.text])
            case .assistant: apiMessages.append(["role": "assistant", "content": msg.text])
            case .system:    break
            }
        }
        apiMessages.append(["role": "user", "content": userText])

        // 4. Call OpenAI chat completions
        let body: [String: Any] = [
            "model": chatModel,
            "messages": apiMessages,
            "temperature": 0.3,
            "max_tokens": 1024,
            "stream": false
        ]

        var request = URLRequest(url: chatURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            appendError("Failed to encode request.")
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                let raw = String(data: data, encoding: .utf8) ?? ""
                appendError("OpenAI error \(http.statusCode): \(raw)")
                return
            }
            guard
                let json    = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let choices = json["choices"] as? [[String: Any]],
                let first   = choices.first,
                let msgObj  = first["message"] as? [String: Any],
                let content = msgObj["content"] as? String
            else {
                appendError("Unexpected response format from OpenAI.")
                return
            }
            messages.append(ChatMessage(role: .assistant, text: content.trimmingCharacters(in: .whitespacesAndNewlines)))
        } catch {
            appendError("Network error: \(error.localizedDescription)")
        }
    }

    // MARK: - Clear chat

    func clearChat() {
        messages.removeAll()
        if chunksReady {
            messages.append(ChatMessage(
                role: .assistant,
                text: "Chat cleared. I still have **\(chunks.count) knowledge chunks** loaded. Ask away! 💬"))
        }
    }

    // MARK: - Helpers

    private func appendError(_ text: String) {
        errorMessage = text
        messages.append(ChatMessage(role: .assistant, text: "❌ \(text)"))
    }
}
