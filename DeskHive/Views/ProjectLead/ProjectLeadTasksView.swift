//
//  ProjectLeadTasksView.swift
//  DeskHive
//
//  Project lead view: create tasks, assign to members, track progress.
//

import SwiftUI

struct ProjectLeadTasksView: View {
    let community: Microcommunity
    let leadEmail: String

    @StateObject private var taskVM = TaskViewModel()
    @State private var showCreate   = false
    @State private var filterStatus: TaskStatus? = nil

    private var filtered: [CommunityTask] {
        guard let f = filterStatus else { return taskVM.tasks }
        return taskVM.tasks.filter { $0.status == f }
    }

    private var todoCount:   Int { taskVM.tasks.filter { $0.status == .todo }.count }
    private var inProgCount: Int { taskVM.tasks.filter { $0.status == .inProgress }.count }
    private var doneCount:   Int { taskVM.tasks.filter { $0.status == .done }.count }

    var body: some View {
        VStack(spacing: 16) {

            // ── Inline header with assign button ─────────────────────────
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Team Tasks")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("\(taskVM.tasks.count) task\(taskVM.tasks.count == 1 ? "" : "s") · \(community.memberIDs.count) member\(community.memberIDs.count == 1 ? "" : "s")")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.45))
                }
                Spacer()
                Button(action: { showCreate = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                        Text("Assign Task")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(hex: "#F5A623"), Color(hex: "#E08C00")]),
                            startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(10)
                    .shadow(color: Color(hex: "#F5A623").opacity(0.3), radius: 6, x: 0, y: 3)
                }
            }
            .padding(.horizontal, 20)

            // ── Stats row ────────────────────────────────────────────────
            HStack(spacing: 10) {
                miniStat(label: "To Do",    value: todoCount,   color: "#A78BFA")
                miniStat(label: "In Prog.", value: inProgCount, color: "#F5A623")
                miniStat(label: "Done",     value: doneCount,   color: "#4ECDC4")
            }
            .padding(.horizontal, 20)

            // ── Filter chips ─────────────────────────────────────────────
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    filterChip(label: "All",         icon: "tray.full",              color: "#FFFFFF",                   active: filterStatus == nil)         { filterStatus = nil }
                    filterChip(label: "To Do",       icon: TaskStatus.todo.icon,       color: TaskStatus.todo.color,       active: filterStatus == .todo)       { filterStatus = .todo }
                    filterChip(label: "In Progress", icon: TaskStatus.inProgress.icon, color: TaskStatus.inProgress.color, active: filterStatus == .inProgress) { filterStatus = .inProgress }
                    filterChip(label: "Done",        icon: TaskStatus.done.icon,       color: TaskStatus.done.color,       active: filterStatus == .done)       { filterStatus = .done }
                }
                .padding(.horizontal, 20)
            }

            // ── Banners ──────────────────────────────────────────────────
            if let err = taskVM.errorMessage   { ErrorBanner(message: err).padding(.horizontal, 20) }
            if let ok  = taskVM.successMessage { SuccessBanner(message: ok).padding(.horizontal, 20) }

            // ── Task list ────────────────────────────────────────────────
            if taskVM.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#F5A623")))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else if filtered.isEmpty {
                // Empty state
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#F5A623").opacity(0.08))
                            .frame(width: 80, height: 80)
                        Image(systemName: "checklist")
                            .font(.system(size: 36))
                            .foregroundColor(Color(hex: "#F5A623").opacity(0.5))
                    }
                    Text(filterStatus == nil ? "No tasks yet" : "No \(filterStatus!.label) tasks")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                    Text("Tap \"+  Assign Task\" to create and assign work to your team members.")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.35))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

                    // Shortcut button in empty state
                    Button(action: { showCreate = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("Create First Task")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(Color(hex: "#F5A623"))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color(hex: "#F5A623").opacity(0.1))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(hex: "#F5A623").opacity(0.3), lineWidth: 1))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .padding(.horizontal, 20)
                .background(Color.white.opacity(0.04))
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(hex: "#F5A623").opacity(0.1), lineWidth: 1))
                .padding(.horizontal, 20)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(filtered) { task in
                        LeadTaskRow(task: task, taskVM: taskVM)
                    }
                }
                .padding(.horizontal, 20)
            }

            Spacer().frame(height: 40)
        }
        .onAppear  { taskVM.startListening(communityID: community.id) }
        .onDisappear { taskVM.stopListening() }
        .sheet(isPresented: $showCreate, onDismiss: { taskVM.successMessage = nil }) {
            CreateTaskSheet(community: community, leadEmail: leadEmail, taskVM: taskVM)
        }
    }

    // MARK: - Mini stat card
    private func miniStat(label: String, value: Int, color: String) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: color))
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(hex: color).opacity(0.08))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(Color(hex: color).opacity(0.2), lineWidth: 1))
    }

    // MARK: - Filter chip
    private func filterChip(label: String, icon: String, color: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11))
                Text(label).font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(active ? Color(hex: color) : .white.opacity(0.45))
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(active ? Color(hex: color).opacity(0.15) : Color.white.opacity(0.06))
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20)
                .stroke(active ? Color(hex: color).opacity(0.4) : Color.white.opacity(0.1), lineWidth: 1))
        }
    }
}

