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

    // Extended profile fields
    var fullName: String
    var phone: String
    var department: String
    var jobTitle: String
    var profileImageURL: String
    var salary: Double          // monthly salary in BDT/USD set by admin
    var bio: String

    init(id: String, email: String, role: UserRole, createdAt: Date = Date(),
         fullName: String = "", phone: String = "", department: String = "",
         jobTitle: String = "", profileImageURL: String = "",
         salary: Double = 0, bio: String = "") {
        self.id = id
        self.email = email
        self.role = role
        self.createdAt = createdAt
        self.fullName = fullName
        self.phone = phone
        self.department = department
        self.jobTitle = jobTitle
        self.profileImageURL = profileImageURL
        self.salary = salary
        self.bio = bio
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

        self.fullName         = data["fullName"]         as? String ?? ""
        self.phone            = data["phone"]            as? String ?? ""
        self.department       = data["department"]       as? String ?? ""
        self.jobTitle         = data["jobTitle"]         as? String ?? ""
        self.profileImageURL  = data["profileImageURL"]  as? String ?? ""
        self.salary           = data["salary"]           as? Double ?? 0
        self.bio              = data["bio"]              as? String ?? ""
    }

    var firestoreData: [String: Any] {
        // Keep Firestore keys centralized to avoid drift between auth flows.
        [
            "email":           email,
            "role":            role.rawValue,
            "createdAt":       Timestamp(date: createdAt),
            "fullName":        fullName,
            "phone":           phone,
            "department":      department,
            "jobTitle":        jobTitle,
            "profileImageURL": profileImageURL,
            "salary":          salary,
            "bio":             bio
        ]
    }
}
