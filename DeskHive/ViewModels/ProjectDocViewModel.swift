//
//  ProjectDocViewModel.swift
//  DeskHive
//
//  Handles the full pipeline:
//    1. Receive .docx Data from the file picker
//    2. Base64-encode and store raw bytes in Firestore
//    3. Extract text via DocxTextExtractor
//    4. Split into chunks
//    5. Embed each chunk with OpenAI
//    6. Store chunks in  communities/{id}/projectDocs/{docID}/chunks/{chunkID}
//    7. Mark document status as "ready"
//
//  Firestore layout:
//    communities/{communityID}/projectDocs/{docID}   <- metadata + base64
//    communities/{communityID}/projectDocs/{docID}/chunks/{chunkID}  <- each chunk
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
class ProjectDocViewModel: ObservableObject {

    @Published var docs: [ProjectDoc] = []
    @Published var isUploading = false
    @Published var uploadProgress: String = ""   // human-readable status
    @Published var errorMessage: String?  = nil
    @Published var successMessage: String? = nil

    private let db = Firestore.firestore()

    // ----------------------------------------------------------------
    // MARK: - Load existing docs for a community
    // ----------------------------------------------------------------

    func loadDocs(communityID: String) async {
        do {
            let snap = try await db
                .collection("communities")
                .document(communityID)
                .collection("projectDocs")
                .order(by: "uploadedAt", descending: true)
                .getDocuments()

            docs = snap.documents.compactMap {
                ProjectDoc(id: $0.documentID, data: $0.data())
            }
        } catch {
            errorMessage = "Failed to load docs: \(error.localizedDescription)"
        }
    }

    // ----------------------------------------------------------------
    // MARK: - Upload + embed pipeline
    // ----------------------------------------------------------------

    /// Call this from the UI after the user picks a .docx file.
    func uploadAndEmbed(docxData: Data, fileName: String,
                        communityID: String, uploaderUID: String) async {
        errorMessage   = nil
        successMessage = nil
        isUploading    = true
        defer { isUploading = false }

        let docID = UUID().uuidString
        var meta  = ProjectDoc(id: docID,
                               communityID: communityID,
                               fileName: fileName,
                               uploadedBy: uploaderUID)

        // ── Step 1: Extract text locally (no Firestore yet) ───────────
        uploadProgress = "Extracting text…"
        let plainText: String
        do {
            plainText = try DocxTextExtractor.extractText(from: docxData)
        } catch {
            errorMessage = "Could not read document: \(error.localizedDescription)"
            return
        }

        guard !plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "The document appears to be empty or uses unsupported formatting."
            return
        }

        // ── Step 2: Chunk ──────────────────────────────────────────────
        let chunkTexts = DocxTextExtractor.chunk(text: plainText)
        uploadProgress = "Embedding \(chunkTexts.count) chunk(s) with AI…"

        // ── Step 3: Embed via OpenAI ───────────────────────────────────
        let vectors: [[Float]]
        do {
            vectors = try await EmbeddingService.embedBatch(texts: chunkTexts)
        } catch let error as EmbeddingError {
            switch error {
            case .networkError(let underlying):
                errorMessage = "Network error during embedding: \(underlying.localizedDescription). Check your internet connection."
            case .badResponse(let code):
                if code == 401 {
                    errorMessage = "Embedding failed: Invalid OpenAI API key (401). Please check your Secrets.xcconfig file."
                } else {
                    errorMessage = "OpenAI API error: HTTP \(code). The API may be unavailable or rate-limited."
                }
            case .decodingError:
                errorMessage = "Embedding failed: Could not parse OpenAI response."
            case .emptyResult:
                errorMessage = "Embedding failed: OpenAI returned no vectors."
            }
            return
        } catch {
            errorMessage = "Embedding failed: \(error.localizedDescription)"
            return
        }

        guard vectors.count == chunkTexts.count else {
            errorMessage = "Embedding returned unexpected number of vectors."
            return
        }

