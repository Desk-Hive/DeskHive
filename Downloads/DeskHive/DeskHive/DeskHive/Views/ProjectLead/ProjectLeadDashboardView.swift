//
//  ProjectLeadDashboardView.swift
//  DeskHive
//

import SwiftUI

struct ProjectLeadDashboardView: View {
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
                        Text(appState.currentUser?.email.components(separatedBy: "@").first?.capitalized ?? "Lead")
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
                        RoleBannerCard(role: .projectLead)
                            .padding(.horizontal, 24)

                        // Profile card
                        DeskHiveCard {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: "#F5A623").opacity(0.2))
                                        .frame(width: 54, height: 54)
                                    Text((appState.currentUser?.email.prefix(1) ?? "L").uppercased())
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(Color(hex: "#F5A623"))
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(appState.currentUser?.email ?? "")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text("Project Lead")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                Spacer()
                            }
                        }
                        .padding(.horizontal, 24)

                        // Stats row
                        HStack(spacing: 16) {
                            StatCard(title: "Projects", value: "—", icon: "folder.fill", color: Color(hex: "#F5A623"))
                            StatCard(title: "Tasks", value: "—", icon: "checklist", color: Color(hex: "#4ECDC4"))
                        }
                        .padding(.horizontal, 24)

                        // Details
                        DeskHiveCard {
                            VStack(alignment: .leading, spacing: 14) {
                                InfoRow(icon: "calendar", title: "Member since", value: formattedDate(appState.currentUser?.createdAt))
                                Divider().background(Color.white.opacity(0.1))
                                InfoRow(icon: "star.fill", title: "Role", value: "Project Lead")
                                Divider().background(Color.white.opacity(0.1))
                                InfoRow(icon: "envelope", title: "Email", value: appState.currentUser?.email ?? "—")
                            }
                        }
                        .padding(.horizontal, 24)

                        // Placeholder projects section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("My Projects")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)

                            EmptyStateView(
                                icon: "folder.badge.plus",
                                title: "No Projects Yet",
                                subtitle: "Projects assigned to you will appear here."
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

#Preview {
    ProjectLeadDashboardView()
        .environmentObject(AppState())
}
