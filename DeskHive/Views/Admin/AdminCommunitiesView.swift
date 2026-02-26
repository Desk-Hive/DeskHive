//
//  AdminCommunitiesView.swift
//  DeskHive
//
//  Admin view to create and manage microcommunities.
//

import SwiftUI

// MARK: - Main list view

struct AdminCommunitiesView: View {
    @ObservedObject var communityVM: CommunityViewModel
    @ObservedObject var adminVM: AdminViewModel
    @EnvironmentObject var appState: AppState

    @State private var showCreateSheet = false
    @State private var selectedCommunity: Microcommunity? = nil

    var body: some View {
        VStack(spacing: 16) {

            // Header
            HStack {
                Text("Microcommunities")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Button(action: { showCreateSheet = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("New")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(hex: "#4ECDC4"))
                    .cornerRadius(10)
                }
            }
            .padding(.horizontal, 24)

            // Banners
            if let err = communityVM.errorMessage {
                ErrorBanner(message: err).padding(.horizontal, 24)
            }
            if let ok = communityVM.successMessage {
                SuccessBanner(message: ok).padding(.horizontal, 24)
            }

            // List or empty state
            if communityVM.isLoading {
                Spacer()
                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                Spacer()
            } else if communityVM.communities.isEmpty {
                EmptyStateView(
                    icon: "person.3.sequence.fill",
                    title: "No Communities Yet",
                    subtitle: "Tap 'New' to create your first microcommunity."
                )
                .padding(.top, 40)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(communityVM.communities) { community in
                        CommunityCard(community: community) {
                            selectedCommunity = community
                        } onDelete: {
                            Task { await communityVM.deleteCommunity(community) }
                        }
                    }
                }
                .padding(.horizontal, 24)
            }

            Spacer().frame(height: 40)
        }
        .sheet(isPresented: $showCreateSheet, onDismiss: {
            communityVM.successMessage = nil
        }) {
            CreateCommunitySheet(communityVM: communityVM, adminVM: adminVM)
        }
        .sheet(item: $selectedCommunity) { community in
            CommunityDetailSheet(community: community,
                                 communityVM: communityVM,
                                 adminVM: adminVM)
            .environmentObject(appState)
        }
        .task {
            await communityVM.fetchCommunities()
            if adminVM.members.isEmpty { await adminVM.fetchMembers() }
        }
    }
}

// MARK: - Community card row

private struct CommunityCard: View {
    let community: Microcommunity
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "#4ECDC4").opacity(0.15))
                        .frame(width: 50, height: 50)
                    Image(systemName: "person.3.sequence.fill")
                        .foregroundColor(Color(hex: "#4ECDC4"))
                        .font(.system(size: 20))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(community.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if !community.project.isEmpty {
                        Text(community.project)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(hex: "#F5A623"))
                    }

                    Text("\(community.memberIDs.count) member\(community.memberIDs.count == 1 ? "" : "s")")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#E94560").opacity(0.8))
                        .padding(8)
                        .background(Color(hex: "#E94560").opacity(0.1))
                        .cornerRadius(8)
                }

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

// MARK: - Create community sheet

struct CreateCommunitySheet: View {
    @ObservedObject var communityVM: CommunityViewModel
    @ObservedObject var adminVM: AdminViewModel
    @Environment(\.dismiss) var dismiss