        // ── Step 4: Write metadata to Firestore (status = processing) ──
        uploadProgress = "Saving to database…"
        do {
            try await db
                .collection("communities")
                .document(communityID)
                .collection("projectDocs")
                .document(docID)
                .setData(meta.metaData())
        } catch {
            errorMessage = "Save failed: \(error.localizedDescription)"
            return
        }

        // ── Step 5: Write chunks in batches ────────────────────────────
        let chunksRef = db
            .collection("communities").document(communityID)
            .collection("projectDocs").document(docID)
            .collection("chunks")

        do {
            var batch      = db.batch()
            var batchCount = 0

            for (i, (text, vec)) in zip(chunkTexts, vectors).enumerated() {
                let chunk = DocChunk(id: UUID().uuidString,
                                     text: text,
                                     embedding: vec,
                                     chunkIndex: i)
                batch.setData(chunk.firestoreData, forDocument: chunksRef.document(chunk.id))
                batchCount += 1
                if batchCount == 499 {
                    try await batch.commit()
                    batch = db.batch(); batchCount = 0
                }
            }
            if batchCount > 0 { try await batch.commit() }
        } catch {
            await markFailed(docID: docID, communityID: communityID)
            errorMessage = "Failed saving embeddings: \(error.localizedDescription)"
            return
        }

        // ── Step 6: Mark ready ─────────────────────────────────────────
        try? await db
            .collection("communities").document(communityID)
            .collection("projectDocs").document(docID)
            .updateData(["status": "ready"])

        uploadProgress = ""
        successMessage = "\"\(fileName)\" embedded successfully (\(chunkTexts.count) chunks)."
        meta.status = .ready
        docs.insert(meta, at: 0)
    }

    // ----------------------------------------------------------------
    // MARK: - Delete a doc
    // ----------------------------------------------------------------

    func deleteDoc(_ doc: ProjectDoc) async {
        do {
            // Delete chunks sub-collection
            let chunksSnap = try await db
                .collection("communities")
                .document(doc.communityID)
                .collection("projectDocs")
                .document(doc.id)
                .collection("chunks")
                .getDocuments()
            let batch = db.batch()
            for d in chunksSnap.documents { batch.deleteDocument(d.reference) }
            try await batch.commit()

            // Delete parent doc
            try await db
                .collection("communities")
                .document(doc.communityID)
                .collection("projectDocs")
                .document(doc.id)
                .delete()

            docs.removeAll { $0.id == doc.id }
        } catch {
            errorMessage = "Delete failed: \(error.localizedDescription)"
        }
    }

    // ----------------------------------------------------------------
    // MARK: - Retrieve chunks for AI (called by chat)
    // ----------------------------------------------------------------

    /// Returns all chunks for a community, sorted by chunkIndex.
    func fetchChunks(communityID: String) async throws -> [DocChunk] {
        // Get all docs for this community
        let docsSnap = try await db
            .collection("communities")
            .document(communityID)
            .collection("projectDocs")
            .whereField("status", isEqualTo: "ready")
            .getDocuments()

        var all: [DocChunk] = []
        for docSnap in docsSnap.documents {
            let chunksSnap = try await db
                .collection("communities")
                .document(communityID)
                .collection("projectDocs")
                .document(docSnap.documentID)
                .collection("chunks")
                .getDocuments()
            let chunks = chunksSnap.documents.compactMap { DocChunk(data: $0.data()) }
            all.append(contentsOf: chunks)
        }
        return all.sorted { $0.chunkIndex < $1.chunkIndex }
    }

    // ----------------------------------------------------------------
    // MARK: - Helpers
    // ----------------------------------------------------------------

    private func markFailed(docID: String, communityID: String) async {
        try? await db
            .collection("communities")
            .document(communityID)
            .collection("projectDocs")
            .document(docID)
            .updateData(["status": "failed"])
    }
}
