//
//  AnnouncementViewModel.swift
//  DeskHive
//
//  Announcements live at: /announcements/{id}
//  Admin creates them; all employees can read them.
//

import Foundation
import FirebaseFirestore

// MARK: - Model

enum AnnouncementType: String {
    case broadcast  = "broadcast"   // admin → all employees
    case promotion  = "promotion"   // admin → specific employee (project lead)
    case task       = "task"        // project lead → assigned employee
}

struct Announcement: Identifiable {
    var id: String
    var title: String
    var body: String
    var priority: AnnouncementPriority
    var targetUID: String    // "" = broadcast to all; non-empty = personal
    var type: AnnouncementType
    var createdAt: Date

    enum AnnouncementPriority: String, CaseIterable {
        case info    = "info"
        case warning = "warning"
        case urgent  = "urgent"

        var label: String {
            switch self {
            case .info:    return "Info"
            case .warning: return "Warning"
            case .urgent:  return "Urgent"
            }
        }
        var icon: String {
            switch self {
            case .info:    return "megaphone.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .urgent:  return "bell.badge.fill"
            }
        }
        var color: String {
            switch self {
            case .info:    return "#4ECDC4"
            case .warning: return "#F5A623"
            case .urgent:  return "#E94560"
            }
        }
    }

    init?(id: String, data: [String: Any]) {
        guard
            let title = data["title"] as? String,
            let body  = data["body"]  as? String
        else { return nil }

        self.id        = id
        self.title     = title
        self.body      = body
        self.priority  = AnnouncementPriority(rawValue: data["priority"] as? String ?? "info") ?? .info
        self.targetUID = data["targetUID"] as? String ?? ""
        self.type      = AnnouncementType(rawValue: data["type"] as? String ?? "broadcast") ?? .broadcast

        if let ts = data["createdAt"] as? Timestamp {
            self.createdAt = ts.dateValue()
        } else {
            self.createdAt = Date()
        }
    }

    var firestoreData: [String: Any] {
        [
            "title":     title,
            "body":      body,
            "priority":  priority.rawValue,
            "targetUID": targetUID,
            "type":      type.rawValue,
            "createdAt": Timestamp(date: createdAt)
        ]
    }
}

// MARK: - ViewModel

@MainActor
class AnnouncementViewModel: ObservableObject {

    @Published var announcements: [Announcement] = []         // broadcast only
    @Published var personalAnnouncements: [Announcement] = [] // promotion type (project lead credentials)
    @Published var taskNotifications: [Announcement] = []     // task assignments for this employee
    @Published var isLoading:  Bool = false
    @Published var isPosting:  Bool = false
    @Published var errorMessage:   String? = nil
    @Published var successMessage: String? = nil

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    // MARK: - Real-time listener — broadcast announcements (no targetUID)
    func startListening() {
        isLoading = true
        listener?.remove()

        listener = db.collection("announcements")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                Task { @MainActor in
                    self.isLoading = false
                    if error != nil {
                        await self.fetchOnce()
                        return
                    }
                    let all = snapshot?.documents
                        .compactMap { Announcement(id: $0.documentID, data: $0.data()) } ?? []
                    // Only show broadcast (no specific target) in the general feed
                    self.announcements = all.filter { $0.targetUID.isEmpty }
                }
            }
    }

    // MARK: - Fetch personal announcements for a specific employee UID
    func fetchPersonal(for uid: String) async {
        do {
            let snap = try await db.collection("announcements").getDocuments()
            let all = snap.documents
                .compactMap { Announcement(id: $0.documentID, data: $0.data()) }
                .filter { $0.targetUID == uid }
                .sorted { $0.createdAt > $1.createdAt }

            personalAnnouncements = all.filter { $0.type == .promotion }
            taskNotifications     = all.filter { $0.type == .task }
        } catch {
            // silently fail
        }
    }

    // Fallback one-time fetch (no composite index needed)
    func fetchOnce() async {
        do {
            let snap = try await db.collection("announcements").getDocuments()
            let all = snap.documents
                .compactMap { Announcement(id: $0.documentID, data: $0.data()) }
                .sorted { $0.createdAt > $1.createdAt }
            announcements = all.filter { $0.targetUID.isEmpty }
        } catch {
            errorMessage = "Failed to load announcements."
        }
        isLoading = false
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    // MARK: - Post announcement (admin)
    func postAnnouncement(title: String,
                          body: String,
                          priority: Announcement.AnnouncementPriority) async {
        let t = title.trimmingCharacters(in: .whitespaces)
        let b = body.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, !b.isEmpty else {
            errorMessage = "Title and body are required."
            return
        }

        isPosting = true
        errorMessage = nil
        successMessage = nil

        let ref = db.collection("announcements").document()
        let ann = Announcement(id: ref.documentID, data: [
            "title":     t,
            "body":      b,
            "priority":  priority.rawValue,
            "targetUID": "",
            "type":      AnnouncementType.broadcast.rawValue,
            "createdAt": Timestamp(date: Date())
        ])
        guard let ann else { isPosting = false; return }

        do {
            try await ref.setData(ann.firestoreData)
            announcements.insert(ann, at: 0)
            successMessage = "Announcement posted!"
        } catch {
            errorMessage = "Failed to post: \(error.localizedDescription)"
        }
        isPosting = false
    }

    // MARK: - Delete announcement (admin)
    func deleteAnnouncement(_ ann: Announcement) async {
        do {
            try await db.collection("announcements").document(ann.id).delete()
            announcements.removeAll { $0.id == ann.id }
        } catch {
            errorMessage = "Failed to delete."
        }
    }

    deinit { listener?.remove() }
}
