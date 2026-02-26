//
//  EmployeeOfMonth.swift
//  DeskHive
//

import Foundation
import FirebaseFirestore

struct EmployeeOfMonth: Identifiable {
    var id: String          // Firestore doc ID (e.g. "2026-02")
    var employeeID: String
    var employeeEmail: String
    var reason: String
    var month: String       // "February 2026"
    var awardedAt: Date
    var awardedByEmail: String

    // Derived: initials for avatar
    var initials: String {
        let name = employeeEmail.components(separatedBy: "@").first ?? "?"
        let parts = name.components(separatedBy: ".")
        if parts.count >= 2 {
            return (parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return name.prefix(2).uppercased()
    }

    // Derived: first name for display
    var displayName: String {
        let name = employeeEmail.components(separatedBy: "@").first ?? employeeEmail
        return name.replacingOccurrences(of: ".", with: " ").capitalized
    }

    init(id: String, employeeID: String, employeeEmail: String,
         reason: String, month: String, awardedAt: Date, awardedByEmail: String) {
        self.id             = id
        self.employeeID     = employeeID
        self.employeeEmail  = employeeEmail
        self.reason         = reason
        self.month          = month
        self.awardedAt      = awardedAt
        self.awardedByEmail = awardedByEmail
    }

    init?(id: String, data: [String: Any]) {
        guard
            let employeeID    = data["employeeID"]    as? String,
            let employeeEmail = data["employeeEmail"] as? String,
            let reason        = data["reason"]        as? String,
            let month         = data["month"]         as? String,
            let awardedByEmail = data["awardedByEmail"] as? String
        else { return nil }

        self.id             = id
        self.employeeID     = employeeID
        self.employeeEmail  = employeeEmail
        self.reason         = reason
        self.month          = month
        self.awardedByEmail = awardedByEmail

        if let ts = data["awardedAt"] as? Timestamp {
            self.awardedAt = ts.dateValue()
        } else {
            self.awardedAt = Date()
        }
    }

    var firestoreData: [String: Any] {
        [
            "employeeID":     employeeID,
            "employeeEmail":  employeeEmail,
            "reason":         reason,
            "month":          month,
            "awardedAt":      Timestamp(date: awardedAt),
            "awardedByEmail": awardedByEmail
        ]
    }

    /// Document ID format: "YYYY-MM"
    static func docID(for date: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f.string(from: date)
    }

    /// Display month string: "February 2026"
    static func monthString(for date: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }
}
