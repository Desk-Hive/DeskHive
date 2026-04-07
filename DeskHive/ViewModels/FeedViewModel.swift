//
//  FeedViewModel.swift
//  DeskHive
//
//  Manages the message feed inside a microcommunity.
//  Messages live at: communities/{communityID}/feed/{messageID}
//

import Foundation
import FirebaseFirestore

// MARK: - Model

struct FeedMessage: Identifiable {
    var id: String
    var senderEmail: String   // display name
    var senderID: String      // UID (empty for admin posts)
    var body: String
    var isAdminPost: Bool
    var createdAt: Date

    init?(id: String, data: [String: Any]) {
        guard let body = data["body"] as? String, !body.isEmpty else { return nil }
        self.id          = id
        self.body        = body
        self.senderEmail = data["senderEmail"] as? String ?? "Unknown"
        self.senderID    = data["senderID"]    as? String ?? ""
        self.isAdminPost = data["isAdminPost"] as? Bool   ?? false
        if let ts = data["createdAt"] as? Timestamp {
            self.createdAt = ts.dateValue()
        } else {
            self.createdAt = Date()
        }
    }

    func firestoreData() -> [String: Any] {
        [
            "senderEmail": senderEmail,
            "senderID":    senderID,
            "body":        body,
            "isAdminPost": isAdminPost,
            "createdAt":   Timestamp(date: createdAt)
        ]
    }
}

// MARK: - ViewModel

@MainActor
class FeedViewModel: ObservableObject {

    @Published var messages: [FeedMessage] = []
    @Published var isLoading: Bool = false
    @Published var isSending: Bool = false
    @Published var errorMessage: String? = nil

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    // MARK: - Start real-time listener for a community's feed
    func startListening(communityID: String) {
        isLoading = true
        listener?.remove()

        listener = db
            .collection("communities")
            .document(communityID)
            .collection("feed")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                Task { @MainActor in
                    self.isLoading = false
                    if let error {
                        // Fallback: one-time fetch without ordering
                        await self.fetchOnce(communityID: communityID)
                        return
                    }
                    self.messages = snapshot?.documents
                        .compactMap { FeedMessage(id: $0.documentID, data: $0.data()) } ?? []
                }
            }
    }

    // Fallback fetch (no index needed)
    func fetchOnce(communityID: String) async {
        do {
            let snapshot = try await db
                .collection("communities")
                .document(communityID)
                .collection("feed")
                .getDocuments()
            messages = snapshot.documents
                .compactMap { FeedMessage(id: $0.documentID, data: $0.data()) }
                .sorted { $0.createdAt < $1.createdAt }
        } catch {
            errorMessage = "Failed to load feed: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    // MARK: - Post a message
    func postMessage(communityID: String,
                     body: String,
                     senderEmail: String,
                     senderID: String,
                     isAdminPost: Bool) async {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSending = true
        errorMessage = nil

        let msg = FeedMessage(id: "", data: [
            "body":        trimmed,
            "senderEmail": senderEmail,
            "senderID":    senderID,
            "isAdminPost": isAdminPost,
            "createdAt":   Timestamp(date: Date())
        ])
        guard let msg else {
            isSending = false
            return
        }

        do {
            try await db
                .collection("communities")
                .document(communityID)
                .collection("feed")
                .addDocument(data: msg.firestoreData())
            isSending = false
        } catch {
            isSending = false
            errorMessage = "Failed to send: \(error.localizedDescription)"
        }
    }

    // MARK: - Delete a message (admin only)
    func deleteMessage(communityID: String, messageID: String) async {
        do {
            try await db
                .collection("communities")
                .document(communityID)
                .collection("feed")
                .document(messageID)
                .delete()
            messages.removeAll { $0.id == messageID }
        } catch {
            errorMessage = "Failed to delete: \(error.localizedDescription)"
        }
    }

    deinit {
        listener?.remove()
    }
}
