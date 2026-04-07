//
//  IssueReportViewModel.swift
//  DeskHive
//

import Foundation
import FirebaseFirestore

// MARK: - Issue Category
enum IssueCategory: String, CaseIterable, Codable {
    case workplace   = "workplace"
    case technical   = "technical"
    case harassment  = "harassment"
    case safety      = "safety"
    case other       = "other"

    var label: String {
        switch self {
        case .workplace:  return "Workplace"
        case .technical:  return "Technical"
        case .harassment: return "Harassment"
        case .safety:     return "Safety"
        case .other:      return "Other"
        }
    }

    var icon: String {
        switch self {
        case .workplace:  return "building.2"
        case .technical:  return "wrench.and.screwdriver"
        case .harassment: return "exclamationmark.shield"
        case .safety:     return "cross.circle"
        case .other:      return "ellipsis.circle"
        }
    }

    var color: String {
        switch self {
        case .workplace:  return "#4ECDC4"
        case .technical:  return "#F5A623"
        case .harassment: return "#E94560"
        case .safety:     return "#A78BFA"
        case .other:      return "#95E1D3"
        }
    }
}

// MARK: - Issue Status
enum IssueStatus: String, Codable {
    case open       = "open"
    case inReview   = "inReview"
    case resolved   = "resolved"

    var label: String {
        switch self {
        case .open:     return "Open"
        case .inReview: return "In Review"
        case .resolved: return "Resolved"
        }
    }

    var icon: String {
        switch self {
        case .open:     return "circle"
        case .inReview: return "clock.fill"
        case .resolved: return "checkmark.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .open:     return "#F5A623"
        case .inReview: return "#4ECDC4"
        case .resolved: return "#95E1D3"
        }
    }
}

// MARK: - Issue Model
struct IssueReport: Identifiable {
    var id: String          // document ID = Case ID
    var category: IssueCategory
    var title: String
    var description: String
    var status: IssueStatus
    var adminResponse: String
    var createdAt: Date

    init?(id: String, data: [String: Any]) {
        guard
            let catRaw  = data["category"]    as? String,
            let cat     = IssueCategory(rawValue: catRaw),
            let title   = data["title"]       as? String,
            let desc    = data["description"] as? String,
            let statRaw = data["status"]      as? String,
            let status  = IssueStatus(rawValue: statRaw)
        else { return nil }

        self.id            = id
        self.category      = cat
        self.title         = title
        self.description   = desc
        self.status        = status
        self.adminResponse = data["adminResponse"] as? String ?? ""

        if let ts = data["createdAt"] as? Timestamp {
            self.createdAt = ts.dateValue()
        } else {
            self.createdAt = Date()
        }
    }
}

// MARK: - ViewModel
@MainActor
class IssueReportViewModel: ObservableObject {

    // Submit flow
    @Published var isSubmitting: Bool = false
    @Published var submitError: String? = nil
    @Published var submittedCaseID: String? = nil   // shown after success

    // Lookup flow
    @Published var isLooking: Bool = false
    @Published var lookupError: String? = nil
    @Published var lookedUpIssue: IssueReport? = nil

    private let db = Firestore.firestore()

    // MARK: - Submit anonymous issue
    func submitIssue(category: IssueCategory, title: String, description: String) async {
        guard !title.isEmpty, !description.isEmpty else {
            submitError = "Please fill in the title and description."
            return
        }

        isSubmitting = true
        submitError  = nil
        submittedCaseID = nil

        let caseID = generateCaseID()
        let data: [String: Any] = [
            "caseID":       caseID,
            "category":     category.rawValue,
            "title":        title,
            "description":  description,
            "status":       IssueStatus.open.rawValue,
            "adminResponse": "",
            "createdAt":    Timestamp(date: Date())
            // No UID stored — fully anonymous
        ]

        do {
            // Use caseID as document ID so lookup is O(1)
            try await db.collection("issues").document(caseID).setData(data)
            submittedCaseID = caseID
        } catch {
            submitError = "Failed to submit. Please try again."
        }

        isSubmitting = false
    }

    // MARK: - Lookup issue by Case ID
    func lookupIssue(caseID: String) async {
        let trimmed = caseID.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else {
            lookupError = "Please enter a Case ID."
            return
        }

        isLooking    = true
        lookupError  = nil
        lookedUpIssue = nil

        do {
            let doc = try await db.collection("issues").document(trimmed).getDocument()
            if doc.exists, let data = doc.data(),
               let issue = IssueReport(id: doc.documentID, data: data) {
                lookedUpIssue = issue
            } else {
                lookupError = "No issue found with Case ID \"\(trimmed)\". Please check and try again."
            }
        } catch {
            lookupError = "Lookup failed. Please check your connection."
        }

        isLooking = false
    }

    // MARK: - Generate readable Case ID  e.g. "ISS-A3F9"
    private func generateCaseID() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        let suffix = String((0..<6).map { _ in chars.randomElement()! })
        return "ISS-\(suffix)"
    }
}