    @State private var name        = ""
    @State private var description = ""
    @State private var project     = ""
    @State private var selectedIDs = Set<String>()

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: true) {
                VStack(spacing: 24) {
                    Spacer().frame(height: 20)

                    // Header
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#4ECDC4").opacity(0.15))
                                .frame(width: 64, height: 64)
                            Image(systemName: "person.3.sequence.fill")
                                .font(.system(size: 26))
                                .foregroundColor(Color(hex: "#4ECDC4"))
                        }
                        Text("New Microcommunity")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Group employees into a project community")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.5))
                    }

                    // Details card
                    DeskHiveCard {
                        VStack(spacing: 16) {
                            fieldBlock(label: "Community Name *", placeholder: "e.g. Alpha Team", text: $name)
                            Divider().background(Color.white.opacity(0.1))
                            fieldBlock(label: "Project", placeholder: "e.g. Project Apollo", text: $project)
                            Divider().background(Color.white.opacity(0.1))
                            fieldBlock(label: "Description", placeholder: "What does this community do?", text: $description, multiline: true)
                        }
                    }

                    // Member picker
                    DeskHiveCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Add Members")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.7))
                                Spacer()
                                Text("\(selectedIDs.count) selected")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "#4ECDC4"))
                            }

                            if adminVM.members.isEmpty {
                                Text("No employees found.")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.4))
                            } else {
                                ForEach(adminVM.members) { emp in
                                    let picked = selectedIDs.contains(emp.id)
                                    Button(action: {
                                        if picked { selectedIDs.remove(emp.id) }
                                        else      { selectedIDs.insert(emp.id) }
                                    }) {
                                        HStack(spacing: 12) {
                                            // Avatar
                                            ZStack {
                                                Circle()
                                                    .fill(Color(hex: "#4ECDC4").opacity(0.15))
                                                    .frame(width: 36, height: 36)
                                                Text(emp.email.prefix(1).uppercased())
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundColor(Color(hex: "#4ECDC4"))
                                            }
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(emp.email)
                                                    .font(.system(size: 13, weight: .medium))
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)
                                                Text(emp.role.displayName)
                                                    .font(.system(size: 11))
                                                    .foregroundColor(.white.opacity(0.4))
                                            }
                                            Spacer()
                                            Image(systemName: picked ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(picked ? Color(hex: "#4ECDC4") : .white.opacity(0.3))
                                                .font(.system(size: 20))
                                        }
                                    }
                                    .buttonStyle(.plain)

                                    if emp.id != adminVM.members.last?.id {
                                        Divider().background(Color.white.opacity(0.08))
                                    }
                                }
                            }
                        }
                    }

                    // Error
                    if let err = communityVM.errorMessage {
                        ErrorBanner(message: err)
                    }

                    // Create button
                    Button(action: {
                        let selected = adminVM.members.filter { selectedIDs.contains($0.id) }
                        Task {
                            await communityVM.createCommunity(
                                name: name,
                                description: description,
                                project: project,
                                selectedMembers: selected
                            )
                            if communityVM.errorMessage == nil { dismiss() }
                        }
                    }) {
                        ZStack {
                            LinearGradient(
                                gradient: Gradient(colors: [Color(hex: "#4ECDC4"), Color(hex: "#2AAFA5")]),
                                startPoint: .leading, endPoint: .trailing
                            )
                            .cornerRadius(14)
                            .shadow(color: Color(hex: "#4ECDC4").opacity(0.4), radius: 10, x: 0, y: 5)

                            if communityVM.isSaving {
                                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                HStack(spacing: 8) {
                                    Image(systemName: "person.3.sequence.fill")
                                    Text("Create Community")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                    }
                    .disabled(communityVM.isSaving || name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 24)
            }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 24)
                    .padding(.top, 56)
                }
                Spacer()
            }
        }
    }

    @ViewBuilder
    private func fieldBlock(label: String, placeholder: String, text: Binding<String>, multiline: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
            if multiline {
                TextField("", text: text,
                          prompt: Text(placeholder).foregroundColor(.white.opacity(0.3)),
                          axis: .vertical)
                    .lineLimit(3...6)
                    .foregroundColor(.white)
                    .tint(Color(hex: "#4ECDC4"))
            } else {
                TextField("", text: text,
                          prompt: Text(placeholder).foregroundColor(.white.opacity(0.3)))
                    .foregroundColor(.white)
                    .tint(Color(hex: "#4ECDC4"))
            }
        }
    }
}

