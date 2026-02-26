//
//  ProjectLeadDashboardView.swift
//  DeskHive
//

import SwiftUI
import FirebaseFirestore

struct ProjectLeadDashboardView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var authVM   = AuthViewModel()
    @StateObject private var issueVM  = IssueReportViewModel()
    @StateObject private var annVM    = AnnouncementViewModel()

    @State private var selectedTab: PLTab = .home
    @State private var myCommunity: Microcommunity? = nil
    @State private var communityMembers: [String] = []   // emails
    @State private var isLoadingCommunity = true
    @State private var showIssueReport = false
    @State private var showMyIssues    = false
    @State private var showFeed        = false
    @State private var showNews        = false

    enum PLTab { case home, project, tasks, inbox, profile }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Top Bar ──────────────────────────────────────────────
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Welcome back,")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.white.opacity(0.55))
                        Text(appState.currentUser?.email
                                .components(separatedBy: "@").first?.capitalized ?? "Lead")
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    // Crown badge
                    HStack(spacing: 5) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#F5A623"))
                        Text("Project Lead")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color(hex: "#F5A623").opacity(0.12))
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(hex: "#F5A623").opacity(0.3), lineWidth: 1))
                }
                .padding(.horizontal, 24)
                .padding(.top, 56)
                .padding(.bottom, 16)

                // ── Content ──────────────────────────────────────────────
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 0) {
                        switch selectedTab {
                        case .home:    homeTab
                        case .project: projectTab
                        case .tasks:   tasksTab
                        case .inbox:   inboxTab
                        case .profile: profileTab
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // ── Bottom Tab Bar ───────────────────────────────────────────
            bottomTabBar
        }
        .ignoresSafeArea(edges: .top)
        .sheet(isPresented: $showIssueReport) {
            IssueReportView(viewModel: issueVM).environmentObject(appState)
        }
        .sheet(isPresented: $showMyIssues) {
            MyIssuesView(viewModel: issueVM).environmentObject(appState)
        }
        .sheet(isPresented: $showNews) {
            TechNewsView()
        }
        .fullScreenCover(isPresented: $showFeed) {
            if let community = myCommunity {
                CommunityFeedView(
                    community: community,
                    senderEmail: appState.currentUser?.email ?? "",
                    senderID:    appState.currentUser?.id    ?? "",
                    isAdmin: false
                )
            }
        }
        .task {
            await fetchMyCommunity()
            if let uid = appState.currentUser?.id {
                await annVM.fetchPersonal(for: uid)
            }
            annVM.startListening()
        }
        .onDisappear { annVM.stopListening() }
    }

    // ====================================================================
    // MARK: - Bottom Tab Bar
    // ====================================================================
    private var bottomTabBar: some View {
        HStack(spacing: 0) {
            tabItem(icon: "house.fill",          label: "Home",    tab: .home)
            tabItem(icon: "folder.fill",          label: "Project", tab: .project)
            tabItem(icon: "checklist",            label: "Tasks",   tab: .tasks)
            tabItem(icon: "bell.badge.fill",      label: "Inbox",   tab: .inbox)
            tabItem(icon: "person.crop.circle",   label: "Profile", tab: .profile)
        }
        .padding(.horizontal, 8).padding(.top, 12).padding(.bottom, 28)
        .background(Color(hex: "#1A1A2E").opacity(0.97).ignoresSafeArea(edges: .bottom))
        .overlay(Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1), alignment: .top)
    }

    private func tabItem(icon: String, label: String, tab: PLTab) -> some View {
        let active = selectedTab == tab
        return Button(action: { withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab } }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: active ? .semibold : .regular))
                    .foregroundColor(active ? Color(hex: "#F5A623") : .white.opacity(0.35))
                    .scaleEffect(active ? 1.1 : 1.0)
                Text(label)
                    .font(.system(size: 10, weight: active ? .semibold : .regular))
                    .foregroundColor(active ? Color(hex: "#F5A623") : .white.opacity(0.35))
            }
            .frame(maxWidth: .infinity)
        }
        .animation(.easeInOut(duration: 0.2), value: selectedTab)
    }

    private var leadEmail: String { appState.currentUser?.email ?? "" }

    // ====================================================================
    // MARK: - HOME Tab
    // ====================================================================
    private var homeTab: some View {
        VStack(spacing: 18) {

            // Hero project card
            if let c = myCommunity {
                heroProjectCard(c)
            } else if isLoadingCommunity {
                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#F5A623")))
                    .frame(maxWidth: .infinity).padding(.vertical, 40)
            } else {
                noProjectCard
            }

            // Quick actions
            sectionLabel("Quick Actions")
            DeskHiveCard {
                VStack(spacing: 0) {
                    if myCommunity != nil {
                        qRow(icon: "folder.fill",
                             title: "View My Project",
                             color: Color(hex: "#F5A623")) {
                            withAnimation { selectedTab = .project }
                        }
                        divider()
                        qRow(icon: "checklist",
                             title: "Team Tasks",
                             color: Color(hex: "#A78BFA")) {
                            withAnimation { selectedTab = .tasks }
                        }
                        divider()
                        qRow(icon: "bubble.left.and.bubble.right.fill",
                             title: "Open Team Feed",
                             color: Color(hex: "#4ECDC4")) { showFeed = true }
                        divider()
                    }
                    qRow(icon: "bell.badge.fill",
                         title: "Inbox & Announcements",
                         color: Color(hex: "#A78BFA")) {
                        withAnimation { selectedTab = .inbox }
                    }
                    divider()
                    qRow(icon: "exclamationmark.shield.fill",
                         title: "Report an Issue",
                         color: Color(hex: "#E94560")) { showIssueReport = true }
                    divider()
                    qRow(icon: "magnifyingglass.circle.fill",
                         title: "Track My Issue",
                         color: Color(hex: "#A78BFA")) { showMyIssues = true }
                }
            }

            // ── Tech News ────────────────────────────────────────────────
            NewsPreviewSection(accentColor: Color(hex: "#F5A623")) {
                showNews = true
            }

        }
        .padding(.top, 4)
    }

    // ====================================================================
    // MARK: - PROJECT Tab
    // ====================================================================
    private var projectTab: some View {
        VStack(spacing: 18) {
            sectionLabel("My Project")

            if isLoadingCommunity {
                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#F5A623")))
                    .frame(maxWidth: .infinity).padding(.vertical, 60)
            } else if let c = myCommunity {
                projectDetailView(c)
            } else {
                noProjectCard
            }
        }
        .padding(.top, 4)
    }

    // ====================================================================
    // MARK: - TASKS Tab
    // ====================================================================
    private var tasksTab: some View {
        VStack(spacing: 18) {
            sectionLabel("Team Tasks")
            if let c = myCommunity {
                ProjectLeadTasksView(community: c, leadEmail: leadEmail)
            } else if isLoadingCommunity {
                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#F5A623")))
                    .frame(maxWidth: .infinity).padding(.vertical, 60)
            } else {
                noProjectCard
            }
        }
        .padding(.top, 4)
    }

    // ====================================================================
    // MARK: - INBOX Tab
    // ====================================================================
    private var inboxTab: some View {
        ProjectLeadAnnouncementsView(
            community: myCommunity,
            leadEmail: leadEmail
        )
        .environmentObject(appState)
    }

    // ====================================================================
    // MARK: - PROFILE Tab
    // ====================================================================
    private var profileTab: some View {
        VStack(spacing: 18) {
            DeskHiveCard {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [Color(hex: "#F5A623"), Color(hex: "#E08C00")]),
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 72, height: 72)
                        Text((appState.currentUser?.email.prefix(1) ?? "L").uppercased())
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Text(appState.currentUser?.email ?? "")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    HStack(spacing: 5) {
                        Image(systemName: "crown.fill").font(.system(size: 11))
                        Text("Project Lead")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(Color(hex: "#F5A623"))
                    .padding(.horizontal, 14).padding(.vertical, 5)
                    .background(Color(hex: "#F5A623").opacity(0.12))
                    .cornerRadius(10)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 8)
            }

            if let c = myCommunity {
                DeskHiveCard {
                    VStack(alignment: .leading, spacing: 14) {
                        InfoRow(icon: "folder.fill",       title: "Project",   value: c.project.isEmpty ? "—" : c.project)
                        Divider().background(Color.white.opacity(0.1))
                        InfoRow(icon: "person.3.fill",     title: "Community", value: c.name)
                        Divider().background(Color.white.opacity(0.1))
                        InfoRow(icon: "person.2.fill",     title: "Members",   value: "\(c.memberIDs.count)")
                        Divider().background(Color.white.opacity(0.1))
                        InfoRow(icon: "calendar",          title: "Since",     value: formattedDate(appState.currentUser?.createdAt))
                    }
                }
            }

            sectionLabel("Account")
            DeskHiveCard {
                Button(action: { authVM.signOut(appState: appState) }) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().fill(Color(hex: "#E94560").opacity(0.15)).frame(width: 36, height: 36)
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(Color(hex: "#E94560")).font(.system(size: 15))
                        }
                        Text("Sign Out")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
    }

    // ====================================================================
    // MARK: - Sub-views
    // ====================================================================

    // Hero card on home tab
    private func heroProjectCard(_ c: Microcommunity) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top gradient header
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    gradient: Gradient(colors: [Color(hex: "#F5A623").opacity(0.8), Color(hex: "#E08C00").opacity(0.5)]),
                    startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(height: 110)
                .cornerRadius(16, corners: [.topLeft, .topRight])

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.9))
                        Text("YOU ARE THE PROJECT LEAD")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.85))
                            .tracking(1)
                    }
                    Text(c.project.isEmpty ? c.name : c.project)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(16)
            }

            // Bottom details
            VStack(alignment: .leading, spacing: 12) {
                if !c.name.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "person.3.sequence.fill")
                            .foregroundColor(Color(hex: "#F5A623"))
                            .font(.system(size: 13))
                        Text(c.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                if !c.description.isEmpty {
                    Text(c.description)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(2)
                }

                HStack(spacing: 16) {
                    Label("\(c.memberIDs.count) Members", systemImage: "person.2.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Button(action: { showFeed = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 11))
                            Text("Open Feed")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(Color(hex: "#F5A623"))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color(hex: "#F5A623").opacity(0.12))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(hex: "#F5A623").opacity(0.3), lineWidth: 1))
                    }
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.07))
            .cornerRadius(16, corners: [.bottomLeft, .bottomRight])
        }
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16)
            .stroke(Color(hex: "#F5A623").opacity(0.25), lineWidth: 1))
        .shadow(color: Color(hex: "#F5A623").opacity(0.15), radius: 12, x: 0, y: 6)
    }

    // Full project detail on Project tab
    private func projectDetailView(_ c: Microcommunity) -> some View {
        VStack(spacing: 16) {

            // Project name banner
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [Color(hex: "#F5A623"), Color(hex: "#E08C00")]),
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 68, height: 68)
                    Image(systemName: "folder.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                }
                Text(c.project.isEmpty ? "Unnamed Project" : c.project)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                HStack(spacing: 5) {
                    Image(systemName: "crown.fill").font(.system(size: 11))
                    Text("You are the Project Lead")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(Color(hex: "#F5A623"))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color(hex: "#F5A623").opacity(0.06))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "#F5A623").opacity(0.2), lineWidth: 1))

            // Stats
            HStack(spacing: 12) {
                StatCard(title: "Members",   value: "\(c.memberIDs.count)", icon: "person.2.fill",    color: Color(hex: "#4ECDC4"))
                StatCard(title: "Community", value: c.name.isEmpty ? "—" : c.name, icon: "person.3.sequence.fill", color: Color(hex: "#F5A623"))
            }

            // Description
            if !c.description.isEmpty {
                DeskHiveCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("About This Project", systemImage: "text.alignleft")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                        Text(c.description)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            // Team members list
            DeskHiveCard {
                VStack(alignment: .leading, spacing: 14) {
                    Label("Team Members", systemImage: "person.3.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))

                    if c.memberEmails.isEmpty {
                        Text("No members yet.")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.4))
                    } else {
                        ForEach(Array(zip(c.memberIDs, c.memberEmails)), id: \.0) { uid, email in
                            let isMe = uid == appState.currentUser?.id
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(isMe
                                              ? Color(hex: "#F5A623").opacity(0.2)
                                              : Color(hex: "#4ECDC4").opacity(0.15))
                                        .frame(width: 36, height: 36)
                                    Text(email.prefix(1).uppercased())
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(isMe ? Color(hex: "#F5A623") : Color(hex: "#4ECDC4"))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(email)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    if isMe {
                                        HStack(spacing: 3) {
                                            Image(systemName: "crown.fill").font(.system(size: 8))
                                            Text("You · Project Lead").font(.system(size: 10, weight: .semibold))
                                        }
                                        .foregroundColor(Color(hex: "#F5A623"))
                                    }
                                }
                                Spacer()
                            }
                            if uid != c.memberIDs.last {
                                Divider().background(Color.white.opacity(0.08))
                            }
                        }
                    }
                }
            }

            // Open feed button
            Button(action: { showFeed = true }) {
                HStack(spacing: 10) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: "#4ECDC4"))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Open Team Feed")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Post messages and communicate with your team")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.45))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white.opacity(0.3)).font(.system(size: 12))
                }
                .padding(14)
                .background(Color(hex: "#4ECDC4").opacity(0.07))
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(hex: "#4ECDC4").opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var noProjectCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "#F5A623").opacity(0.4))
            Text("No Project Assigned Yet")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
            Text("Your admin has not assigned a project community to you yet.")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.35))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16)
            .stroke(Color(hex: "#F5A623").opacity(0.15), lineWidth: 1))
    }

    // ====================================================================
    // MARK: - Helpers
    // ====================================================================
    private func sectionLabel(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Spacer()
        }
    }

    private func divider() -> some View {
        Divider().background(Color.white.opacity(0.08))
    }

    private func qRow(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(color.opacity(0.15)).frame(width: 36, height: 36)
                    Image(systemName: icon).foregroundColor(color).font(.system(size: 15))
                }
                Text(title).font(.system(size: 14, weight: .medium)).foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.white.opacity(0.25)).font(.system(size: 12))
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "—" }
        let f = DateFormatter(); f.dateStyle = .medium
        return f.string(from: date)
    }

    // Fetch the community where this user is the projectLead
    private func fetchMyCommunity() async {
        guard let uid = appState.currentUser?.id else {
            isLoadingCommunity = false
            return
        }
        isLoadingCommunity = true
        do {
            let snap = try await Firestore.firestore()
                .collection("communities")
                .getDocuments()
            myCommunity = snap.documents
                .compactMap { Microcommunity(id: $0.documentID, data: $0.data()) }
                .first { $0.projectLeadID == uid }
        } catch { }
        isLoadingCommunity = false
    }
}

#Preview {
    ProjectLeadDashboardView()
        .environmentObject(AppState())
}
