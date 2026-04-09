//
//  AIProjectSelectionView.swift
//  DeskHive
//
//  Shows the list of communities this employee belongs to.
//  The employee taps a project to enter the AI chat grounded on its docs.
//

import SwiftUI

struct AIProjectSelectionView: View {

    let employeeID: String
    let employeeEmail: String

    @StateObject private var communityVM = CommunityViewModel()
    @Environment(\.dismiss) private var dismiss

    // Filtered to communities this employee is a member of
    private var myProjects: [Microcommunity] {
        communityVM.communities.filter {
            $0.memberIDs.contains(employeeID) || $0.memberEmails.contains(employeeEmail)
        }
    }

    var body: some View {
        ZStack {
            AppBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header ───────────────────────────────────────────────
                HStack(spacing: 12) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(10)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AI Assistant")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Select a project to start chatting")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                    // AI icon badge
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(colors: [Color(hex: "#7C3AED"), Color(hex: "#4ECDC4")],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .frame(width: 42, height: 42)
                        Image(systemName: "sparkles")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                Divider().background(Color.white.opacity(0.08))

                if communityVM.isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#7C3AED")))
                        .scaleEffect(1.4)
                    Spacer()
                } else if myProjects.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "tray.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.white.opacity(0.2))
                        Text("No projects assigned")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                        Text("You need to be added to a community\nby your admin to use AI chat.")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.35))
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 12) {
                            ForEach(myProjects) { community in
                            NavigationLink(destination:
                                AIChatView(community: community)
                            ) {
                                    ProjectAICard(community: community)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                }
            }
        }
        .task {
            await communityVM.fetchCommunities()
        }
    }
}

// MARK: - Project AI Card

private struct ProjectAICard: View {
    let community: Microcommunity

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#7C3AED").opacity(0.7), Color(hex: "#4ECDC4").opacity(0.6)],
                            startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 52, height: 52)
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(community.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                if !community.project.isEmpty {
                    Text(community.project)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#4ECDC4"))
                        .lineLimit(1)
                }
                if !community.description.isEmpty {
                    Text(community.description)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.45))
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.white.opacity(0.3))
                .font(.system(size: 13))
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(colors: [Color(hex: "#7C3AED").opacity(0.4), Color(hex: "#4ECDC4").opacity(0.3)],
                                   startPoint: .leading, endPoint: .trailing),
                    lineWidth: 1
                )
        )
    }
}
