//
//  EmbeddingService.swift
//  DeskHive
//
//  Calls the OpenAI Embeddings API (text-embedding-3-small, 1536 dims).
//

import Foundation

enum EmbeddingError: Error {
    case networkError(Error)
    case badResponse(Int)
    case decodingError
    case emptyResult
}

struct EmbeddingService {

    // ⚠️  Key is loaded from Secrets.xcconfig (gitignored).
    static let openAIKey: String = {
        // Try Info.plist first (works when xcconfig is fully wired)
        if let key = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String,
           !key.isEmpty, key != "your-openai-api-key-here" {
            return key
        }
        // Fallback: parse Secrets.xcconfig directly from the project source tree.
        // Works in Simulator where the source is accessible on disk.
        let xcconfig = "/Users/nishattasinshreya/Desktop/Shormi/DeskHive/DeskHive/Secrets.xcconfig"
        if let content = try? String(contentsOfFile: xcconfig, encoding: .utf8) {
            for line in content.components(separatedBy: .newlines) {
                let t = line.trimmingCharacters(in: .whitespaces)
                guard !t.hasPrefix("//"), t.hasPrefix("OPENAI_API_KEY") else { continue }
                let parts = t.components(separatedBy: "=")
                if parts.count >= 2 {
                    let key = parts[1...].joined(separator: "=").trimmingCharacters(in: .whitespaces)
                    if !key.isEmpty { return key }
                }
            }
        }
        return ""
    }()
    private static let apiKey = openAIKey
    private static let model  = "text-embedding-3-small"
    private static let url    = URL(string: "https://api.openai.com/v1/embeddings")!

    // MARK: - Single text

    static func embed(text: String) async throws -> [Float] {
        let body: [String: Any] = ["model": model, "input": text]
        return try await callAPI(body: body).first ?? []
    }

    // MARK: - Batch (up to 2048 inputs per call per OpenAI limits)

    static func embedBatch(texts: [String]) async throws -> [[Float]] {
        guard !texts.isEmpty else { return [] }
        // OpenAI batch limit: 2048 strings per request
        let batches = stride(from: 0, to: texts.count, by: 2048).map {
            Array(texts[$0..<min($0 + 2048, texts.count)])
        }
        var all: [[Float]] = []
        for batch in batches {
            let body: [String: Any] = ["model": model, "input": batch]
            let result = try await callAPI(body: body)
            all.append(contentsOf: result)
        }
        return all
    }

    // MARK: - Internal

    private static func callAPI(body: [String: Any]) async throws -> [[Float]] {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json",  forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw EmbeddingError.networkError(error)
        }

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw EmbeddingError.badResponse(http.statusCode)
        }

        guard
            let json    = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let dataArr = json["data"] as? [[String: Any]]
        else { throw EmbeddingError.decodingError }

        // OpenAI returns embeddings sorted by "index"
        let sorted = dataArr.sorted {
            ($0["index"] as? Int ?? 0) < ($1["index"] as? Int ?? 0)
        }
        let vectors = sorted.compactMap { item -> [Float]? in
            guard let vec = item["embedding"] as? [Double] else { return nil }
            return vec.map { Float($0) }
        }
        if vectors.isEmpty { throw EmbeddingError.emptyResult }
        return vectors
    }

    // MARK: - Cosine similarity helper (used by AI chat)

    static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot: Float = 0; var normA: Float = 0; var normB: Float = 0
        for i in 0..<a.count {
            dot   += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        let denom = sqrt(normA) * sqrt(normB)
        return denom > 0 ? dot / denom : 0
    }
}
