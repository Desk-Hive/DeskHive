//
//  EmployeeAnnouncementsView.swift
//  DeskHive
//

import SwiftUI

struct EmployeeAnnouncementsView: View {
    @StateObject private var annVM   = AnnouncementViewModel()

    @State private var selectedSegment: Int = 0   // 0=Announcements 1=Work
    @EnvironmentObject var appState: AppState

    // Total unread badge count
    private var totalUnread: Int {
        annVM.announcements.count + annVM.taskNotifications.count + annVM.personalAnnouncements.count
    }

    var body: some View {
        VStack(spacing: 0) {

            // ── Top bar ──────────────────────────────────────────────────
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Inbox")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Announcements, Work & Issue Updates")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.45))
                }
                Spacer()
                if totalUnread > 0 {
                    ZStack {
                        Circle().fill(Color(hex: "#E94560")).frame(width: 22, height: 22)
                        Text("\(min(totalUnread, 99))")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 14)

            // ── 2-segment control ────────────────────────────────────────
            HStack(spacing: 6) {
                segmentBtn(title: "Announcements", icon: "megaphone.fill",         idx: 0, badge: annVM.announcements.count + annVM.personalAnnouncements.count)
                segmentBtn(title: "Work",          icon: "checklist",               idx: 1, badge: annVM.taskNotifications.count)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)

            // ── Content ──────────────────────────────────────────────────
            ScrollView(showsIndicators: true) {
                VStack(spacing: 16) {
                    switch selectedSegment {
                    case 0: announcementsSection
                    default: workSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            annVM.startListening()
            if let uid = appState.currentUser?.id {
                Task { await annVM.fetchPersonal(for: uid) }
            }
        }
        .onDisappear { annVM.stopListening() }
    }

    // MARK: - Segment button
    private func segmentBtn(title: String, icon: String, idx: Int, badge: Int) -> some View {
        let active = selectedSegment == idx
        return Button(action: { withAnimation(.easeInOut(duration: 0.2)) { selectedSegment = idx } }) {
            ZStack(alignment: .topTrailing) {
                HStack(spacing: 5) {
                    Image(systemName: icon).font(.system(size: 11))
                    Text(title).font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(active ? .white : .white.opacity(0.4))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(active ? Color.white.opacity(0.12) : Color.clear)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(active ? Color.white.opacity(0.2) : Color.clear, lineWidth: 1))

                // Badge dot
                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(3)
                        .background(Color(hex: "#E94560"))
                        .clipShape(Circle())
                        .offset(x: 4, y: -4)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedSegment)
    }

    // ================================================================
    // MARK: - SEGMENT 0: Announcements (admin broadcasts + promotion)
    // ================================================================
    private var announcementsSection: some View {
        VStack(spacing: 14) {
            // Promotion / credentials cards
            ForEach(annVM.personalAnnouncements) { ann in
                CredentialsCard(announcement: ann)
            }

            if annVM.isLoading {
                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .padding(.top, 20)
            } else if annVM.announcements.isEmpty && annVM.personalAnnouncements.isEmpty {
                inboxEmpty(icon: "megaphone",
                           title: "No Announcements",
                           subtitle: "HR/Admin announcements will appear here.")
            } else {
                ForEach(annVM.announcements) { ann in
                    AnnouncementCard(announcement: ann)
                }
            }
        }
    }

    // ================================================================
    // MARK: - SEGMENT 1: Work (task assignment notifications)
    // ================================================================
    private var workSection: some View {
        VStack(spacing: 14) {
            if annVM.isLoading {
                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#A78BFA")))
                    .padding(.top, 20)
            } else if annVM.taskNotifications.isEmpty {
                inboxEmpty(icon: "checklist",
                           title: "No Work Assigned",
                           subtitle: "Task assignments from your project lead will appear here.")
            } else {
                ForEach(annVM.taskNotifications) { ann in
                    TaskNotificationCard(announcement: ann)
                }
            }
        }
    }

    private func inboxEmpty(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 44)).foregroundColor(.white.opacity(0.18))
            Text(title).font(.system(size: 16, weight: .semibold)).foregroundColor(.white.opacity(0.4))
            Text(subtitle).font(.system(size: 13)).foregroundColor(.white.opacity(0.3)).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.top, 40)
    }

}

// MARK: - Task Notification Card

struct TaskNotificationCard: View {
    let announcement: Announcement

