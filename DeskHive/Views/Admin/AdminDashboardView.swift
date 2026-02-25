//
//  AdminDashboardView.swift
//  DeskHive
//

import SwiftUI

struct AdminDashboardView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var adminVM = AdminViewModel()
    @StateObject private var authVM = AuthViewModel()

    @State private var selectedTab: AdminTab = .home
    @State private var showAddMemberSheet = false

    enum AdminTab {
        case home, members
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
                    Button(action: {
                        authVM.signOut(appState: appState)
                    }) {
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
                HStack(spacing: 0) {
                    TabButton(title: "Home", icon: "square.grid.2x2", selected: selectedTab == .home) {
                        selectedTab = .home
                    }
                    TabButton(title: "Members", icon: "person.3", selected: selectedTab == .members) {
                        selectedTab = .members
                        Task { await adminVM.fetchMembers() }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)

                // Content
                ScrollView(showsIndicators: false) {
                    if selectedTab == .home {
                        homeContent
                    } else {
                        membersContent
                    }
                }
            }
        }
        .sheet(isPresented: $showAddMemberSheet) {
            AddMemberSheet(adminVM: adminVM)
        }
    }

    // MARK: - Home Tab
    var homeContent: some View {
        VStack(spacing: 20) {
            // Stats cards
            HStack(spacing: 16) {
                StatCard(
                    title: "Total Members",
                    value: "\(adminVM.members.filter { $0.role == .member }.count)",
                    icon: "person.2.fill",
                    color: Color(hex: "#4ECDC4")
                )
                StatCard(
                    title: "Project Leads",
                    value: "\(adminVM.members.filter { $0.role == .projectLead }.count)",
                    icon: "star.fill",
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
                    title: "Add New Member",
                    subtitle: "Create member account & send credentials",
                    icon: "person.badge.plus",
                    color: Color(hex: "#E94560")
                ) {
                    showAddMemberSheet = true
                }

                ActionCard(
                    title: "Manage Members",
                    subtitle: "View and manage all team members",
                    icon: "person.3.fill",
                    color: Color(hex: "#4ECDC4")
                ) {
                    selectedTab = .members
                    Task { await adminVM.fetchMembers() }
                }
            }
            .padding(.horizontal, 24)

            Spacer().frame(height: 40)
        }
        .task {
            await adminVM.fetchMembers()
        }
    }

    // MARK: - Members Tab
    var membersContent: some View {
        VStack(spacing: 16) {
            // Header row
            HStack {
                Text("Team Members")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Button(action: { showAddMemberSheet = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("Add")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(hex: "#E94560"))
                    .cornerRadius(10)
                }
            }
            .padding(.horizontal, 24)

            if let msg = adminVM.successMessage {
                SuccessBanner(message: msg).padding(.horizontal, 24)
            }
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
                    title: "No Members Yet",
                    subtitle: "Add your first team member to get started."
                )
                .padding(.top, 40)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(adminVM.members) { member in
                        MemberRow(member: member) {
                            Task { await adminVM.toggleRole(for: member) }
                        }
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

struct MemberRow: View {
    let member: DeskHiveUser
    let toggleAction: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(avatarColor(for: member.role).opacity(0.2))
                    .frame(width: 46, height: 46)
                Text(member.email.prefix(1).uppercased())
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(avatarColor(for: member.role))
            }

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(member.email)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                RoleBadge(role: member.role)
            }

            Spacer()

            // Toggle button
            Button(action: toggleAction) {
                Text(member.role == .member ? "Make Lead" : "Remove Lead")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(member.role == .member ? Color(hex: "#F5A623") : Color(hex: "#4ECDC4"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background((member.role == .member ? Color(hex: "#F5A623") : Color(hex: "#4ECDC4")).opacity(0.15))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke((member.role == .member ? Color(hex: "#F5A623") : Color(hex: "#4ECDC4")).opacity(0.4), lineWidth: 1)
                    )
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.07))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    func avatarColor(for role: UserRole) -> Color {
        switch role {
        case .member: return Color(hex: "#4ECDC4")
        case .projectLead: return Color(hex: "#F5A623")
        case .admin: return Color(hex: "#E94560")
        }
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
        case .admin: return Color(hex: "#E94560")
        case .projectLead: return Color(hex: "#F5A623")
        case .member: return Color(hex: "#4ECDC4")
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
