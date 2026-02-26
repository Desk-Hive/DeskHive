//
//  EmployeeDashboardView.swift
//  DeskHive
//

import SwiftUI

struct EmployeeDashboardView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var authVM    = AuthViewModel()
    @StateObject private var checkInVM = CheckInViewModel()
    @StateObject private var eomVM     = EmployeeOfMonthViewModel()

    @State private var selectedTab: EmployeeTab = .home
    @State private var showCheckIn    = false
    @State private var showIssueReport = false
    @State private var showMyIssues    = false
    @State private var showNews        = false
    @StateObject private var issueVM  = IssueReportViewModel()

    enum EmployeeTab { case home, communities, work, inbox, profile }

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
                                .components(separatedBy: "@").first?.capitalized ?? "Employee")
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    // Check-in status pill
                    HStack(spacing: 6) {
                        Circle()
                            .fill(checkInVM.hasCheckedInToday
                                  ? Color(hex: "#4ECDC4") : Color(hex: "#E94560"))
                            .frame(width: 8, height: 8)
                        Text(checkInVM.hasCheckedInToday ? "Checked In" : "Not Checked In")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(20)
                }
                .padding(.horizontal, 24)
                .padding(.top, 56)
                .padding(.bottom, 16)

                // ── Tab Content ──────────────────────────────────────────
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 0) {
                        switch selectedTab {
                        case .home:        homeTab
                        case .communities: communitiesTab
                        case .work:        workTab
                        case .inbox:       inboxTab
                        case .profile:     profileTab
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100) // room for tab bar
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // ── Bottom Tab Bar ───────────────────────────────────────────
            bottomTabBar
        }
        .ignoresSafeArea(edges: .top)
        .sheet(isPresented: $showCheckIn, onDismiss: {
            Task {
                if let uid = appState.currentUser?.id {
                    await checkInVM.loadTodayStatus(uid: uid)
                    await checkInVM.loadRecentCheckIns(uid: uid)
                }
            }
        }) {
            CheckInView(viewModel: checkInVM).environmentObject(appState)
        }
        .sheet(isPresented: $showIssueReport) {
            IssueReportView(viewModel: issueVM).environmentObject(appState)
        }
        .sheet(isPresented: $showMyIssues) {
            MyIssuesView(viewModel: issueVM).environmentObject(appState)
        }
        .sheet(isPresented: $showNews) {
            TechNewsView()
        }
        .task {
            if let uid = appState.currentUser?.id {
                await checkInVM.loadTodayStatus(uid: uid)
                await checkInVM.loadRecentCheckIns(uid: uid)
            }
            eomVM.startListening()
        }
        .onDisappear { eomVM.stopListening() }
    }

    // ====================================================================
    // MARK: - Bottom Tab Bar
    // ====================================================================
    private var bottomTabBar: some View {
        HStack(spacing: 0) {
            tabBarItem(icon: "house.fill",                label: "Home",        tab: .home)
            tabBarItem(icon: "person.3.sequence.fill",    label: "Communities", tab: .communities)
            tabBarItem(icon: "checklist",                 label: "My Work",     tab: .work)
            tabBarItem(icon: "bell.badge.fill",           label: "Inbox",       tab: .inbox)
            tabBarItem(icon: "person.crop.circle",        label: "Profile",     tab: .profile)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 28)
        .background(
            Color(hex: "#1A1A2E")
                .opacity(0.97)
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1),
            alignment: .top
        )
    }

    private func tabBarItem(icon: String, label: String, tab: EmployeeTab) -> some View {
        let active = selectedTab == tab
        return Button(action: { withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab } }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: active ? .semibold : .regular))
                    .foregroundColor(active ? Color(hex: "#4ECDC4") : .white.opacity(0.35))
                    .scaleEffect(active ? 1.1 : 1.0)
                Text(label)
                    .font(.system(size: 10, weight: active ? .semibold : .regular))
                    .foregroundColor(active ? Color(hex: "#4ECDC4") : .white.opacity(0.35))
            }
            .frame(maxWidth: .infinity)
        }
        .animation(.easeInOut(duration: 0.2), value: selectedTab)
    }

    // ====================================================================
    // MARK: - HOME Tab
    // ====================================================================
    private var homeTab: some View {
        VStack(spacing: 18) {

            // ── Daily Check-in card ──────────────────────────────────────
            Button(action: { showCheckIn = true }) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(checkInVM.hasCheckedInToday
                                  ? Color(hex: "#4ECDC4").opacity(0.2)
                                  : Color(hex: "#E94560").opacity(0.15))
                            .frame(width: 52, height: 52)
                        if checkInVM.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else if checkInVM.hasCheckedInToday, let mood = checkInVM.todayMood {
                            Text(mood.emoji).font(.system(size: 24))
                        } else {
                            Image(systemName: "hand.tap.fill")
                                .foregroundColor(Color(hex: "#E94560"))
                                .font(.system(size: 22))
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(checkInVM.hasCheckedInToday ? "Checked In ✓" : "Daily Check-in")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        Text(checkInVM.hasCheckedInToday
                             ? "Feeling \(checkInVM.todayMood?.label ?? "great") today"
                             : "Tap to check in — takes 10 seconds")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.55))
                    }
                    Spacer()
                    Image(systemName: checkInVM.hasCheckedInToday
                          ? "checkmark.circle.fill" : "chevron.right")
                        .foregroundColor(checkInVM.hasCheckedInToday
                                         ? Color(hex: "#4ECDC4") : .white.opacity(0.3))
                }
                .padding(16)
                .background(Color.white.opacity(0.07))
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(
                    checkInVM.hasCheckedInToday
                    ? Color(hex: "#4ECDC4").opacity(0.35)
                    : Color(hex: "#E94560").opacity(0.25), lineWidth: 1))
            }

            // ── Stats row ───────────────────────────────────────────────
            HStack(spacing: 12) {
                StatCard(title: "Check-ins",
                         value: "\(checkInVM.recentCheckIns.count)",
                         icon: "checkmark.circle.fill",
                         color: Color(hex: "#4ECDC4"))
                StatCard(title: "Streak",
                         value: streakCount(),
                         icon: "flame.fill",
                         color: Color(hex: "#F5A623"))
            }

            // ── Employee of the Month ────────────────────────────────────
            if let award = eomVM.current {
                EmployeeOfMonthCard(
                    award: award,
                    isHighlighted: award.employeeID == appState.currentUser?.id
                )
            } else {
                EmployeeOfMonthEmptyCard()
            }

            // ── Quick actions ────────────────────────────────────────────
            sectionHeader("Quick Actions")
            DeskHiveCard {
                VStack(spacing: 0) {
                    quickRow(icon: "person.3.sequence.fill",
                             title: "My Communities",
                             color: Color(hex: "#4ECDC4")) {
                        withAnimation { selectedTab = .communities }
                    }

                    divider()

                    quickRow(icon: "checklist",
                             title: "My Work",
                             color: Color(hex: "#A78BFA")) {
                        withAnimation { selectedTab = .work }
                    }

                    divider()

                    quickRow(icon: "bell.badge.fill",
                             title: "Inbox & Announcements",
                             color: Color(hex: "#E94560")) {
                        withAnimation { selectedTab = .inbox }
                    }

                    divider()

                    quickRow(icon: "exclamationmark.shield.fill",
                             title: "Report a Workplace Issue",
                             color: Color(hex: "#E94560")) {
                        showIssueReport = true
                    }

                    divider()

                    quickRow(icon: "magnifyingglass.circle.fill",
                             title: "Track My Issue",
                             color: Color(hex: "#A78BFA")) {
                        showMyIssues = true
                    }

                    divider()

                    quickRow(icon: "bell",
                             title: "Notifications",
                             color: Color(hex: "#A78BFA")) {
                        withAnimation { selectedTab = .inbox }
                    }
                }
            }

            // ── Tech News ────────────────────────────────────────────────
            NewsPreviewSection(accentColor: Color(hex: "#4ECDC4")) {
                showNews = true
            }

        }
        .padding(.top, 4)
    }

    // ====================================================================
    // MARK: - COMMUNITIES Tab
    // ====================================================================
    private var communitiesTab: some View {
        VStack(spacing: 18) {
            sectionHeader("My Communities")

            EmployeeCommunitiesView(
                employeeID:    appState.currentUser?.id    ?? "",
                employeeEmail: appState.currentUser?.email ?? ""
            )
        }
        .padding(.top, 4)
    }

    // ====================================================================
    // MARK: - WORK Tab (My assigned tasks)
    // ====================================================================
    private var workTab: some View {
        VStack(spacing: 18) {
            sectionHeader("My Work")
            EmployeeMyWorkView(employeeID: appState.currentUser?.id ?? "")
        }
        .padding(.top, 4)
    }

    // ====================================================================
    // MARK: - INBOX Tab (Announcements + Issues)
    // ====================================================================
    private var inboxTab: some View {
        EmployeeAnnouncementsView()
            .environmentObject(appState)
    }

    // ====================================================================
    // MARK: - PROFILE Tab
    // ====================================================================
    private var profileTab: some View {
        VStack(spacing: 18) {
            // Avatar card
            DeskHiveCard {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [Color(hex: "#4ECDC4"), Color(hex: "#44A8B3")]),
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 72, height: 72)
                        Text((appState.currentUser?.email.prefix(1) ?? "E").uppercased())
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Text(appState.currentUser?.email ?? "")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Employee")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#4ECDC4"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color(hex: "#4ECDC4").opacity(0.12))
                        .cornerRadius(8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            // Stats
            HStack(spacing: 12) {
                StatCard(title: "Check-ins",
                         value: "\(checkInVM.recentCheckIns.count)",
                         icon: "checkmark.circle.fill",
                         color: Color(hex: "#4ECDC4"))
                StatCard(title: "Streak",
                         value: streakCount(),
                         icon: "flame.fill",
                         color: Color(hex: "#F5A623"))
            }

            // Account actions
            sectionHeader("Account")
            DeskHiveCard {
                VStack(spacing: 0) {
                    quickRow(icon: "rectangle.portrait.and.arrow.right",
                             title: "Sign Out",
                             color: Color(hex: "#E94560")) {
                        authVM.signOut(appState: appState)
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    // ====================================================================
    // MARK: - Helpers
    // ====================================================================
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Spacer()
        }
    }

    private func divider() -> some View {
        Divider().background(Color.white.opacity(0.08))
    }

    private func quickRow(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(color.opacity(0.15)).frame(width: 36, height: 36)
                    Image(systemName: icon).foregroundColor(color).font(.system(size: 15))
                }
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.25))
                    .font(.system(size: 12))
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private func quickRow(icon: String, title: String, subtitle: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(color.opacity(0.15)).frame(width: 38, height: 38)
                    Image(systemName: icon).foregroundColor(color).font(.system(size: 16))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.45))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.25))
                    .font(.system(size: 12))
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private func streakCount() -> String {
        let keys = checkInVM.recentCheckIns.map { $0.dateKey }.sorted(by: >)
        guard !keys.isEmpty else { return "0" }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        var streak = 0; var check = Date()
        for key in keys {
            if key == f.string(from: check) {
                streak += 1
                check = Calendar.current.date(byAdding: .day, value: -1, to: check)!
            } else { break }
        }
        return "\(streak)"
    }
}

// MARK: - Issue Step Row
private struct IssueStepRow: View {
    let number: String
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(Color(hex: "#E94560").opacity(0.15)).frame(width: 24, height: 24)
                Text(number).font(.system(size: 11, weight: .bold)).foregroundColor(Color(hex: "#E94560"))
            }
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }
}

#Preview {
    EmployeeDashboardView().environmentObject(AppState())
}
