//
//  MemberDashboardView.swift
//  DeskHive
//

import SwiftUI

struct MemberDashboardView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var authVM = AuthViewModel()

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Welcome,")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.white.opacity(0.6))
                        Text(appState.currentUser?.email.components(separatedBy: "@").first?.capitalized ?? "Member")
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
                .padding(.bottom, 28)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Role badge
                        RoleBannerCard(role: .member)
                            .padding(.horizontal, 24)

                        // Profile card
                        DeskHiveCard {
                            VStack(spacing: 16) {
                                HStack {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: "#4ECDC4").opacity(0.2))
                                            .frame(width: 54, height: 54)
                                        Text((appState.currentUser?.email.prefix(1) ?? "M").uppercased())
                                            .font(.system(size: 22, weight: .bold))
                                            .foregroundColor(Color(hex: "#4ECDC4"))
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(appState.currentUser?.email ?? "")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.white)
                                        Text("Team Member")
                                            .font(.system(size: 13))
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                    Spacer()
                                }
                            }
                        }
                        .padding(.horizontal, 24)

                        // Info section
                        DeskHiveCard {
                            VStack(alignment: .leading, spacing: 14) {
                                InfoRow(icon: "calendar", title: "Member since", value: formattedDate(appState.currentUser?.createdAt))
                                Divider().background(Color.white.opacity(0.1))
                                InfoRow(icon: "person.badge.key", title: "Role", value: "Member")
                                Divider().background(Color.white.opacity(0.1))
                                InfoRow(icon: "envelope", title: "Email", value: appState.currentUser?.email ?? "—")
                            }
                        }
                        .padding(.horizontal, 24)

                        // Placeholder task/project section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("My Tasks")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)

                            EmptyStateView(
                                icon: "checklist",
                                title: "No Tasks Yet",
                                subtitle: "Tasks assigned to you will appear here."
                            )
                            .padding(.top, 20)
                        }

                        Spacer().frame(height: 40)
                    }
                }
            }
        }
    }

    func formattedDate(_ date: Date?) -> String {
        guard let date = date else { return "—" }
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }
}

// MARK: - Role Banner Card
struct RoleBannerCard: View {
    let role: UserRole

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: roleIcon)
                .font(.system(size: 24))
                .foregroundColor(roleColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("Your Role")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                Text(role.displayName)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            Spacer()
            ZStack {
                Circle()
                    .fill(roleColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Circle()
                    .stroke(roleColor.opacity(0.3), lineWidth: 1)
                    .frame(width: 36, height: 36)
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(roleColor)
            }
        }
        .padding(16)
        .background(roleColor.opacity(0.08))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(roleColor.opacity(0.3), lineWidth: 1))
    }

    var roleColor: Color {
        switch role {
        case .admin: return Color(hex: "#E94560")
        case .projectLead: return Color(hex: "#F5A623")
        case .member: return Color(hex: "#4ECDC4")
        }
    }

    var roleIcon: String {
        switch role {
        case .admin: return "shield.checkered"
        case .projectLead: return "star.fill"
        case .member: return "person.fill"
        }
    }
}

// MARK: - Info Row
struct InfoRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 20)
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
        }
    }
}

#Preview {
    MemberDashboardView()
        .environmentObject(AppState())
}