    var priorityColor: Color { Color(hex: announcement.priority.color) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "#A78BFA").opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "checklist")
                        .font(.system(size: 17))
                        .foregroundColor(Color(hex: "#A78BFA"))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("New Task Assigned")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "#A78BFA"))
                    Text(relativeDate(announcement.createdAt))
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.35))
                }
                Spacer()
                // Priority badge
                HStack(spacing: 4) {
                    Image(systemName: announcement.priority.icon).font(.system(size: 9))
                    Text(announcement.priority.label).font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(priorityColor)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(priorityColor.opacity(0.12))
                .cornerRadius(5)
            }

            // Title
            Text(announcement.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)

            // Body
            Text(announcement.body)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color(hex: "#A78BFA").opacity(0.05))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(Color(hex: "#A78BFA").opacity(0.2), lineWidth: 1))
    }

    private func relativeDate(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter(); f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Credentials Card (Project Lead promotion notification)

struct CredentialsCard: View {
    let announcement: Announcement
    @State private var copied = false

    private var tempPassword: String {
        announcement.body.components(separatedBy: "\n")
            .first { $0.contains("Temporary Password:") }?
            .components(separatedBy: "Temporary Password:").last?
            .trimmingCharacters(in: .whitespaces) ?? ""
    }

    private var email: String {
        announcement.body.components(separatedBy: "\n")
            .first { $0.contains("Email:") && !$0.contains("Temporary") }?
            .components(separatedBy: "Email:").last?
            .trimmingCharacters(in: .whitespaces) ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(Color(hex: "#F5A623").opacity(0.15)).frame(width: 42, height: 42)
                    Image(systemName: "crown.fill").foregroundColor(Color(hex: "#F5A623")).font(.system(size: 18))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Project Lead Promotion").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                    Text(relativeDate(announcement.createdAt)).font(.system(size: 11)).foregroundColor(.white.opacity(0.4))
                }
                Spacer()
                Text("NEW").font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Color(hex: "#E94560")).cornerRadius(5)
            }
            Text(announcement.title).font(.system(size: 14, weight: .semibold)).foregroundColor(Color(hex: "#F5A623"))
            Divider().background(Color.white.opacity(0.1))
            VStack(alignment: .leading, spacing: 10) {
                Text("🔑 Your Login Credentials").font(.system(size: 13, weight: .semibold)).foregroundColor(.white.opacity(0.7))
                credRow(label: "Email",    value: email)
                credRow(label: "Password", value: tempPassword)
            }
            .padding(12)
            .background(Color(hex: "#F5A623").opacity(0.07)).cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#F5A623").opacity(0.2), lineWidth: 1))

            Button(action: {
                UIPasteboard.general.string = "Email: \(email)\nPassword: \(tempPassword)"
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc.fill").font(.system(size: 13))
                    Text(copied ? "Copied!" : "Copy Credentials").font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(copied ? Color(hex: "#4ECDC4") : Color(hex: "#F5A623"))
                .frame(maxWidth: .infinity).padding(.vertical, 10)
                .background(copied ? Color(hex: "#4ECDC4").opacity(0.1) : Color(hex: "#F5A623").opacity(0.1))
                .cornerRadius(10)
            }
            Text("Log out and sign back in using these credentials to access your Project Lead dashboard.")
                .font(.system(size: 11)).foregroundColor(.white.opacity(0.4))
        }
        .padding(16)
        .background(Color(hex: "#F5A623").opacity(0.05)).cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "#F5A623").opacity(0.3), lineWidth: 1))
    }

    private func credRow(label: String, value: String) -> some View {
        HStack {
            Text(label + ":").font(.system(size: 12, weight: .semibold)).foregroundColor(.white.opacity(0.5)).frame(width: 70, alignment: .leading)
            Text(value).font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(.white).lineLimit(1)
            Spacer()
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter(); f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Announcement Card

struct AnnouncementCard: View {
    let announcement: Announcement
    var priorityColor: Color { Color(hex: announcement.priority.color) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: announcement.priority.icon).font(.system(size: 11))
                    Text(announcement.priority.label).font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(priorityColor)
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background(priorityColor.opacity(0.12)).cornerRadius(7)
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(priorityColor.opacity(0.35), lineWidth: 1))
                Spacer()
                Text(relativeDate(announcement.createdAt)).font(.system(size: 11)).foregroundColor(.white.opacity(0.35))
            }
            Text(announcement.title).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
            Text(announcement.body).font(.system(size: 13)).foregroundColor(.white.opacity(0.65)).fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(priorityColor.opacity(0.05)).cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(priorityColor.opacity(0.2), lineWidth: 1))
    }

    private func relativeDate(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter(); f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }
}
