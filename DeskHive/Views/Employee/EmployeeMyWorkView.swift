//
//  EmployeeMyWorkView.swift
//  DeskHive
//
//  Employee view: see assigned tasks, mark in-progress or done.
//

import SwiftUI

struct EmployeeMyWorkView: View {
    let employeeID: String

    @StateObject private var taskVM = TaskViewModel()
    @State private var filterStatus: TaskStatus? = nil

    private var filtered: [CommunityTask] {
        guard let f = filterStatus else { return taskVM.tasks }
        return taskVM.tasks.filter { $0.status == f }
    }

    private var pendingCount: Int { taskVM.tasks.filter { $0.status != .done }.count }
    private var doneCount:    Int { taskVM.tasks.filter { $0.status == .done }.count }

    var body: some View {
        VStack(spacing: 16) {

            // ── Header banner ────────────────────────────────────────────
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "#A78BFA").opacity(0.15))
                        .frame(width: 46, height: 46)
                    Image(systemName: "checklist")
                        .foregroundColor(Color(hex: "#A78BFA"))
                        .font(.system(size: 20))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("My Work")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Text("\(pendingCount) pending · \(doneCount) completed")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }
                Spacer()
            }
            .padding(14)
            .background(Color.white.opacity(0.06))
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "#A78BFA").opacity(0.2), lineWidth: 1))

            // ── Filter chips ─────────────────────────────────────────────
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    workFilterChip(label: "All",         icon: "tray.full",                   color: "#FFFFFF", active: filterStatus == nil)       { filterStatus = nil }
                    workFilterChip(label: "To Do",       icon: TaskStatus.todo.icon,       color: TaskStatus.todo.color,       active: filterStatus == .todo)       { filterStatus = .todo }
                    workFilterChip(label: "In Progress", icon: TaskStatus.inProgress.icon, color: TaskStatus.inProgress.color, active: filterStatus == .inProgress) { filterStatus = .inProgress }
                    workFilterChip(label: "Done",        icon: TaskStatus.done.icon,       color: TaskStatus.done.color,       active: filterStatus == .done)       { filterStatus = .done }
                }
                .padding(.horizontal, 2)
            }

            if let err = taskVM.errorMessage { ErrorBanner(message: err) }

            // ── Task list ────────────────────────────────────────────────
            if taskVM.isLoading {
                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#A78BFA")))
                    .frame(maxWidth: .infinity).padding(.vertical, 40)
            } else if filtered.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: taskVM.tasks.isEmpty ? "checklist" : "checkmark.seal.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.white.opacity(0.18))
                    Text(taskVM.tasks.isEmpty ? "No tasks assigned yet" : "All caught up! 🎉")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                    if taskVM.tasks.isEmpty {
                        Text("Your project lead will assign tasks to you here.")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.3))
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                VStack(spacing: 10) {
                    ForEach(filtered) { task in
                        EmployeeTaskCard(task: task, taskVM: taskVM)
                    }
                }
            }
        }
        .task { await taskVM.fetchMyTasks(employeeID: employeeID) }
    }

    private func workFilterChip(label: String, icon: String, color: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11))
                Text(label).font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(active ? Color(hex: color) : .white.opacity(0.45))
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(active ? Color(hex: color).opacity(0.15) : Color.white.opacity(0.06))
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20)
                .stroke(active ? Color(hex: color).opacity(0.4) : Color.white.opacity(0.1), lineWidth: 1))
        }
    }
}

// MARK: - Employee Task Card

struct EmployeeTaskCard: View {
    let task: CommunityTask
    @ObservedObject var taskVM: TaskViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Top: priority + status
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: task.priority.icon).font(.system(size: 10))
                    Text(task.priority.label).font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(Color(hex: task.priority.color))
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color(hex: task.priority.color).opacity(0.12))
                .cornerRadius(6)

                Spacer()

                // Community tag
                if !task.communityName.isEmpty {
                    Text(task.communityName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(6)
                }

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
            }

            // Title
            Text(task.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(task.status == .done ? .white.opacity(0.45) : .white)
                .strikethrough(task.status == .done, color: .white.opacity(0.3))

            if !task.description.isEmpty {
                Text(task.description)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(3)
            }

            // Assigned by + due date
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill").font(.system(size: 9)).foregroundColor(Color(hex: "#F5A623").opacity(0.7))
                    Text("From: \(task.assignedByEmail.components(separatedBy: "@").first ?? task.assignedByEmail)")
                        .font(.system(size: 11)).foregroundColor(.white.opacity(0.4))
                }
                if let due = task.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar").font(.system(size: 10))
                        Text("Due \(shortDate(due))")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(due < Date() && task.status != .done
                                     ? Color(hex: "#E94560") : .white.opacity(0.4))
                }
                Spacer()
            }

            // Action buttons (only if not done)
            if task.status != .done {
                HStack(spacing: 10) {
                    if task.status == .todo {
                        actionBtn(label: "Start",       icon: "play.fill",             color: "#F5A623") {
                            Task { await taskVM.updateStatus(task: task, newStatus: .inProgress) }
                        }
                    }
                    actionBtn(label: "Mark as Done", icon: "checkmark.circle.fill",  color: "#4ECDC4") {
                        Task { await taskVM.updateStatus(task: task, newStatus: .done) }
                    }
                }
            } else if let done = task.completedAt {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 12)).foregroundColor(Color(hex: "#4ECDC4"))
                    Text("Completed \(shortDate(done))").font(.system(size: 11)).foregroundColor(Color(hex: "#4ECDC4").opacity(0.8))
                }
            }
        }
        .padding(14)
        .background(task.status == .done ? Color.white.opacity(0.04) : Color.white.opacity(0.08))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16)
            .stroke(task.status == .done
                    ? Color(hex: "#4ECDC4").opacity(0.2)
                    : Color.white.opacity(0.1), lineWidth: 1))
    }

    private func actionBtn(label: String, icon: String, color: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 12))
                Text(label).font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(Color(hex: color))
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Color(hex: color).opacity(0.12))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(Color(hex: color).opacity(0.3), lineWidth: 1))
        }
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMM d"
        return f.string(from: date)
    }
}
