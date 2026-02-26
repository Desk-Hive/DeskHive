//
//  EmployeeOfMonthViewModel.swift
//  DeskHive
//

import Foundation
import FirebaseFirestore

@MainActor
final class EmployeeOfMonthViewModel: ObservableObject {

    @Published var current: EmployeeOfMonth? = nil
    @Published var history: [EmployeeOfMonth] = []
    @Published var isLoading   = false
    @Published var isSaving    = false
    @Published var errorMessage: String? = nil
    @Published var successMessage: String? = nil

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

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

    func stopListening() {
        listener?.remove()
        listener = nil
    }

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

    // MARK: - Admin: clear current award
    func clearAward() async {
        let docID = EmployeeOfMonth.docID()
        try? await db.collection("employeeOfMonth").document(docID).delete()
        current = nil
        successMessage = "Award cleared for this month."
    }
}