// MARK: - Community detail / manage members sheet

struct CommunityDetailSheet: View {
    let community: Microcommunity
    @ObservedObject var communityVM: CommunityViewModel
    @ObservedObject var adminVM: AdminViewModel
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var showAddMember = false
    @State private var showFeed      = false

    // Live version of the community from the VM (reflects updates)
    private var live: Microcommunity {
        communityVM.communities.first(where: { $0.id == community.id }) ?? community
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: true) {
                VStack(spacing: 24) {
                    Spacer().frame(height: 20)

                    // Header
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#4ECDC4").opacity(0.15))
                                .frame(width: 64, height: 64)
                            Image(systemName: "person.3.sequence.fill")
                                .font(.system(size: 26))
                                .foregroundColor(Color(hex: "#4ECDC4"))
                        }
                        Text(live.name)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        if !live.project.isEmpty {
                            Text(live.project)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(hex: "#F5A623"))
                        }
                        if !live.description.isEmpty {
                            Text(live.description)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.5))
                                .multilineTextAlignment(.center)
                        }
                    }

                    // Stats
                    HStack(spacing: 16) {
                        StatCard(
                            title: "Members",
                            value: "\(live.memberIDs.count)",
                            icon: "person.2.fill",
                            color: Color(hex: "#4ECDC4")
                        )
                        StatCard(
                            title: "Project Lead",
                            value: live.projectLeadEmail.isEmpty
                                   ? "None"
                                   : live.projectLeadEmail.components(separatedBy: "@").first ?? "—",
                            icon: "crown.fill",
                            color: Color(hex: "#F5A623")
                        )
                    }

                    // Error banner
                    if let err = communityVM.errorMessage {
                        ErrorBanner(message: err)
                    }

                    // Open Feed button
                    Button(action: { showFeed = true }) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(hex: "#4ECDC4").opacity(0.15))
                                    .frame(width: 48, height: 48)
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .foregroundColor(Color(hex: "#4ECDC4"))
                                    .font(.system(size: 20))
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Community Feed")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("Post messages and view responses")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.07))
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#4ECDC4").opacity(0.25), lineWidth: 1))
                    }

                    // Member list
                    DeskHiveCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Members")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.7))
                                Spacer()
                                Button(action: { showAddMember = true }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus")
                                        Text("Add")
                                    }
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color(hex: "#4ECDC4"))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(hex: "#4ECDC4").opacity(0.12))
                                    .cornerRadius(8)
                                }
                            }

                            if live.memberEmails.isEmpty {
                                Text("No members yet. Tap Add to invite employees.")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.4))
                            } else {
                                ForEach(Array(zip(live.memberIDs, live.memberEmails)), id: \.0) { uid, email in
                                    let isLead = uid == live.projectLeadID
                                    HStack(spacing: 10) {
                                        // Avatar
                                        ZStack {
                                            Circle()
                                                .fill(isLead
                                                      ? Color(hex: "#F5A623").opacity(0.2)
                                                      : Color(hex: "#4ECDC4").opacity(0.15))
                                                .frame(width: 36, height: 36)
                                            Text(email.prefix(1).uppercased())
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(isLead
                                                                 ? Color(hex: "#F5A623")
                                                                 : Color(hex: "#4ECDC4"))
                                        }

                                        // Email + lead badge
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(email)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                            if isLead {
                                                HStack(spacing: 3) {
                                                    Image(systemName: "crown.fill")
                                                        .font(.system(size: 9))
                                                    Text("Project Lead")
                                                        .font(.system(size: 10, weight: .semibold))
                                                }
                                                .foregroundColor(Color(hex: "#F5A623"))
                                            }
                                        }

                                        Spacer()

                                        // Crown button — assign or unassign lead
                                        Button(action: {
                                            Task {
                                                if isLead {
                                                    await communityVM.removeProjectLead(from: live)
                                                } else {
                                                    if let member = adminVM.members.first(where: { $0.id == uid }) {
                                                        await communityVM.setProjectLead(member, in: live)
                                                    }
                                                }
                                            }
                                        }) {
                                            Image(systemName: isLead ? "crown.fill" : "crown")
                                                .font(.system(size: 16))
                                                .foregroundColor(isLead
                                                                 ? Color(hex: "#F5A623")
                                                                 : .white.opacity(0.25))
                                        }

                                        // Remove button
                                        Button(action: {
                                            Task { await communityVM.removeMember(uid, from: live) }
                                        }) {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundColor(Color(hex: "#E94560").opacity(0.7))
                                                .font(.system(size: 20))
                                        }
                                    }

                                    if uid != live.memberIDs.last {
                                        Divider().background(Color.white.opacity(0.08))
                                    }
                                }
                            }

                            // Lead hint
                            if !live.memberEmails.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(Color(hex: "#F5A623").opacity(0.6))
                                    Text("Tap the crown icon to assign or remove Project Lead")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.3))
                                }
                                .padding(.top, 4)
                            }
                        }
                    }

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 24)
            }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 24)
                    .padding(.top, 56)
                }
                Spacer()
            }
        }
        .sheet(isPresented: $showAddMember) {
            AddMemberToCommunitySheet(
                community: live,
                communityVM: communityVM,
                adminVM: adminVM
            )
        }
        .fullScreenCover(isPresented: $showFeed) {
            CommunityFeedView(
                community: live,
                senderEmail: appState.currentUser?.email ?? "Admin",
                senderID:    appState.currentUser?.id    ?? "admin",
                isAdmin: true
            )
            .environmentObject(appState)
        }
    }
}

