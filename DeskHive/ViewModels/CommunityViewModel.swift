//
//  CommunityViewModel.swift
//  DeskHive
//
//  Manages microcommunities — each community has a name, description,
//  a project tag, and a list of member UIDs / emails.
//

import Foundation
import FirebaseFirestore

// MARK: - Model

struct Microcommunity: Identifiable {
    var id: String
    var name: String
    var description: String
    var project: String
    var memberIDs: [String]
    var memberEmails: [String]
    var projectLeadID: String       // "" means no lead assigned
    var projectLeadEmail: String
    var createdAt: Date

    init?(id: String, data: [String: Any]) {
        guard
            let name    = data["name"]        as? String,
            let desc    = data["description"] as? String,
            let project = data["project"]     as? String
        else { return nil }

        self.id               = id
        self.name             = name
        self.description      = desc
        self.project          = project
        self.memberIDs        = data["memberIDs"]        as? [String] ?? []
        self.memberEmails     = data["memberEmails"]     as? [String] ?? []
        self.projectLeadID    = data["projectLeadID"]    as? String  ?? ""
        self.projectLeadEmail = data["projectLeadEmail"] as? String  ?? ""

        if let ts = data["createdAt"] as? Timestamp {
            self.createdAt = ts.dateValue()
        } else {
            self.createdAt = Date()
        }
    }

    var firestoreData: [String: Any] {
        [
            "name":             name,
            "description":      description,
            "project":          project,
            "memberIDs":        memberIDs,
            "memberEmails":     memberEmails,
            "projectLeadID":    projectLeadID,
            "projectLeadEmail": projectLeadEmail,
            "createdAt":        Timestamp(date: createdAt)
        ]
    }
}

// MARK: - ViewModel

@MainActor
class CommunityViewModel: ObservableObject {

    @Published var communities: [Microcommunity] = []
    @Published var isLoading: Bool = false
    @Published var isSaving: Bool = false
    @Published var errorMessage: String? = nil
    @Published var successMessage: String? = nil

    private let db = Firestore.firestore()

    // MARK: - Fetch all communities
    func fetchCommunities() async {
        isLoading = true
        errorMessage = nil

        do {
            let snapshot = try await db.collection("communities")
                .order(by: "createdAt", descending: true)
                .getDocuments()

            communities = snapshot.documents.compactMap {
                Microcommunity(id: $0.documentID, data: $0.data())
            }
            isLoading = false
        } catch {
            isLoading = false
            // Fallback: fetch without ordering (no index needed)
            do {
                let snapshot = try await db.collection("communities").getDocuments()
                communities = snapshot.documents
                    .compactMap { Microcommunity(id: $0.documentID, data: $0.data()) }
                    .sorted { $0.createdAt > $1.createdAt }
                isLoading = false
            } catch let e {
                isLoading = false
                errorMessage = "Failed to load communities: \(e.localizedDescription)"
            }
        }
    }

    // MARK: - Create a new community
    func createCommunity(name: String,
                         description: String,
                         project: String,
                         selectedMembers: [DeskHiveUser],
                         projectLead: DeskHiveUser? = nil) async {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Community name cannot be empty."
            return
        }

        isSaving = true
        errorMessage = nil
        successMessage = nil

        let ref = db.collection("communities").document()
        let community = Microcommunity(id: ref.documentID, data: [
            "name":             name.trimmingCharacters(in: .whitespaces),
            "description":      description.trimmingCharacters(in: .whitespaces),
            "project":          project.trimmingCharacters(in: .whitespaces),
            "memberIDs":        selectedMembers.map { $0.id },
            "memberEmails":     selectedMembers.map { $0.email },
            "projectLeadID":    projectLead?.id    ?? "",
            "projectLeadEmail": projectLead?.email ?? "",
            "createdAt":        Timestamp(date: Date())
        ])

        guard let community else {
            isSaving = false
            errorMessage = "Failed to build community data."
            return
        }

