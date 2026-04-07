//
//  UserModel.swift
//  DeskHive
//

import Foundation
import FirebaseFirestore

enum UserRole: String, Codable {
    case admin = "admin"
    case employee = "employee"
    case projectLead = "projectLead"

    var displayName: String {
        switch self {
        case .admin:       return "Admin"
        case .employee:    return "Employee"
        case .projectLead: return "Project Lead"
        }
    }
}

struct DeskHiveUser: Identifiable, Codable {
    var id: String           // Firebase UID
    var email: String
    var role: UserRole
    var createdAt: Date

    init(id: String, email: String, role: UserRole, createdAt: Date = Date()) {
        self.id = id
        self.email = email
        self.role = role
        self.createdAt = createdAt
    }

    init?(id: String, data: [String: Any]) {
        // Firestore decoding is intentionally strict to avoid routing users with malformed roles.
        guard
            let email = data["email"] as? String,
            let roleRaw = data["role"] as? String,
            let role = UserRole(rawValue: roleRaw)
        else { return nil }

        self.id = id
        self.email = email
        self.role = role

        if let ts = data["createdAt"] as? Timestamp {
            self.createdAt = ts.dateValue()
        } else {
            // Fall back for older/migrated docs that predate createdAt.
            self.createdAt = Date()
        }
    }

    var firestoreData: [String: Any] {
        // Keep Firestore keys centralized to avoid drift between auth flows.
        [
            "email": email,
            "role": role.rawValue,
            "createdAt": Timestamp(date: createdAt)
        ]
    }
}