// MARK: - Add member to existing community sheet

struct AddMemberToCommunitySheet: View {
    let community: Microcommunity
    @ObservedObject var communityVM: CommunityViewModel
    @ObservedObject var adminVM: AdminViewModel
    @Environment(\.dismiss) var dismiss

    // Employees not already in this community
    private var available: [DeskHiveUser] {
        adminVM.members.filter { !community.memberIDs.contains($0.id) }
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: true) {
                VStack(spacing: 20) {
                    Spacer().frame(height: 20)

                    VStack(spacing: 6) {
                        Text("Add to \(community.name)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Select an employee to add")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.5))
                    }

                    DeskHiveCard {
                        VStack(spacing: 0) {
                            if available.isEmpty {
                                Text("All employees are already in this community.")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.4))
                                    .padding(.vertical, 12)
                            } else {
                                ForEach(available) { emp in
                                    Button(action: {
                                        Task {
                                            await communityVM.addMember(emp, to: community)
                                            dismiss()
                                        }
                                    }) {
                                        HStack(spacing: 12) {
                                            ZStack {
                                                Circle()
                                                    .fill(Color(hex: "#4ECDC4").opacity(0.15))
                                                    .frame(width: 38, height: 38)
                                                Text(emp.email.prefix(1).uppercased())
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundColor(Color(hex: "#4ECDC4"))
                                            }
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(emp.email)
                                                    .font(.system(size: 13, weight: .medium))
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)
                                                Text(emp.role.displayName)
                                                    .font(.system(size: 11))
                                                    .foregroundColor(.white.opacity(0.4))
                                            }
                                            Spacer()
                                            Image(systemName: "plus.circle.fill")
                                                .foregroundColor(Color(hex: "#4ECDC4"))
                                                .font(.system(size: 22))
                                        }
                                        .padding(.vertical, 10)
                                    }
                                    .buttonStyle(.plain)

                                    if emp.id != available.last?.id {
                                        Divider().background(Color.white.opacity(0.08))
                                    }
                                }
                            }
                        }
                    }

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 24)
            }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 24)
                    .padding(.top, 56)
                }
                Spacer()
            }
        }
    }
}