        do {
            try await ref.setData(community.firestoreData)
            communities.insert(community, at: 0)
            successMessage = "Community \"\(community.name)\" created!"
            isSaving = false
        } catch {
            isSaving = false
            errorMessage = "Failed to create community: \(error.localizedDescription)"
        }
    }

    // MARK: - Set project lead for a community
    func setProjectLead(_ user: DeskHiveUser, in community: Microcommunity) async {
        errorMessage = nil
        do {
            try await db.collection("communities").document(community.id).updateData([
                "projectLeadID":    user.id,
                "projectLeadEmail": user.email
            ])
            if let idx = communities.firstIndex(where: { $0.id == community.id }) {
                communities[idx].projectLeadID    = user.id
                communities[idx].projectLeadEmail = user.email
            }
            // Promote the user's role and notify them
            await promoteToProjectLead(user: user, community: community)
        } catch {
            errorMessage = "Failed to set lead: \(error.localizedDescription)"
        }
    }

    // MARK: - Promote employee to projectLead role + send credentials notification
    private func promoteToProjectLead(user: DeskHiveUser, community: Microcommunity) async {
        // 1. Generate a readable temporary password
        let tempPassword = generateTempPassword()

        // 2. Upgrade role in Firestore users collection
        do {
            try await db.collection("users").document(user.id).updateData([
                "role": UserRole.projectLead.rawValue
            ])
        } catch {
            errorMessage = "Promoted to lead but failed to update role: \(error.localizedDescription)"
            return
        }

        // 3. Store temp password on the community doc so admin can retrieve it
        do {
            try await db.collection("communities").document(community.id).updateData([
                "projectLeadTempPassword": tempPassword
            ])
        } catch { /* non-critical */ }

        // 4. Post a personal announcement to the employee's inbox with credentials
        let announcementRef = db.collection("announcements").document()
        let announcementData: [String: Any] = [
            "title":      "🎉 You've been promoted to Project Lead!",
            "body":       "Congratulations! You are now the Project Lead for \"\(community.name)\" (\(community.project.isEmpty ? "No project tag" : community.project)).\n\n🔑 Your Project Lead Login Credentials:\n• Email: \(user.email)\n• Temporary Password: \(tempPassword)\n\nPlease log out and log back in using these credentials. Change your password after first login.",
            "priority":   "urgent",
            "targetUID":  user.id,
            "type":       "promotion",
            "createdAt":  Timestamp(date: Date())
        ]
        do {
            try await announcementRef.setData(announcementData)
        } catch {
            errorMessage = "Promoted but failed to send notification: \(error.localizedDescription)"
        }

        successMessage = "\(user.email) promoted to Project Lead. Credentials sent to their inbox."
    }

    // MARK: - Remove project lead
    func removeProjectLead(from community: Microcommunity) async {
        errorMessage = nil

        // Downgrade role back to employee in Firestore
        if !community.projectLeadID.isEmpty {
            do {
                try await db.collection("users").document(community.projectLeadID).updateData([
                    "role": UserRole.employee.rawValue
                ])
            } catch { /* non-critical */ }
        }

        do {
            try await db.collection("communities").document(community.id).updateData([
                "projectLeadID":           "",
                "projectLeadEmail":        "",
                "projectLeadTempPassword": ""
            ])
            if let idx = communities.firstIndex(where: { $0.id == community.id }) {
                communities[idx].projectLeadID    = ""
                communities[idx].projectLeadEmail = ""
            }
        } catch {
            errorMessage = "Failed to remove lead: \(error.localizedDescription)"
        }
    }

    // MARK: - Generate readable temp password e.g. "Lead@X7k2"
    private func generateTempPassword() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789"
        let suffix = String((0..<6).map { _ in chars.randomElement()! })
        return "Lead@\(suffix)"
    }

    // MARK: - Delete a community
    func deleteCommunity(_ community: Microcommunity) async {
        errorMessage = nil
        do {
            try await db.collection("communities").document(community.id).delete()
            communities.removeAll { $0.id == community.id }
        } catch {
            errorMessage = "Failed to delete: \(error.localizedDescription)"
        }
    }

    // MARK: - Add a member to an existing community
    func addMember(_ user: DeskHiveUser, to community: Microcommunity) async {
        guard !community.memberIDs.contains(user.id) else { return }
        errorMessage = nil

        var updatedIDs    = community.memberIDs    + [user.id]
        var updatedEmails = community.memberEmails + [user.email]

        do {
            try await db.collection("communities").document(community.id).updateData([
                "memberIDs":    updatedIDs,
                "memberEmails": updatedEmails
            ])
            if let idx = communities.firstIndex(where: { $0.id == community.id }) {
                communities[idx].memberIDs    = updatedIDs
                communities[idx].memberEmails = updatedEmails
            }
        } catch {
            errorMessage = "Failed to add member: \(error.localizedDescription)"
        }
    }

    // MARK: - Remove a member from a community
    func removeMember(_ userID: String, from community: Microcommunity) async {
        errorMessage = nil

        let updatedIDs    = community.memberIDs.filter    { $0 != userID }
        let updatedEmails = zip(community.memberIDs, community.memberEmails)
                               .filter { $0.0 != userID }.map { $0.1 }

        do {
            try await db.collection("communities").document(community.id).updateData([
                "memberIDs":    updatedIDs,
                "memberEmails": updatedEmails
            ])
            if let idx = communities.firstIndex(where: { $0.id == community.id }) {
                communities[idx].memberIDs    = updatedIDs
                communities[idx].memberEmails = updatedEmails
            }
        } catch {
            errorMessage = "Failed to remove member: \(error.localizedDescription)"
        }
    }
}
