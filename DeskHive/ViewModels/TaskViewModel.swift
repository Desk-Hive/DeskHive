//
//  TaskViewModel.swift
//  DeskHive
//
//  Tasks live at: /communities/{communityID}/tasks/{taskID}
//  Project lead creates & assigns; employees mark done.
//

import Foundation
import FirebaseFirestore

// MARK: - Task Priority

enum TaskPriority: String, CaseIterable, Codable {
    case low    = "low"
    case medium = "medium"
    case high   = "high"

    var label: String {
        switch self {
        case .low:    return "Low"
        case .medium: return "Medium"
        case .high:   return "High"
        }
    }
    var icon: String {
        switch self {
        case .low:    return "arrow.down.circle.fill"
        case .medium: return "minus.circle.fill"
        case .high:   return "exclamationmark.circle.fill"
        }
    }
    var color: String {
        switch self {
        case .low:    return "#4ECDC4"
        case .medium: return "#F5A623"
        case .high:   return "#E94560"
        }
    }
}

// MARK: - Task Status

enum TaskStatus: String, CaseIterable, Codable {
    case todo       = "todo"
    case inProgress = "inProgress"
    case done       = "done"

    var label: String {
        switch self {
        case .todo:       return "To Do"
        case .inProgress: return "In Progress"
        case .done:       return "Done"
        }
    }
    var icon: String {
        switch self {
        case .todo:       return "circle"
        case .inProgress: return "clock.fill"
        case .done:       return "checkmark.circle.fill"
        }
    }
    var color: String {
        switch self {
        case .todo:       return "#A78BFA"
        case .inProgress: return "#F5A623"
        case .done:       return "#4ECDC4"
        }
    }
}

// MARK: - Task Model

struct CommunityTask: Identifiable {
    var id: String
    var title: String
    var description: String
    var assignedToID: String
    var assignedToEmail: String
    var assignedByEmail: String    // project lead
    var priority: TaskPriority
    var status: TaskStatus
    var dueDate: Date?
    var completedAt: Date?
    var createdAt: Date
    var communityID: String
    var communityName: String

    init?(id: String, communityID: String, data: [String: Any]) {
        guard
            let title   = data["title"]           as? String,
            let toID    = data["assignedToID"]    as? String,
            let toEmail = data["assignedToEmail"] as? String
        else { return nil }

        self.id              = id
        self.communityID     = communityID
        self.title           = title
        self.description     = data["description"]    as? String ?? ""
        self.assignedToID    = toID
        self.assignedToEmail = toEmail
        self.assignedByEmail = data["assignedByEmail"] as? String ?? ""
        self.communityName   = data["communityName"]   as? String ?? ""
        self.priority        = TaskPriority(rawValue: data["priority"] as? String ?? "medium") ?? .medium
        self.status          = TaskStatus(rawValue: data["status"] as? String ?? "todo") ?? .todo

        if let ts = data["createdAt"] as? Timestamp {
            self.createdAt = ts.dateValue()
        } else {
            self.createdAt = Date()
        }
        if let ts = data["dueDate"] as? Timestamp {
            self.dueDate = ts.dateValue()
        }
        if let ts = data["completedAt"] as? Timestamp {
            self.completedAt = ts.dateValue()
        }
    }

    var firestoreData: [String: Any] {
        var d: [String: Any] = [
            "title":           title,
            "description":     description,
            "assignedToID":    assignedToID,
            "assignedToEmail": assignedToEmail,
            "assignedByEmail": assignedByEmail,
            "communityName":   communityName,
            "priority":        priority.rawValue,
            "status":          status.rawValue,
            "createdAt":       Timestamp(date: createdAt)
        ]
        if let due = dueDate       { d["dueDate"]     = Timestamp(date: due) }
        if let done = completedAt  { d["completedAt"] = Timestamp(date: done) }
        return d
    }
}

// MARK: - ViewModel

@MainActor
class TaskViewModel: ObservableObject {