// MARK: - Task row for lead (with delete + status display)

struct LeadTaskRow: View {
    let task: CommunityTask
    @ObservedObject var taskVM: TaskViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top row: priority + status + delete
            HStack(spacing: 8) {
                // Priority badge
                HStack(spacing: 4) {
                    Image(systemName: task.priority.icon).font(.system(size: 10))
                    Text(task.priority.label).font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(Color(hex: task.priority.color))
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color(hex: task.priority.color).opacity(0.12))
                .cornerRadius(6)

                Spacer()

                // Status badge
                HStack(spacing: 4) {
                    Image(systemName: task.status.icon).font(.system(size: 10))
                    Text(task.status.label).font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(Color(hex: task.status.color))
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color(hex: task.status.color).opacity(0.12))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(hex: task.status.color).opacity(0.3), lineWidth: 1))

                // Delete
                Button(action: { Task { await taskVM.deleteTask(task) } }) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#E94560").opacity(0.6))
                        .padding(6)
                        .background(Color(hex: "#E94560").opacity(0.08))
                        .cornerRadius(6)
                }
            }

            // Title
            Text(task.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(task.status == .done ? .white.opacity(0.45) : .white)
                .strikethrough(task.status == .done, color: .white.opacity(0.3))

            if !task.description.isEmpty {
                Text(task.description)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(2)
            }

            // Assignee + due + completed
            HStack(spacing: 12) {
                // Assignee
                HStack(spacing: 5) {
                    Image(systemName: "person.fill").font(.system(size: 10)).foregroundColor(.white.opacity(0.35))
                    Text(task.assignedToEmail.components(separatedBy: "@").first ?? task.assignedToEmail)
                        .font(.system(size: 11)).foregroundColor(.white.opacity(0.5))
                }

                if let due = task.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar").font(.system(size: 10)).foregroundColor(.white.opacity(0.35))
                        Text(shortDate(due)).font(.system(size: 11))
                            .foregroundColor(due < Date() && task.status != .done
                                             ? Color(hex: "#E94560") : .white.opacity(0.5))
                    }
                }

                Spacer()

                if task.status == .done, let done = task.completedAt {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 10)).foregroundColor(Color(hex: "#4ECDC4"))
                        Text(shortDate(done)).font(.system(size: 10)).foregroundColor(Color(hex: "#4ECDC4"))
                    }
                }
            }
        }
        .padding(14)
        .background(task.status == .done ? Color.white.opacity(0.04) : Color.white.opacity(0.08))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(task.status == .done
                    ? Color(hex: "#4ECDC4").opacity(0.2)
                    : Color.white.opacity(0.1), lineWidth: 1))
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMM d"
        return f.string(from: date)
    }
}

