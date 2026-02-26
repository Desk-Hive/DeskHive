//
//  AdminDashboardView.swift
//  DeskHive
//

import SwiftUI

struct AdminDashboardView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var adminVM = AdminViewModel()
    @StateObject private var authVM = AuthViewModel()
    @StateObject private var communityVM = CommunityViewModel()

    @State private var selectedTab: AdminTab = .home
    @State private var showNews: Bool = false

    enum AdminTab {
        case home, employees, communities, announcements, issues
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                // Top navigation bar
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Welcome back,")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.white.opacity(0.6))
                        Text("Admin")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Button(action: { authVM.signOut(appState: appState) }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 38, height: 38)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 56)
                .padding(.bottom, 20)

                // Tab Selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        TabButton(title: "Home", icon: "square.grid.2x2", selected: selectedTab == .home) {
                            selectedTab = .home
                        }
                        TabButton(title: "Employees", icon: "person.3", selected: selectedTab == .employees) {
                            selectedTab = .employees
                            Task { await adminVM.fetchMembers() }
                        }
                        TabButton(title: "Communities", icon: "person.3.sequence.fill", selected: selectedTab == .communities) {
                            selectedTab = .communities
                        }
                        TabButton(title: "Announce", icon: "megaphone.fill", selected: selectedTab == .announcements) {
                            selectedTab = .announcements
                        }
                        TabButton(title: "Issues", icon: "exclamationmark.shield.fill", selected: selectedTab == .issues) {
                            selectedTab = .issues
                            Task { await adminVM.fetchIssues() }
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 20)

                // Content
                ScrollView(showsIndicators: true) {
                    if selectedTab == .home {
                        homeContent
                    } else if selectedTab == .employees {
                        employeesContent
                    } else if selectedTab == .communities {
                        AdminCommunitiesView(communityVM: communityVM, adminVM: adminVM)
                    } else if selectedTab == .announcements {
                        AdminAnnouncementsView()
                    } else {
                        AdminIssuesView(adminVM: adminVM)
                    }
                }
            }
        }
        .sheet(isPresented: $showNews) {
            TechNewsView()
        }
    }

    // MARK: - Home Tab
    var homeContent: some View {
        VStack(spacing: 20) {
            // Stats cards
            HStack(spacing: 16) {
                StatCard(
                    title: "Total Employees",
                    value: "\(adminVM.members.filter { $0.role == .employee }.count)",
                    icon: "person.2.fill",
                    color: Color(hex: "#4ECDC4")
                )
                StatCard(
                    title: "Communities",
                    value: "\(communityVM.communities.count)",
                    icon: "person.3.sequence.fill",
                    color: Color(hex: "#F5A623")
                )
            }
            .padding(.horizontal, 24)

            // Quick actions
            VStack(alignment: .leading, spacing: 14) {
                Text("Quick Actions")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                ActionCard(
                    title: "View Employees",
                    subtitle: "See all employees registered in the app",
                    icon: "person.3.fill",
                    color: Color(hex: "#4ECDC4")
                ) {
                    selectedTab = .employees
                    Task { await adminVM.fetchMembers() }
                }

                ActionCard(
                    title: "Microcommunities",
                    subtitle: "Create and manage project communities",
                    icon: "person.3.sequence.fill",
                    color: Color(hex: "#F5A623")
                ) {
                    selectedTab = .communities
                }

                ActionCard(
                    title: "Announcements",
                    subtitle: "Post official messages to all employees",
                    icon: "megaphone.fill",
                    color: Color(hex: "#4ECDC4")
                ) {
                    selectedTab = .announcements
                }

                ActionCard(
                    title: "Review Issues",
                    subtitle: "View and respond to anonymous reports",
                    icon: "exclamationmark.shield.fill",
                    color: Color(hex: "#A78BFA")
                ) {
                    selectedTab = .issues
                    Task { await adminVM.fetchIssues() }
                }
            }
            .padding(.horizontal, 24)

            // ── Tech News ────────────────────────────────────────────────
            NewsPreviewSection(accentColor: Color(hex: "#E94560")) {
                showNews = true
            }
            .padding(.horizontal, 24)

            Spacer().frame(height: 40)
        }
        .task {
            await adminVM.fetchMembers()
            await communityVM.fetchCommunities()
            await communityVM.fetchCommunities()
            await communityVM.fetchCommunities()
        }
    }

    // MARK: - Employees Tab (read-only)
    var employeesContent: some View {
        VStack(spacing: 16) {
            // Header
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
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .padding(.top, 40)
            } else if adminVM.members.isEmpty {
                EmptyStateView(
                    icon: "person.3",
                    title: "No Employees Yet",
                    subtitle: "Employees who sign up will appear here."
                )
                .padding(.top, 40)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(adminVM.members) { member in
                        EmployeeRow(member: member)
                    }
                }
                .padding(.horizontal, 24)
            }

            Spacer().frame(height: 40)
        }
    }
}

// MARK: - Supporting Views

struct TabButton: View {
    let title: String
    let icon: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(selected ? .white : .white.opacity(0.5))
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(selected ? Color.white.opacity(0.15) : Color.clear)
            .cornerRadius(10)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 20))
                Spacer()
            }
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.3), lineWidth: 1))
    }
}

struct ActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.2))
                        .frame(width: 50, height: 50)
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.system(size: 22))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.4))
                    .font(.system(size: 14))
            }
            .padding(16)
            .background(Color.white.opacity(0.08))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.12), lineWidth: 1))
        }
    }
}

struct EmployeeRow: View {
    let member: DeskHiveUser

    var roleColor: Color {
        switch member.role {
        case .employee:    return Color(hex: "#4ECDC4")
        case .projectLead: return Color(hex: "#F5A623")
        case .admin:       return Color(hex: "#E94560")
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(roleColor.opacity(0.2))
                    .frame(width: 46, height: 46)
                Text(member.email.prefix(1).uppercased())
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(roleColor)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(member.email)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                RoleBadge(role: member.role)
            }

            Spacer()

            // Joined date
            VStack(alignment: .trailing, spacing: 2) {
                Text("Joined")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.3))
                Text(shortDate(member.createdAt))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.07))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date)
    }
}

struct RoleBadge: View {
    let role: UserRole

    var body: some View {
        Text(role.displayName)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(badgeColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(badgeColor.opacity(0.15))
            .cornerRadius(6)
    }

    var badgeColor: Color {
        switch role {
        case .admin:       return Color(hex: "#E94560")
        case .projectLead: return Color(hex: "#F5A623")
        case .employee:    return Color(hex: "#4ECDC4")
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.3))
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    AdminDashboardView()
        .environmentObject(AppState())
}
