//
//  AdminViewModel.swift
//  DeskHive
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions

@MainActor
class AdminViewModel: ObservableObject {
    @Published var members: [DeskHiveUser] = []
    @Published var isLoading: Bool = false
    @Published var isAddingMember: Bool = false
    @Published var errorMessage: String? = nil
    @Published var successMessage: String? = nil

    // Issues
    @Published var issues: [IssueReport] = []
    @Published var isLoadingIssues: Bool = false
    @Published var issuesError: String? = nil
    @Published var isRespondingToIssue: Bool = false

    private let db = Firestore.firestore()
    private lazy var functions = Functions.functions()

    // MARK: - Fetch all non-admin users
    func fetchMembers() async {
        isLoading = true
        errorMessage = nil

        do {
            let snapshot = try await db.collection("users").getDocuments()

            members = snapshot.documents
                .compactMap { doc in DeskHiveUser(id: doc.documentID, data: doc.data()) }
                .filter { $0.role != .admin }
                .sorted { $0.createdAt > $1.createdAt }

            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Failed to load employees: \(error.localizedDescription)"
        }
    }

    // MARK: - Add member via Cloud Function (secure)
    func addMember(email: String) async {
        guard !email.isEmpty else {
            errorMessage = "Please enter an email address."
            return
        }
        guard isValidEmail(email) else {
            errorMessage = "Please enter a valid email address."
            return
        }

        isAddingMember = true
        errorMessage = nil
        successMessage = nil

        do {
            let result = try await functions.httpsCallable("createMember").call(["email": email])
            if let data = result.data as? [String: Any],
               let success = data["success"] as? Bool, success {
                successMessage = "Member account created! A welcome email has been sent to \(email)."
                await fetchMembers()
            } else {
                errorMessage = "Failed to create member. Please try again."
            }
            isAddingMember = false
        } catch let error as NSError {
            isAddingMember = false
            if let details = error.userInfo[FunctionsErrorDetailsKey] as? String {
                errorMessage = details
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Toggle role between member <-> projectLead
    func toggleRole(for user: DeskHiveUser) async {
        errorMessage = nil
        successMessage = nil

        let newRole: UserRole = user.role == .employee ? .projectLead : .employee

        do {
            try await db.collection("users").document(user.id).updateData(["role": newRole.rawValue])
            if let index = members.firstIndex(where: { $0.id == user.id }) {
                members[index].role = newRole
            }
            successMessage = "\(user.email) is now a \(newRole.displayName)."
        } catch {
            errorMessage = "Failed to update role: \(error.localizedDescription)"
        }
    }

    // MARK: - Email validation
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let pred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return pred.evaluate(with: email)
    }

    // MARK: - Fetch all submitted issues (admin only)
    func fetchIssues() async {
        isLoadingIssues = true
        issuesError = nil

        do {
            let snapshot = try await db.collection("issues")
                .order(by: "createdAt", descending: true)
                .getDocuments()

            issues = snapshot.documents.compactMap { doc in
                IssueReport(id: doc.documentID, data: doc.data())
            }
            isLoadingIssues = false
        } catch {
            isLoadingIssues = false
            issuesError = "Failed to load issues: \(error.localizedDescription)"
        }
    }

    // MARK: - Respond to an issue and optionally update its status
    func respondToIssue(issueID: String, response: String, newStatus: IssueStatus) async {
        isRespondingToIssue = true
        issuesError = nil

        do {
            try await db.collection("issues").document(issueID).updateData([
                "adminResponse": response,
                "status": newStatus.rawValue
            ])
            // Reflect change locally without re-fetching
            if let idx = issues.firstIndex(where: { $0.id == issueID }) {
                issues[idx].adminResponse = response
                issues[idx].status = newStatus
            }
            isRespondingToIssue = false
        } catch {
            isRespondingToIssue = false
            issuesError = "Failed to send response: \(error.localizedDescription)"
        }
    }
}