    @Published var tasks: [CommunityTask] = []
    @Published var isLoading  = false
    @Published var isSaving   = false
    @Published var errorMessage:   String? = nil
    @Published var successMessage: String? = nil

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    // MARK: - Real-time listener for a community's tasks
    func startListening(communityID: String) {
        isLoading = true
        listener?.remove()

        listener = db
            .collection("communities").document(communityID)
            .collection("tasks")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                Task { @MainActor in
                    self.isLoading = false
                    if error != nil {
                        await self.fetchOnce(communityID: communityID)
                        return
                    }
                    self.tasks = (snapshot?.documents
                        .compactMap { CommunityTask(id: $0.documentID, communityID: communityID, data: $0.data()) } ?? [])
                        .sorted { $0.createdAt > $1.createdAt }
                }
            }
    }

    func fetchOnce(communityID: String) async {
        do {
            let snap = try await db
                .collection("communities").document(communityID)
                .collection("tasks").getDocuments()
            tasks = snap.documents
                .compactMap { CommunityTask(id: $0.documentID, communityID: communityID, data: $0.data()) }
                .sorted { $0.createdAt > $1.createdAt }
        } catch {
            errorMessage = "Failed to load tasks."
        }
        isLoading = false
    }

    // Fetch tasks assigned to a specific employee across ALL communities
    func fetchMyTasks(employeeID: String) async {
        isLoading = true
        errorMessage = nil
        do {
            // Fetch all communities first, then their tasks
            let commSnap = try await db.collection("communities").getDocuments()
            var all: [CommunityTask] = []
            for doc in commSnap.documents {
                let cID = doc.documentID
                let taskSnap = try await db
                    .collection("communities").document(cID)
                    .collection("tasks").getDocuments()
                let myTasks = taskSnap.documents
                    .compactMap { CommunityTask(id: $0.documentID, communityID: cID, data: $0.data()) }
                    .filter { $0.assignedToID == employeeID }
                all.append(contentsOf: myTasks)
            }
            tasks = all.sorted { $0.createdAt > $1.createdAt }
        } catch {
            errorMessage = "Failed to load tasks."
        }
        isLoading = false
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    // MARK: - Create task
    func createTask(communityID: String,
                    communityName: String,
                    title: String,
                    description: String,
                    assignedTo: DeskHiveUser,
                    priority: TaskPriority,
                    dueDate: Date?,
                    leadEmail: String) async {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Task title cannot be empty."; return
        }
        isSaving = true; errorMessage = nil; successMessage = nil

        let ref = db.collection("communities").document(communityID).collection("tasks").document()
        var data: [String: Any] = [
            "title":           title.trimmingCharacters(in: .whitespaces),
            "description":     description.trimmingCharacters(in: .whitespaces),
            "assignedToID":    assignedTo.id,
            "assignedToEmail": assignedTo.email,
            "assignedByEmail": leadEmail,
            "communityName":   communityName,
            "priority":        priority.rawValue,
            "status":          TaskStatus.todo.rawValue,
            "createdAt":       Timestamp(date: Date())
        ]
        if let due = dueDate { data["dueDate"] = Timestamp(date: due) }

        do {
            try await ref.setData(data)

            // Post task notification to employee's inbox
            let dueLine = dueDate.map { d -> String in
                let f = DateFormatter(); f.dateStyle = .medium
                return "\n• Due: \(f.string(from: d))"
            } ?? ""
            let notifRef = db.collection("announcements").document()
            let notifData: [String: Any] = [
                "title":      "📋 New Task Assigned: \(title.trimmingCharacters(in: .whitespaces))",
                "body":       "Your project lead \(leadEmail.components(separatedBy: "@").first ?? leadEmail) has assigned you a task in \(communityName).\n\n• Priority: \(priority.label)\(dueLine)\n\n\(description.trimmingCharacters(in: .whitespaces))",
                "priority":   priority == .high ? "urgent" : priority == .medium ? "warning" : "info",
                "targetUID":  assignedTo.id,
                "type":       "task",
                "taskID":     ref.documentID,
                "createdAt":  Timestamp(date: Date())
            ]
            try await notifRef.setData(notifData)

            successMessage = "Task assigned to \(assignedTo.email.components(separatedBy: "@").first ?? assignedTo.email)!"
        } catch {
            errorMessage = "Failed to create task: \(error.localizedDescription)"
        }
        isSaving = false
    }

    // MARK: - Update status (employee marks done / in progress)
    func updateStatus(task: CommunityTask, newStatus: TaskStatus) async {
        errorMessage = nil
        var update: [String: Any] = ["status": newStatus.rawValue]
        if newStatus == .done { update["completedAt"] = Timestamp(date: Date()) }

        do {
            try await db
                .collection("communities").document(task.communityID)
                .collection("tasks").document(task.id)
                .updateData(update)
            if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[idx].status = newStatus
                if newStatus == .done { tasks[idx].completedAt = Date() }
            }
        } catch {
            errorMessage = "Failed to update task."
        }
    }

    // MARK: - Delete task (lead only)
    func deleteTask(_ task: CommunityTask) async {
        do {
            try await db
                .collection("communities").document(task.communityID)
                .collection("tasks").document(task.id)
                .delete()
            tasks.removeAll { $0.id == task.id }
        } catch {
            errorMessage = "Failed to delete task."
        }
    }

    deinit { listener?.remove() }
}
