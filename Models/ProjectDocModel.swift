//
//  ProjectDocModel.swift
//  DeskHive
//
//  Represents a project document stored in Firestore.
//  The raw .docx bytes are base64-encoded and stored directly in Firestore.
//  Text is extracted client-side and embedded with OpenAI.
//

import Foundation
import FirebaseFirestore

// MARK: - Embedded chunk

struct DocChunk: Identifiable, Codable {
    var id: String          // UUID string
    var text: String        // plain text of this chunk
    var embedding: [Float]  // OpenAI text-embedding-3-small vector (1536 dims)
    var chunkIndex: Int

    var firestoreData: [String: Any] {
        [
            "id":         id,
            "text":       text,
            "embedding":  embedding.map { Double($0) },
            "chunkIndex": chunkIndex
        ]
    }

    init?(data: [String: Any]) {
        guard
            let id    = data["id"]         as? String,
            let text  = data["text"]       as? String,
            let index = data["chunkIndex"] as? Int
        else { return nil }
        self.id         = id
        self.text       = text
        self.chunkIndex = index
        if let raw = data["embedding"] as? [Double] {
            self.embedding = raw.map { Float($0) }
        } else {
            self.embedding = []
        }
    }

    init(id: String, text: String, embedding: [Float], chunkIndex: Int) {
        self.id         = id
        self.text       = text
        self.embedding  = embedding
        self.chunkIndex = chunkIndex
    }
}

// MARK: - Top-level document record

struct ProjectDoc: Identifiable {
    var id: String
    var communityID: String
    var fileName: String
    var uploadedBy: String    // projectLead UID
    var uploadedAt: Date
    var status: EmbedStatus

    enum EmbedStatus: String {
        case pending    = "pending"
        case processing = "processing"
        case ready      = "ready"
        case failed     = "failed"
    }

    init(id: String = UUID().uuidString,
         communityID: String,
         fileName: String,
         uploadedBy: String) {
        self.id          = id
        self.communityID = communityID
        self.fileName    = fileName
        self.uploadedBy  = uploadedBy
        self.uploadedAt  = Date()
        self.status      = .pending
    }

    init?(id: String, data: [String: Any]) {
        guard
            let communityID = data["communityID"] as? String,
            let fileName    = data["fileName"]    as? String,
            let uploadedBy  = data["uploadedBy"]  as? String,
            let statusRaw   = data["status"]      as? String
        else { return nil }

        self.id          = id
        self.communityID = communityID
        self.fileName    = fileName
        self.uploadedBy  = uploadedBy
        self.status      = EmbedStatus(rawValue: statusRaw) ?? .pending

        if let ts = data["uploadedAt"] as? Timestamp {
            self.uploadedAt = ts.dateValue()
        } else {
            self.uploadedAt = Date()
        }
    }

    func metaData() -> [String: Any] {
        [
            "communityID": communityID,
            "fileName":    fileName,
            "uploadedBy":  uploadedBy,
            "uploadedAt":  Timestamp(date: uploadedAt),
            "status":      status.rawValue
        ]
    }
}
