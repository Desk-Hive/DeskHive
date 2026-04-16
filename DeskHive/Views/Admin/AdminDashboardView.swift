//
//  AdminDashboardView.swift
//  DeskHive
//

import SwiftUI

struct AdminDashboardView: View {
    @EnvironmentObject var appState: AppState

    @StateObject private var adminVM     = AdminViewModel()
    @StateObject private var authVM      = AuthViewModel()
    @StateObject private var communityVM = CommunityViewModel()
    @StateObject private var eomVM       = EmployeeOfMonthViewModel()

    @State private var selectedTab: AdminTab = .home
    @State private var showNews: Bool = false
    @State private var showEOM: Bool  = false

    enum AdminTab { case home, employees, communities, announcements, issues, profile }

    private let accent = Color(hex: "#4ECDC4")
    private let gold   = Color(hex: "#F5A623")
    private let red    = Color(hex: "#E94560")

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {

                // ── Top navigation bar ─────────────────────────────
                HStack(alignment: .center) {
                    if selectedTab == .profile {
                        Button(action: { withAnimation { selectedTab = .home } }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                                .frame(width: 34, height: 34)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Welcome back,")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.white.opacity(0.6))
                        Text("Admin")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    // Profile button in top-right
                    if selectedTab != .profile {
                        Button(action: { withAnimation { selectedTab = .profile } }) {
                            ZStack {
                                Circle()
                                    .fill(accent.opacity(0.15))
                                    .frame(width: 38, height: 38)
                                Image(systemName: "person.crop.circle")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(accent)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 56)
                .padding(.bottom, 16)

                // ── Horizontal Tab Selector (hidden on profile) ────
                if selectedTab != .profile {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            TabButton(title: "Home", icon: "square.grid.2x2", selected: selectedTab == .home) { selectedTab = .home }
                            TabButton(title: "Employees", icon: "person.3", selected: selectedTab == .employees) { selectedTab = .employees; Task { await adminVM.fetchMembers() } }
                            TabButton(title: "Communities", icon: "person.3.sequence.fill", selected: selectedTab == .communities) { selectedTab = .communities }
                            TabButton(title: "Announce", icon: "megaphone.fill", selected: selectedTab == .announcements) { selectedTab = .announcements }
                            TabButton(title: "Issues", icon: "exclamationmark.shield.fill", selected: selectedTab == .issues) { selectedTab = .issues; Task { await adminVM.fetchIssues() } }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 4)
                    }
                    .padding(.bottom, 12)
                }

                // ── Content ────────────────────────────────────────
                ScrollView(showsIndicators: true) {
                    switch selectedTab {
                    case .home:          homeContent
                    case .employees:     panelBackButton { selectedTab = .home }; employeesContent
                    case .communities:   panelBackButton { selectedTab = .home }; AdminCommunitiesView(communityVM: communityVM, adminVM: adminVM)
                    case .announcements: panelBackButton { selectedTab = .home }; AdminAnnouncementsView()
                    case .issues:        panelBackButton { selectedTab = .home }; AdminIssuesView(adminVM: adminVM)
                    case .profile:       adminProfileContent
                    }
                }
            }
        }
        .sheet(isPresented: $showNews) { TechNewsView() }
        .sheet(isPresented: $showEOM) {
            AdminEmployeeOfMonthView(vm: eomVM, members: adminVM.members, adminEmail: appState.currentUser?.email ?? "")
        }
        .task {
            await adminVM.fetchMembers()
            await communityVM.fetchCommunities()
            eomVM.startListening()
        }
        .onDisappear { eomVM.stopListening() }
    }

    // MARK: - Back Button

    private func panelBackButton(action: @escaping () -> Void) -> some View {
        HStack {
            Button(action: action) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    // MARK: - Profile Content

    private var adminProfileContent: some View {
        VStack(spacing: 20) {
            // Avatar
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [accent, Color(hex: "#44A8B3")],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 80, height: 80)
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                }
                Text(appState.currentUser?.email ?? "Admin")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Administrator")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(accent)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(accent.opacity(0.12))
                    .cornerRadius(8)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 10)

            // Info card
            VStack(alignment: .leading, spacing: 14) {
                Label("Account Info", systemImage: "person.text.rectangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))
                Divider().background(Color.white.opacity(0.08))
                HStack(spacing: 12) {
                    Image(systemName: "envelope.fill").foregroundColor(accent).font(.system(size: 14)).frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Email").font(.system(size: 11)).foregroundColor(.white.opacity(0.4))
                        Text(appState.currentUser?.email ?? "\u{2014}").font(.system(size: 14, weight: .medium)).foregroundColor(.white.opacity(0.85))
                    }
                    Spacer()
                }
                HStack(spacing: 12) {
                    Image(systemName: "shield.fill").foregroundColor(accent).font(.system(size: 14)).frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Role").font(.system(size: 11)).foregroundColor(.white.opacity(0.4))
                        Text("Admin").font(.system(size: 14, weight: .medium)).foregroundColor(.white.opacity(0.85))
                    }
                    Spacer()
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.07))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
            .padding(.horizontal, 24)

            // Sign Out
            Button(action: { authVM.signOut(appState: appState) }) {
                HStack(spacing: 12) {
                    Image(systemName: "rectangle.portrait.and.arrow.right").foregroundColor(red).font(.system(size: 18))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sign Out").font(.system(size: 15, weight: .semibold)).foregroundColor(red)
                        Text("You will be logged out").font(.system(size: 12)).foregroundColor(.white.opacity(0.4))
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(red.opacity(0.5)).font(.system(size: 13))
                }
                .padding(16)
                .background(red.opacity(0.08))
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(red.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)

            Spacer().frame(height: 40)
        }
    }

