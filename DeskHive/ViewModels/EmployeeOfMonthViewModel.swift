//
//  EmployeeOfMonthViewModel.swift
//  DeskHive
//

import Foundation
import FirebaseFirestore

// Owns all Employee of the Month data flow.
// It listens to the current month's document in real time, loads recent history,
// and handles the admin write/delete actions that update Firestore.
@MainActor
final class EmployeeOfMonthViewModel: ObservableObject {

    // UI-facing state shared by the admin picker sheet and dashboard spotlight cards.
    @Published var current: EmployeeOfMonth? = nil
    @Published var history: [EmployeeOfMonth] = []
    @Published var isLoading   = false
    @Published var isSaving    = false
    @Published var errorMessage: String? = nil
    @Published var successMessage: String? = nil

    // Firestore connection details for the single `employeeOfMonth` collection.
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    // Subscribes to the document for the current month only.
    // Because the document ID is based on `yyyy-MM`, any save for this month
    // updates the same record and all listening dashboards refresh automatically.
    // MARK: - Real-time listener for the current month's award
    func startListening() {
        let docID = EmployeeOfMonth.docID()
        listener = db.collection("employeeOfMonth")
            .document(docID)
            .addSnapshotListener { [weak self] snap, error in
                guard let self else { return }
                if let data = snap?.data(), !data.isEmpty {
                    self.current = EmployeeOfMonth(id: docID, data: data)
                } else {
                    self.current = nil
                }
            }
    }

    // Called when the hosting screen disappears so the snapshot listener is cleaned up.
    func stopListening() {
        listener?.remove()
        listener = nil
    }

    // Loads a short newest-first history list for admin review screens.
    // MARK: - Fetch history (last 6 months)
    func fetchHistory() async {
        isLoading = true
        do {
            let snap = try await db.collection("employeeOfMonth")
                .order(by: "awardedAt", descending: true)
                .limit(to: 6)
                .getDocuments()
            history = snap.documents.compactMap { EmployeeOfMonth(id: $0.documentID, data: $0.data()) }
        } catch {
            errorMessage = "Failed to load history."
        }
        isLoading = false
    }

    // Writes or replaces the current month's winner document.
    // The rest of the app reads the same monthly document, so one successful save
    // is enough to update admin, employee, and project-lead dashboards.
    // MARK: - Admin: save award
    func saveAward(employee: DeskHiveUser, reason: String, adminEmail: String) async {
        guard !reason.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please add a reason for the award."
            return
        }

        isSaving = true
        errorMessage = nil
        successMessage = nil

        let docID  = EmployeeOfMonth.docID()
        let month  = EmployeeOfMonth.monthString()
        let award  = EmployeeOfMonth(
            id:             docID,
            employeeID:     employee.id,
            employeeEmail:  employee.email,
            reason:         reason,
            month:          month,
            awardedAt:      Date(),
            awardedByEmail: adminEmail
        )

        do {
            try await db.collection("employeeOfMonth")
                .document(docID)
                .setData(award.firestoreData)
            current = award
            successMessage = "\(employee.email) has been named Employee of the Month! 🎉"
        } catch {
            errorMessage = "Failed to save award: \(error.localizedDescription)"
        }
        isSaving = false
    }

    // Removes only this month's winner document and clears the local current state.
    // MARK: - Admin: clear current award
    func clearAward() async {
        let docID = EmployeeOfMonth.docID()
        try? await db.collection("employeeOfMonth").document(docID).delete()
        current = nil
        successMessage = "Award cleared for this month."
    }
}
