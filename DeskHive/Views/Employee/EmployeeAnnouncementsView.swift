//
//  EmployeeAnnouncementsView.swift
//  DeskHive
//

import SwiftUI

struct EmployeeAnnouncementsView: View {
    @StateObject private var annVM   = AnnouncementViewModel()
    @StateObject private var issueVM = IssueReportViewModel()

    @State private var selectedSegment: Int = 0   // 0=Announcements 1=Work 2=My Issues
    @State private var caseIDInput = ""
    @State private var showIssueReport = false
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

            // ── 3-segment control ────────────────────────────────────────
            HStack(spacing: 6) {
                segmentBtn(title: "Announcements", icon: "megaphone.fill",         idx: 0, badge: annVM.announcements.count + annVM.personalAnnouncements.count)
                segmentBtn(title: "Work",          icon: "checklist",               idx: 1, badge: annVM.taskNotifications.count)
                segmentBtn(title: "My Issues",     icon: "shield.lefthalf.filled",  idx: 2, badge: 0)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)

            // ── Content ──────────────────────────────────────────────────
            ScrollView(showsIndicators: true) {
                VStack(spacing: 16) {
                    switch selectedSegment {
                    case 0: announcementsSection
                    case 1: workSection
                    default: myIssuesSection
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
        .sheet(isPresented: $showIssueReport) {
            IssueReportView(viewModel: issueVM).environmentObject(appState)
        }
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

    // ================================================================
    // MARK: - SEGMENT 2: My Issues
    // ================================================================
    private var myIssuesSection: some View {
        VStack(spacing: 16) {
            // Case ID lookup
            DeskHiveCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Check Issue Status", systemImage: "magnifyingglass.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))

                    HStack(spacing: 10) {
                        Image(systemName: "number").foregroundColor(.white.opacity(0.4))
                        TextField("", text: $caseIDInput,
                                  prompt: Text("Enter Case ID  e.g. ISS-A3F9B2")
                                    .foregroundColor(.white.opacity(0.3)))
                            .foregroundColor(.white)
                            .tint(Color(hex: "#A78BFA"))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.characters)
                        if !caseIDInput.isEmpty {
                            Button(action: { caseIDInput = "" }) {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.white.opacity(0.3))
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(hex: "#A78BFA").opacity(0.3), lineWidth: 1))

                    Button(action: {
                        Task { await issueVM.lookupIssue(caseID: caseIDInput) }
                    }) {
                        HStack(spacing: 6) {
                            if issueVM.isLooking {
                                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.8)
                            } else {
                                Image(systemName: "magnifyingglass")
                                Text("Look Up").font(.system(size: 14, weight: .semibold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 42)
                        .background(LinearGradient(
                            gradient: Gradient(colors: [Color(hex: "#A78BFA"), Color(hex: "#7C3AED")]),
                            startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(10)
                    }
                    .disabled(caseIDInput.trimmingCharacters(in: .whitespaces).isEmpty || issueVM.isLooking)
                    .opacity(caseIDInput.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                }
            }

            if let err = issueVM.lookupError { ErrorBanner(message: err) }

            if let issue = issueVM.lookedUpIssue {
                issueDetailCard(issue).transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Divider().background(Color.white.opacity(0.08)).padding(.vertical, 4)

            Button(action: { showIssueReport = true }) {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(Color(hex: "#E94560")).font(.system(size: 18))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Submit a New Issue")
                            .font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                        Text("100% anonymous · get a Case ID instantly")
                            .font(.system(size: 11)).foregroundColor(.white.opacity(0.45))
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(.white.opacity(0.3)).font(.system(size: 12))
                }
                .padding(14)
                .background(Color(hex: "#E94560").opacity(0.07))
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#E94560").opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Issue detail card
    private func issueDetailCard(_ issue: IssueReport) -> some View {
        DeskHiveCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(issue.id)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.45))
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: issue.status.icon).font(.system(size: 10))
                        Text(issue.status.label).font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(Color(hex: issue.status.color))
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(Color(hex: issue.status.color).opacity(0.15))
                    .cornerRadius(7)
                }
                Divider().background(Color.white.opacity(0.1))
                HStack(spacing: 5) {
                    Image(systemName: issue.category.icon).font(.system(size: 11))
                    Text(issue.category.label).font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(Color(hex: issue.category.color))
                Text(issue.title).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                Text(issue.description).font(.system(size: 13)).foregroundColor(.white.opacity(0.6))
                HStack(spacing: 5) {
                    Image(systemName: "calendar").font(.system(size: 11))
                    Text(formattedDate(issue.createdAt)).font(.system(size: 11))
                }
                .foregroundColor(.white.opacity(0.35))
                if !issue.adminResponse.isEmpty {
                    Divider().background(Color.white.opacity(0.1))
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "bubble.left.fill").font(.system(size: 12)).foregroundColor(Color(hex: "#4ECDC4"))
                            Text("HR / Admin Response").font(.system(size: 12, weight: .semibold)).foregroundColor(Color(hex: "#4ECDC4"))
                        }
                        Text(issue.adminResponse)
                            .font(.system(size: 13)).foregroundColor(.white.opacity(0.85))
                            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(hex: "#4ECDC4").opacity(0.08)).cornerRadius(10)
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "clock").font(.system(size: 11)).foregroundColor(.white.opacity(0.3))
                        Text("Awaiting admin response…").font(.system(size: 12)).foregroundColor(.white.opacity(0.35))
                    }
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

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        return f.string(from: date)
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