    // MARK: - Home Tab

    var homeContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 16) {
                StatCard(title: "Total Employees",
                         value: "\(adminVM.members.filter { $0.role == .employee }.count)",
                         icon: "person.2.fill", color: accent)
                StatCard(title: "Micro Communities",
                         value: "\(communityVM.communities.count)",
                         icon: "person.3.sequence.fill", color: gold)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)

            // Quick Actions
            VStack(alignment: .leading, spacing: 10) {
                Text("Quick Actions")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase).tracking(0.8)
                    .padding(.horizontal, 24)

                VStack(spacing: 10) {
                    ActionCard(title: "View Employees", subtitle: "See all employees registered in the app",
                               icon: "person.3.fill", color: accent) {
                        selectedTab = .employees; Task { await adminVM.fetchMembers() }
                    }
                    ActionCard(title: "Micro Communities", subtitle: "Create and manage project micro communities",
                               icon: "person.3.sequence.fill", color: gold) {
                        selectedTab = .communities
                    }
                    ActionCard(title: "Announcements", subtitle: "Post official messages to all employees",
                               icon: "megaphone.fill", color: accent) {
                        selectedTab = .announcements
                    }
                    ActionCard(title: "Review Issues", subtitle: "View and respond to anonymous reports",
                               icon: "exclamationmark.shield.fill", color: Color(hex: "#A78BFA")) {
                        selectedTab = .issues; Task { await adminVM.fetchIssues() }
                    }
                    ActionCard(title: "Employee of the Month", subtitle: "Spotlight a star employee this month",
                               icon: "trophy.fill", color: gold) {
                        showEOM = true
                    }
                }
                .padding(.horizontal, 24)
            }

            // Employee of the Month
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Employee of the Month")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase).tracking(0.8)
                    Spacer()
                    Button(action: { showEOM = true }) {
                        HStack(spacing: 4) {
                            Text(eomVM.current == nil ? "Select" : "Change")
                                .font(.system(size: 12, weight: .semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(gold)
                    }
                }
                .padding(.horizontal, 24)

                Group {
                    if let award = eomVM.current {
                        EmployeeOfMonthCard(award: award)
                    } else {
                        EmployeeOfMonthEmptyCard()
                    }
                }
                .padding(.horizontal, 24)
            }

            // Tech News
            VStack(alignment: .leading, spacing: 10) {
                Text("Tech News")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase).tracking(0.8)
                    .padding(.horizontal, 24)

                NewsPreviewSection(accentColor: red) { showNews = true }
                    .padding(.horizontal, 24)
            }

            Spacer().frame(height: 40)
        }
    }

    // MARK: - Employees Tab

    var employeesContent: some View {
        VStack(spacing: 16) {
            HStack {
                Text("All Employees")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text("\(adminVM.members.count) total")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 24)

            if let err = adminVM.errorMessage {
                ErrorBanner(message: err).padding(.horizontal, 24)
            }

            if adminVM.isLoading {
                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).padding(.top, 40)
            } else if adminVM.members.isEmpty {
                EmptyStateView(icon: "person.3", title: "No Employees Yet", subtitle: "Employees who sign up will appear here.").padding(.top, 40)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(adminVM.members) { member in EmployeeRow(member: member) }
                }
                .padding(.horizontal, 24)
            }
            Spacer().frame(height: 40)
        }
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let title: String; let icon: String; let selected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                Text(title).font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(selected ? .white : .white.opacity(0.5))
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(selected ? Color.white.opacity(0.15) : Color.white.opacity(0.06))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String; let value: String; let icon: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Image(systemName: icon).foregroundColor(color).font(.system(size: 20)); Spacer() }
            Text(value).font(.system(size: 32, weight: .bold, design: .rounded)).foregroundColor(.white)
            Text(title).font(.system(size: 12, weight: .medium)).foregroundColor(.white.opacity(0.6))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08)).cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - Action Card

