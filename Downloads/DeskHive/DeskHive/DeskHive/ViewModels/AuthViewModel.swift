//
//  AuthViewModel.swift
//  DeskHive
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var successMessage: String? = nil

    private let db = Firestore.firestore()

    // MARK: - Login
    func login(email: String, password: String, appState: AppState) async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter your email and password."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            let uid = result.user.uid

            let doc = try await db.collection("users").document(uid).getDocument()
            guard let data = doc.data(), let user = DeskHiveUser(id: uid, data: data) else {
                errorMessage = "Account data not found. Please contact your admin."
                isLoading = false
                return
            }

            isLoading = false
            appState.navigateAfterLogin(user: user)
        } catch let error as NSError {
            isLoading = false
            errorMessage = mapAuthError(error)
        }
    }

    // MARK: - Admin Sign-Up (only once)
    func adminSignUp(email: String, password: String, confirmPassword: String, appState: AppState) async {
        errorMessage = nil
        successMessage = nil

        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in all fields."
            return
        }
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match."
            return
        }
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            return
        }

        isLoading = true

        do {
            // Check if an admin already exists
            let snapshot = try await db.collection("users")
                .whereField("role", isEqualTo: "admin")
                .limit(to: 1)
                .getDocuments()

            if !snapshot.documents.isEmpty {
                isLoading = false
                errorMessage = "An admin account already exists. Please log in instead."
                return
            }

            // Create Firebase Auth user
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let uid = result.user.uid

            // Create Firestore document
            let user = DeskHiveUser(id: uid, email: email, role: .admin)
            try await db.collection("users").document(uid).setData(user.firestoreData)

            isLoading = false
            appState.navigateAfterLogin(user: user)
        } catch let error as NSError {
            isLoading = false
            errorMessage = mapAuthError(error)
        }
    }

    // MARK: - Sign Out
    func signOut(appState: AppState) {
        do {
            try Auth.auth().signOut()
            appState.signOut()
        } catch {
            errorMessage = "Failed to sign out: \(error.localizedDescription)"
        }
    }

    // MARK: - Restore session on app launch
    func restoreSession(appState: AppState) async {
        guard let currentUser = Auth.auth().currentUser else {
            appState.currentScreen = .login
            return
        }

        do {
            let doc = try await db.collection("users").document(currentUser.uid).getDocument()
            if let data = doc.data(), let user = DeskHiveUser(id: currentUser.uid, data: data) {
                appState.navigateAfterLogin(user: user)
            } else {
                appState.currentScreen = .login
            }
        } catch {
            appState.currentScreen = .login
        }
    }

    // MARK: - Map Firebase errors to user-friendly messages
    private func mapAuthError(_ error: NSError) -> String {
        guard let code = AuthErrorCode(_bridgedNSError: error)?.code else {
            return error.localizedDescription
        }
        switch code {
        case .wrongPassword, .invalidCredential:
            return "Invalid email or password. Please try again."
        case .userNotFound:
            return "No account found with this email address."
        case .emailAlreadyInUse:
            return "This email is already registered."
        case .weakPassword:
            return "Password is too weak. Use at least 6 characters."
        case .invalidEmail:
            return "Please enter a valid email address."
        case .networkError:
            return "Network error. Please check your connection."
        case .tooManyRequests:
            return "Too many attempts. Please try again later."
        default:
            return error.localizedDescription
        }
    }
}
