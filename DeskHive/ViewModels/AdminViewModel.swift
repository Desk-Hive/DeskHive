//
//  AdminViewModel.swift
//  DeskHive
//
//  Central view-model for all admin-facing operations.
//  Handles member management (fetch, add, role toggle), issue report
//  retrieval, and admin responses. All Firestore writes and Cloud Function
//  calls are performed here so that the admin views stay free of business logic.
//
//  Marked @MainActor so that @Published property mutations always happen
//  on the main thread, keeping the UI update-safe without manual DispatchQueue calls.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions

@MainActor
class AdminViewModel: ObservableObject {

    // MARK: - Member state
    @Published var members: [DeskHiveUser] = []       // All non-admin users, sorted newest first
    @Published var isLoading: Bool = false             // True while fetchMembers() is in flight
    @Published var isAddingMember: Bool = false        // True while the Cloud Function call is running
    @Published var errorMessage: String? = nil         // Last member-related error surfaced to the UI
    @Published var successMessage: String? = nil       // Confirmation shown after a successful action

    // MARK: - Issue state
    @Published var issues: [IssueReport] = []          // All issue reports, sorted newest first
    @Published var isLoadingIssues: Bool = false        // True while fetchIssues() is in flight
    @Published var issuesError: String? = nil           // Last issue-related error surfaced to the UI
    @Published var isRespondingToIssue: Bool = false    // True while respondToIssue() is in flight

    // Firestore database reference shared across all operations in this VM
    private let db = Firestore.firestore()
    // Cloud Functions client — lazy so it initialises only when first used
    private lazy var functions = Functions.functions()

    // MARK: - Fetch all non-admin users
    /// Loads every registered user from Firestore, strips out admin accounts,
    /// and sorts the result by creation date (newest first).
    func fetchMembers() async {
        isLoading = true
        errorMessage = nil

        do {
            let snapshot = try await db.collection("users").getDocuments()

            members = snapshot.documents
                .compactMap { doc in DeskHiveUser(id: doc.documentID, data: doc.data()) }
                .filter { $0.role != .admin }        // Admins are excluded from the member list
                .sorted { $0.createdAt > $1.createdAt }

            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Failed to load employees: \(error.localizedDescription)"
        }
    }

    // MARK: - Add member via Cloud Function (secure)
    /// Creates a new employee account by calling the `createMember` Cloud Function.
    /// The function generates a secure random password, creates the Firebase Auth user,
    /// writes the Firestore profile, and emails the credentials — all server-side.
    /// The client never sees or stores the generated password.
    func addMember(email: String) async {
        // Guard against empty or malformed input before making any network call
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
                // Refresh the member list so the new account appears immediately
                await fetchMembers()
            } else {
                errorMessage = "Failed to create member. Please try again."
            }
            isAddingMember = false
        } catch let error as NSError {
            isAddingMember = false
            // Cloud Functions errors carry a user-facing message in FunctionsErrorDetailsKey
            if let details = error.userInfo[FunctionsErrorDetailsKey] as? String {
                errorMessage = details
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Toggle role between member <-> projectLead
    /// Flips a user's role between `employee` and `projectLead` in Firestore
    /// and updates the local `members` array in place to avoid a full re-fetch.
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
    /// Returns `true` when `email` matches a standard RFC-compliant email pattern.
    /// Used as a lightweight client-side guard before invoking the Cloud Function.
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let pred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return pred.evaluate(with: email)
    }

    // MARK: - Fetch all submitted issues (admin only)
    /// Loads all issue reports from Firestore ordered newest-first.
    /// Only the admin role has Firestore security-rule access to the `issues` collection.
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
    /// Writes the admin's response text and the chosen status back to Firestore.
    /// After a successful write, the local `issues` array is patched in place
    /// so the UI reflects the change instantly without a full re-fetch.
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
