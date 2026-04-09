//
//  ProjectLeadAnnouncementsView.swift
//  DeskHive
//
//  Project Lead inbox: post announcements to team, see work notifications, track issues.
//

import SwiftUI
import FirebaseFirestore

struct ProjectLeadAnnouncementsView: View {
    let community: Microcommunity?
    let leadEmail: String

    @StateObject private var annVM   = AnnouncementViewModel()
    @StateObject private var issueVM = IssueReportViewModel()

    @State private var selectedSegment: Int = 0
    @State private var showPostSheet   = false
    @State private var caseIDInput     = ""
    @State private var showIssueReport = false
    @EnvironmentObject var appState: AppState

    private var totalUnread: Int {
        annVM.announcements.count + annVM.personalAnnouncements.count + annVM.taskNotifications.count
    }

    var body: some View {
        VStack(spacing: 0) {

            // ── Top bar ──────────────────────────────────────────────────
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Inbox")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Announcements & Updates")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.45))
                }
                Spacer()
                // Post announcement button
                Button(action: { showPostSheet = true }) {
                    HStack(spacing: 5) {
                        Image(systemName: "megaphone.fill")
                            .font(.system(size: 12))
                        Text("Post")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(LinearGradient(
                        gradient: Gradient(colors: [Color(hex: "#A78BFA"), Color(hex: "#7C3AED")]),
                        startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(10)
                    .shadow(color: Color(hex: "#A78BFA").opacity(0.3), radius: 6, x: 0, y: 3)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 14)

            // ── Segment control ──────────────────────────────────────────
            HStack(spacing: 6) {
                segmentBtn(title: "Announcements", icon: "megaphone.fill",        idx: 0, badge: annVM.announcements.count + annVM.personalAnnouncements.count)
                segmentBtn(title: "Work",          icon: "checklist",              idx: 1, badge: annVM.taskNotifications.count)
                segmentBtn(title: "My Issues",     icon: "shield.lefthalf.filled", idx: 2, badge: 0)
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
        .sheet(isPresented: $showPostSheet) {
            LeadPostAnnouncementSheet(
                community:  community,
                leadEmail:  leadEmail,
                annVM:      annVM
            )
        }
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
                .background(active ? Color(hex: "#A78BFA").opacity(0.2) : Color.clear)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(active ? Color(hex: "#A78BFA").opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1))

                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white).padding(3)
                        .background(Color(hex: "#E94560")).clipShape(Circle())
                        .offset(x: 4, y: -4)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedSegment)
    }

    // ================================================================
    // MARK: - SEGMENT 0: Announcements
    // ================================================================
    private var announcementsSection: some View {
        VStack(spacing: 14) {
            // Hint card
            HStack(spacing: 10) {
                Image(systemName: "megaphone.fill")
                    .foregroundColor(Color(hex: "#A78BFA")).font(.system(size: 16))
                Text("Tap **Post** to send an announcement to your team or to all employees.")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            .padding(12)
            .background(Color(hex: "#A78BFA").opacity(0.07))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#A78BFA").opacity(0.2), lineWidth: 1))

            // Promotion cards
            ForEach(annVM.personalAnnouncements) { ann in
                CredentialsCard(announcement: ann)
            }

            if annVM.isLoading {
                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#A78BFA")))
                    .padding(.top, 20)
            } else if annVM.announcements.isEmpty && annVM.personalAnnouncements.isEmpty {
                inboxEmpty(icon: "megaphone",
                           title: "No Announcements Yet",
                           subtitle: "Tap Post above to create and send your first announcement to the team.")
            } else {
                ForEach(annVM.announcements) { ann in
                    AnnouncementCard(announcement: ann)
                }
            }
        }
    }

    // ================================================================
    // MARK: - SEGMENT 1: Work notifications
    // ================================================================
    private var workSection: some View {
        VStack(spacing: 14) {
            if annVM.isLoading {
                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#A78BFA")))
                    .padding(.top, 20)
            } else if annVM.taskNotifications.isEmpty {
                inboxEmpty(icon: "checklist",
                           title: "No Work Notifications",
                           subtitle: "Notifications for tasks you receive will appear here.")
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
                    .background(Color.white.opacity(0.06)).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(hex: "#A78BFA").opacity(0.3), lineWidth: 1))

                    Button(action: { Task { await issueVM.lookupIssue(caseID: caseIDInput) } }) {
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
                    Image(systemName: "plus.circle.fill").foregroundColor(Color(hex: "#E94560")).font(.system(size: 18))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Submit a New Issue").font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                        Text("100% anonymous · get a Case ID instantly").font(.system(size: 11)).foregroundColor(.white.opacity(0.45))
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(.white.opacity(0.3)).font(.system(size: 12))
                }
                .padding(14)
                .background(Color(hex: "#E94560").opacity(0.07)).cornerRadius(14)
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
                    .background(Color(hex: issue.status.color).opacity(0.15)).cornerRadius(7)
                }
                Divider().background(Color.white.opacity(0.1))
                Text(issue.title).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                Text(issue.description).font(.system(size: 13)).foregroundColor(.white.opacity(0.6))
                if !issue.adminResponse.isEmpty {
                    Divider().background(Color.white.opacity(0.1))
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "bubble.left.fill").font(.system(size: 12)).foregroundColor(Color(hex: "#4ECDC4"))
                            Text("Response").font(.system(size: 12, weight: .semibold)).foregroundColor(Color(hex: "#4ECDC4"))
                        }
                        Text(issue.adminResponse)
                            .font(.system(size: 13)).foregroundColor(.white.opacity(0.85))
                            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(hex: "#4ECDC4").opacity(0.08)).cornerRadius(10)
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "clock").font(.system(size: 11)).foregroundColor(.white.opacity(0.3))
                        Text("Awaiting response…").font(.system(size: 12)).foregroundColor(.white.opacity(0.35))
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
}

