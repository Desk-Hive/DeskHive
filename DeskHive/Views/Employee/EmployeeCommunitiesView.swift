//
//  EmployeeCommunitiesView.swift
//  DeskHive
//
//  Shows communities the logged-in employee belongs to,
//  and lets them open the feed for each.
//

import SwiftUI

struct EmployeeCommunitiesView: View {
    let employeeID: String
    let employeeEmail: String

    @StateObject private var communityVM = CommunityViewModel()
    @State private var selectedCommunity: Microcommunity? = nil

    // Only communities this employee is a member of
    private var myCommunities: [Microcommunity] {
        communityVM.communities.filter { $0.memberIDs.contains(employeeID) }
    }

    var body: some View {
        VStack(spacing: 20) {

            // Header banner
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "#4ECDC4").opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "person.3.sequence.fill")
                        .foregroundColor(Color(hex: "#4ECDC4"))
                        .font(.system(size: 22))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("My Communities")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Communities you've been added to")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }
                Spacer()
            }
            .padding(16)
            .background(Color.white.opacity(0.06))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "#4ECDC4").opacity(0.2), lineWidth: 1))

            if communityVM.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .padding(.top, 20)
            } else if myCommunities.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.3.sequence")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.2))
                    Text("No communities yet")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                    Text("Your admin will add you to a community.")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.3))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
            } else {
                VStack(spacing: 10) {
                    ForEach(myCommunities) { community in
                        Button(action: { selectedCommunity = community }) {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(hex: "#4ECDC4").opacity(0.12))
                                        .frame(width: 46, height: 46)
                                    Image(systemName: "bubble.left.and.bubble.right.fill")
                                        .foregroundColor(Color(hex: "#4ECDC4"))
                                        .font(.system(size: 18))
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(community.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    if !community.project.isEmpty {
                                        Text(community.project)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(Color(hex: "#F5A623"))
                                    }
                                    if !community.projectLeadEmail.isEmpty {
                                        HStack(spacing: 3) {
                                            Image(systemName: "crown.fill")
                                                .font(.system(size: 9))
                                            Text("Lead: \(community.projectLeadEmail.components(separatedBy: "@").first ?? community.projectLeadEmail)")
                                                .font(.system(size: 10, weight: .medium))
                                        }
                                        .foregroundColor(Color(hex: "#F5A623"))
                                    }
                                    Text("\(community.memberIDs.count) member\(community.memberIDs.count == 1 ? "" : "s")")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.4))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.white.opacity(0.3))
                                    .font(.system(size: 13))
                            }
                            .padding(14)
                            .background(Color.white.opacity(0.07))
                            .cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .fullScreenCover(item: $selectedCommunity) { community in
            CommunityFeedView(
                community: community,
                senderEmail: employeeEmail,
                senderID: employeeID,
                isAdmin: false
            )
        }
        .task { await communityVM.fetchCommunities() }
    }
}