struct ActionCard: View {
    let title: String; let subtitle: String; let icon: String; let color: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.2)).frame(width: 50, height: 50)
                    Image(systemName: icon).foregroundColor(color).font(.system(size: 22))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Image(systemName: "chevron.right").foregroundColor(.white.opacity(0.35)).font(.system(size: 12, weight: .medium))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.08)).cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Employee Row

struct EmployeeRow: View {
    let member: DeskHiveUser
    var roleColor: Color {
        switch member.role {
        case .employee: return Color(hex: "#4ECDC4")
        case .projectLead: return Color(hex: "#F5A623")
        case .admin: return Color(hex: "#E94560")
        }
    }
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(roleColor.opacity(0.2)).frame(width: 46, height: 46)
                Text(member.email.prefix(1).uppercased()).font(.system(size: 18, weight: .bold)).foregroundColor(roleColor)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(member.email).font(.system(size: 14, weight: .semibold)).foregroundColor(.white).lineLimit(1)
                RoleBadge(role: member.role)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Joined").font(.system(size: 10)).foregroundColor(.white.opacity(0.3))
                Text(shortDate(member.createdAt)).font(.system(size: 11, weight: .medium)).foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(14).background(Color.white.opacity(0.07)).cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"; return f.string(from: date)
    }
}

// MARK: - Role Badge

struct RoleBadge: View {
    let role: UserRole
    var badgeColor: Color {
        switch role {
        case .admin: return Color(hex: "#E94560")
        case .projectLead: return Color(hex: "#F5A623")
        case .employee: return Color(hex: "#4ECDC4")
        }
    }
    var body: some View {
        Text(role.displayName).font(.system(size: 10, weight: .bold)).foregroundColor(badgeColor)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(badgeColor.opacity(0.15)).cornerRadius(6)
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let icon: String; let title: String; let subtitle: String
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon).font(.system(size: 48)).foregroundColor(.white.opacity(0.3))
            Text(title).font(.system(size: 18, weight: .semibold)).foregroundColor(.white.opacity(0.6))
            Text(subtitle).font(.system(size: 14)).foregroundColor(.white.opacity(0.4)).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    AdminDashboardView().environmentObject(AppState())
}