// MARK: - Create Task Sheet

struct CreateTaskSheet: View {
    let community: Microcommunity
    let leadEmail: String
    @ObservedObject var taskVM: TaskViewModel
    @Environment(\.dismiss) var dismiss

    @State private var title       = ""
    @State private var description = ""
    @State private var priority    = TaskPriority.medium
    @State private var selectedMember: DeskHiveUser? = nil
    @State private var hasDueDate  = false
    @State private var dueDate     = Date().addingTimeInterval(86400 * 3)

    private var members: [DeskHiveUser] {
        zip(community.memberIDs, community.memberEmails).map {
            DeskHiveUser(id: $0.0, email: $0.1, role: .employee)
        }
    }

    var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && selectedMember != nil && !taskVM.isSaving
    }

    var body: some View {
        ZStack {
            AppBackground().ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Top bar ──────────────────────────────────────────────
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("Assign Task")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Color.clear.frame(width: 34, height: 34)
                }
                .padding(.horizontal, 20).padding(.top, 56).padding(.bottom, 16)

                // ── Scrollable form ──────────────────────────────────────
                ScrollView(showsIndicators: true) {
                    VStack(spacing: 18) {

                        // Header
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "#F5A623").opacity(0.15))
                                    .frame(width: 60, height: 60)
                                Image(systemName: "checklist")
                                    .font(.system(size: 26))
                                    .foregroundColor(Color(hex: "#F5A623"))
                            }
                            Text(community.project.isEmpty ? community.name : community.project)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "#F5A623"))
                            Text("Create and assign a task to a team member")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .padding(.top, 4)

                        // Task title
                        DeskHiveCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Task Title *", systemImage: "pencil")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.6))
                                TextField("", text: $title,
                                          prompt: Text("e.g. Design the landing page")
                                            .foregroundColor(.white.opacity(0.3)))
                                    .foregroundColor(.white)
                                    .tint(Color(hex: "#F5A623"))
                            }
                        }

                        // Description
                        DeskHiveCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Description", systemImage: "text.alignleft")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.6))
                                TextField("", text: $description,
                                          prompt: Text("Optional details about this task…")
                                            .foregroundColor(.white.opacity(0.3)),
                                          axis: .vertical)
                                    .foregroundColor(.white)
                                    .tint(Color(hex: "#F5A623"))
                                    .lineLimit(3...6)
                            }
                        }

                        // Assign to member
                        DeskHiveCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Assign To *", systemImage: "person.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.6))

                                if members.isEmpty {
                                    HStack(spacing: 8) {
                                        Image(systemName: "person.slash").foregroundColor(.white.opacity(0.3))
                                        Text("No members in this community yet.")
                                            .font(.system(size: 13))
                                            .foregroundColor(.white.opacity(0.4))
                                    }
                                } else {
                                    VStack(spacing: 0) {
                                        ForEach(members) { member in
                                            let selected = selectedMember?.id == member.id
                                            Button(action: { selectedMember = member }) {
                                                HStack(spacing: 12) {
                                                    ZStack {
                                                        Circle()
                                                            .fill(selected
                                                                  ? Color(hex: "#F5A623").opacity(0.2)
                                                                  : Color.white.opacity(0.08))
                                                            .frame(width: 36, height: 36)
                                                        Text(member.email.prefix(1).uppercased())
                                                            .font(.system(size: 13, weight: .bold))
                                                            .foregroundColor(selected ? Color(hex: "#F5A623") : .white.opacity(0.5))
                                                    }
                                                    VStack(alignment: .leading, spacing: 1) {
                                                        Text(member.email.components(separatedBy: "@").first ?? member.email)
                                                            .font(.system(size: 13, weight: .semibold))
                                                            .foregroundColor(selected ? .white : .white.opacity(0.7))
                                                        Text(member.email)
                                                            .font(.system(size: 11))
                                                            .foregroundColor(.white.opacity(0.35))
                                                            .lineLimit(1)
                                                    }
                                                    Spacer()
                                                    if selected {
                                                        Image(systemName: "checkmark.circle.fill")
                                                            .foregroundColor(Color(hex: "#F5A623"))
                                                            .font(.system(size: 18))
                                                    } else {
                                                        Circle()
                                                            .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
                                                            .frame(width: 18, height: 18)
                                                    }
                                                }
                                                .padding(.vertical, 10)
                                                .contentShape(Rectangle())
                                            }
                                            .buttonStyle(.plain)
                                            if member.id != members.last?.id {
                                                Divider().background(Color.white.opacity(0.08))
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Priority
                        DeskHiveCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("Priority", systemImage: "flag.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.6))
                                HStack(spacing: 8) {
                                    ForEach(TaskPriority.allCases, id: \.self) { p in
                                        Button(action: { priority = p }) {
                                            VStack(spacing: 4) {
                                                Image(systemName: p.icon)
                                                    .font(.system(size: 16))
                                                    .foregroundColor(priority == p ? Color(hex: p.color) : .white.opacity(0.3))
                                                Text(p.label)
                                                    .font(.system(size: 11, weight: .semibold))
                                                    .foregroundColor(priority == p ? Color(hex: p.color) : .white.opacity(0.35))
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(priority == p ? Color(hex: p.color).opacity(0.15) : Color.white.opacity(0.05))
                                            .cornerRadius(10)
                                            .overlay(RoundedRectangle(cornerRadius: 10)
                                                .stroke(priority == p ? Color(hex: p.color).opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1))
                                        }
                                    }
                                }
                            }
                        }

                        // Due date
                        DeskHiveCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Label("Due Date", systemImage: "calendar")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.6))
                                    Spacer()
                                    Toggle("", isOn: $hasDueDate)
                                        .labelsHidden()
                                        .tint(Color(hex: "#F5A623"))
                                }
                                if hasDueDate {
                                    DatePicker("", selection: $dueDate, in: Date()..., displayedComponents: .date)
                                        .datePickerStyle(.graphical)
                                        .tint(Color(hex: "#F5A623"))
                                        .colorScheme(.dark)
                                }
                            }
                        }

                        if let err = taskVM.errorMessage { ErrorBanner(message: err) }
                        Spacer().frame(height: 8)
                    }
                    .padding(.horizontal, 20)
                }

                // ── Pinned assign button ──────────────────────────────────
                VStack(spacing: 0) {
                    Divider().background(Color.white.opacity(0.08))

                    // Validation hint
                    if !canSubmit && !taskVM.isSaving {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.35))
                            Text(title.trimmingCharacters(in: .whitespaces).isEmpty
                                 ? "Enter a task title to continue"
                                 : "Select a team member to assign to")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .padding(.top, 10)
                    }

                    Button(action: {
                        guard let member = selectedMember else { return }
                        Task {
                            await taskVM.createTask(
                                communityID:   community.id,
                                communityName: community.name,
                                title:         title,
                                description:   description,
                                assignedTo:    member,
                                priority:      priority,
                                dueDate:       hasDueDate ? dueDate : nil,
                                leadEmail:     leadEmail
                            )
                            if taskVM.errorMessage == nil { dismiss() }
                        }
                    }) {
                        ZStack {
                            LinearGradient(
                                gradient: Gradient(colors: [Color(hex: "#F5A623"), Color(hex: "#E08C00")]),
                                startPoint: .leading, endPoint: .trailing)
                                .cornerRadius(14)
                                .shadow(color: Color(hex: "#F5A623").opacity(0.3), radius: 8, x: 0, y: 4)
                            if taskVM.isSaving {
                                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                HStack(spacing: 8) {
                                    Image(systemName: "paperplane.fill")
                                    Text("Assign Task")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity).frame(height: 54)
                    }
                    .disabled(!canSubmit)
                    .opacity(canSubmit ? 1 : 0.4)
                    .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 32)
                }
                .background(Color(hex: "#1A1A2E").opacity(0.95))
            }
        }
    }
}
