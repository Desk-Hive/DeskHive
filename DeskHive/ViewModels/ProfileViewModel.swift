//
//  ProfileViewModel.swift
//  DeskHive
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

// MARK: - Salary Statement Model
struct SalaryStatement: Identifiable {
    var id: String
    var month: String       // "March 2025"
    var amount: Double
    var status: String      // "Paid" / "Pending"
    var paidOn: Date?

    init?(id: String, data: [String: Any]) {
        guard
            let month  = data["month"]  as? String,
            let amount = data["amount"] as? Double,
            let status = data["status"] as? String
        else { return nil }
        self.id     = id
        self.month  = month
        self.amount = amount
        self.status = status
        if let ts = data["paidOn"] as? Timestamp {
            self.paidOn = ts.dateValue()
        }
    }
}

@MainActor
class ProfileViewModel: ObservableObject {

    @Published var isLoading       = false
    @Published var isSaving        = false
    @Published var successMessage: String? = nil
    @Published var errorMessage:   String? = nil

    // Editable fields
    @Published var fullName        = ""
    @Published var phone           = ""
    @Published var department      = ""
    @Published var jobTitle        = ""
    @Published var bio             = ""

    // Salary
    @Published var salary: Double  = 0
    @Published var statements: [SalaryStatement] = []

    // Password change
    @Published var currentPassword = ""
    @Published var newPassword     = ""
    @Published var confirmPassword = ""
    @Published var isChangingPw    = false

    private let db = Firestore.firestore()

    // MARK: - Load profile from Firestore
    func load(user: DeskHiveUser) {
        fullName   = user.fullName
        phone      = user.phone
        department = user.department
        jobTitle   = user.jobTitle
        bio        = user.bio
        salary     = user.salary
        Task { await fetchStatements(uid: user.id) }
    }

    // MARK: - Save profile
    func saveProfile(uid: String, appState: AppState) async {
        isSaving = true
        errorMessage = nil
        successMessage = nil
        let updates: [String: Any] = [
            "fullName":   fullName.trimmingCharacters(in: .whitespaces),
            "phone":      phone.trimmingCharacters(in: .whitespaces),
            "department": department.trimmingCharacters(in: .whitespaces),
            "jobTitle":   jobTitle.trimmingCharacters(in: .whitespaces),
            "bio":        bio.trimmingCharacters(in: .whitespaces)
        ]
        do {
            try await db.collection("users").document(uid).updateData(updates)
            // Refresh appState user
            let doc = try await db.collection("users").document(uid).getDocument()
            if let data = doc.data(), let updated = DeskHiveUser(id: uid, data: data) {
                appState.currentUser = updated
            }
            successMessage = "Profile updated successfully ✓"
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
        isSaving = false
    }

    // MARK: - Change password
    func changePassword() async {
        guard !newPassword.isEmpty else {
            errorMessage = "New password cannot be empty."
            return
        }
        guard newPassword == confirmPassword else {
            errorMessage = "Passwords do not match."
            return
        }
        guard newPassword.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            return
        }
        isChangingPw = true
        errorMessage = nil
        successMessage = nil

        guard let user = Auth.auth().currentUser, let email = user.email else {
            errorMessage = "Not signed in."
            isChangingPw = false
            return
        }

        do {
            // Re-authenticate first
            let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)
            try await user.reauthenticate(with: credential)
            try await user.updatePassword(to: newPassword)
            successMessage = "Password changed successfully ✓"
            currentPassword = ""
            newPassword = ""
            confirmPassword = ""
        } catch let err as NSError {
            if err.code == AuthErrorCode.wrongPassword.rawValue {
                errorMessage = "Current password is incorrect."
            } else {
                errorMessage = err.localizedDescription
            }
        }
        isChangingPw = false
    }

    // MARK: - Fetch salary statements
    func fetchStatements(uid: String) async {
        do {
            let snap = try await db.collection("users").document(uid)
                .collection("salaryStatements")
                .order(by: "createdAt", descending: true)
                .getDocuments()
            statements = snap.documents.compactMap {
                SalaryStatement(id: $0.documentID, data: $0.data())
            }
        } catch {
            // Statements may not exist yet — silently ignore
        }
    }
}