// MARK: - Post Announcement Sheet

struct LeadPostAnnouncementSheet: View {
    let community: Microcommunity?
    let leadEmail: String
    @ObservedObject var annVM: AnnouncementViewModel
    @Environment(\.dismiss) var dismiss

    @State private var title       = ""
    @State private var body_text   = ""
    @State private var priority    = Announcement.AnnouncementPriority.info
    @State private var targetType  = TargetType.community

    enum TargetType: String, CaseIterable {
        case community = "My Team"
        case all       = "All Employees"
        var icon: String { self == .community ? "person.3.fill" : "person.crop.circle.fill" }
        var color: String { self == .community ? "#A78BFA" : "#4ECDC4" }
    }

    var db = Firestore.firestore()
    @State private var isSaving = false
    @State private var errorMsg: String? = nil

    var canPost: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !body_text.trimmingCharacters(in: .whitespaces).isEmpty &&
        !isSaving
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
                    Text("Post Announcement")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Color.clear.frame(width: 34, height: 34)
                }
                .padding(.horizontal, 20).padding(.top, 56).padding(.bottom, 16)

                ScrollView(showsIndicators: true) {
                    VStack(spacing: 18) {

                        // Header icon
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "#A78BFA").opacity(0.15))
                                    .frame(width: 60, height: 60)
                                Image(systemName: "megaphone.fill")
                                    .font(.system(size: 26))
                                    .foregroundColor(Color(hex: "#A78BFA"))
                            }
                            Text("Project Lead Announcement")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(hex: "#A78BFA"))
                            Text("Compose a message for your team or all employees")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .padding(.top, 4)

                        // Send to
                        DeskHiveCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("Send To", systemImage: "paperplane.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.6))
                                HStack(spacing: 10) {
                                    ForEach(TargetType.allCases, id: \.self) { t in
                                        Button(action: { targetType = t }) {
                                            HStack(spacing: 6) {
                                                Image(systemName: t.icon).font(.system(size: 13))
                                                Text(t.rawValue).font(.system(size: 13, weight: .semibold))
                                            }
                                            .foregroundColor(targetType == t ? Color(hex: t.color) : .white.opacity(0.4))
                                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                                            .background(targetType == t ? Color(hex: t.color).opacity(0.15) : Color.white.opacity(0.05))
                                            .cornerRadius(10)
                                            .overlay(RoundedRectangle(cornerRadius: 10)
                                                .stroke(targetType == t ? Color(hex: t.color).opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1))
                                        }
                                    }
                                }
                                // Audience note
                                if targetType == .community, let c = community {
                                    HStack(spacing: 5) {
                                        Image(systemName: "info.circle").font(.system(size: 11))
                                        Text("Will be sent to \(c.memberIDs.count) member\(c.memberIDs.count == 1 ? "" : "s") of \"\(c.name)\"")
                                            .font(.system(size: 11))
                                    }
                                    .foregroundColor(.white.opacity(0.35))
                                } else if targetType == .all {
                                    HStack(spacing: 5) {
                                        Image(systemName: "info.circle").font(.system(size: 11))
                                        Text("Will be visible to all employees in the app")
                                            .font(.system(size: 11))
                                    }
                                    .foregroundColor(.white.opacity(0.35))
                                }
                            }
                        }

                        // Title
                        DeskHiveCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Title *", systemImage: "pencil")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.6))
                                TextField("", text: $title,
                                          prompt: Text("e.g. Team standup moved to 10am")
                                            .foregroundColor(.white.opacity(0.3)))
                                    .foregroundColor(.white)
                                    .tint(Color(hex: "#A78BFA"))
                            }
                        }

                        // Message
                        DeskHiveCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Message *", systemImage: "text.alignleft")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.6))
                                TextField("", text: $body_text,
                                          prompt: Text("Write your announcement here…")
                                            .foregroundColor(.white.opacity(0.3)),
                                          axis: .vertical)
                                    .foregroundColor(.white)
                                    .tint(Color(hex: "#A78BFA"))
                                    .lineLimit(4...10)
                            }
                        }

                        // Priority
                        DeskHiveCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("Priority", systemImage: "flag.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.6))
                                HStack(spacing: 8) {
                                    ForEach(Announcement.AnnouncementPriority.allCases, id: \.self) { p in
                                        Button(action: { priority = p }) {
                                            VStack(spacing: 4) {
                                                Image(systemName: p.icon).font(.system(size: 15))
                                                    .foregroundColor(priority == p ? Color(hex: p.color) : .white.opacity(0.3))
                                                Text(p.label).font(.system(size: 11, weight: .semibold))
                                                    .foregroundColor(priority == p ? Color(hex: p.color) : .white.opacity(0.35))
                                            }
                                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                                            .background(priority == p ? Color(hex: p.color).opacity(0.15) : Color.white.opacity(0.05))
                                            .cornerRadius(10)
                                            .overlay(RoundedRectangle(cornerRadius: 10)
                                                .stroke(priority == p ? Color(hex: p.color).opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1))
                                        }
                                    }
                                }
                            }
                        }

                        if let err = errorMsg { ErrorBanner(message: err) }
                        Spacer().frame(height: 8)
                    }
                    .padding(.horizontal, 20)
                }

                // ── Pinned Post button ────────────────────────────────────
                VStack(spacing: 0) {
                    Divider().background(Color.white.opacity(0.08))

                    if !canPost && !isSaving {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle").font(.system(size: 11)).foregroundColor(.white.opacity(0.35))
                            Text(title.trimmingCharacters(in: .whitespaces).isEmpty
                                 ? "Enter a title to continue"
                                 : "Enter a message to continue")
                                .font(.system(size: 12)).foregroundColor(.white.opacity(0.4))
                        }
                        .padding(.top, 10)
                    }

                    Button(action: { Task { await postAnnouncement() } }) {
                        ZStack {
                            LinearGradient(
                                gradient: Gradient(colors: [Color(hex: "#A78BFA"), Color(hex: "#7C3AED")]),
                                startPoint: .leading, endPoint: .trailing)
                                .cornerRadius(14)
                                .shadow(color: Color(hex: "#A78BFA").opacity(0.3), radius: 8, x: 0, y: 4)
                            if isSaving {
                                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                HStack(spacing: 8) {
                                    Image(systemName: "paperplane.fill")
                                    Text("Post Announcement")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity).frame(height: 54)
                    }
                    .disabled(!canPost)
                    .opacity(canPost ? 1 : 0.4)
                    .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 32)
                }
                .background(Color(hex: "#1A1A2E").opacity(0.95))
            }
        }
    }

    // MARK: - Post logic
    func postAnnouncement() async {
        let t = title.trimmingCharacters(in: .whitespaces)
        let b = body_text.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, !b.isEmpty else { return }

        isSaving = true
        errorMsg = nil

        if targetType == .all {
            // Broadcast to all — goes into every employee's Announcements segment
            await annVM.postAnnouncement(title: t, body: b, priority: priority)
            if annVM.errorMessage == nil { dismiss() }
            else { errorMsg = annVM.errorMessage }
        } else {
            // Send to each community member individually (type: task-like but "announcement")
            guard let c = community else {
                errorMsg = "No community found."
                isSaving = false
                return
            }
            do {
                for uid in c.memberIDs {
                    let ref = db.collection("announcements").document()
                    let data: [String: Any] = [
                        "title":     "📢 \(t)",
                        "body":      "From your Project Lead (\(leadEmail.components(separatedBy: "@").first ?? leadEmail)):\n\n\(b)",
                        "priority":  priority.rawValue,
                        "targetUID": uid,
                        "type":      "task",    // shows in Work segment so employee sees it
                        "createdAt": Timestamp(date: Date())
                    ]
                    try await ref.setData(data)
                }
                isSaving = false
                dismiss()
            } catch {
                errorMsg = "Failed to post: \(error.localizedDescription)"
                isSaving = false
            }
        }
    }
}
