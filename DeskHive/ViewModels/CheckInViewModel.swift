//
//  CheckInViewModel.swift
//  DeskHive
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Mood Model
enum CheckInMood: String, CaseIterable, Codable {
    case great    = "great"
    case good     = "good"
    case okay     = "okay"
    case low      = "low"
    case stressed = "stressed"

    var emoji: String {
        switch self {
        case .great:    return "😄"
        case .good:     return "🙂"
        case .okay:     return "😐"
        case .low:      return "😔"
        case .stressed: return "😤"
        }
    }

    var label: String {
        switch self {
        case .great:    return "Great"
        case .good:     return "Good"
        case .okay:     return "Okay"
        case .low:      return "Low"
        case .stressed: return "Stressed"
        }
    }

    var color: String {
        switch self {
        case .great:    return "#4ECDC4"
        case .good:     return "#95E1D3"
        case .okay:     return "#F5A623"
        case .low:      return "#E94560"
        case .stressed: return "#A78BFA"
        }
    }
}

// MARK: - CheckIn Model
struct DailyCheckIn: Identifiable {
    var id: String
    var uid: String          // anonymised — stored but not shown to admin
    var mood: CheckInMood
    var note: String
    var date: Date
    var dateKey: String      // "yyyy-MM-dd" for easy querying

    init?(id: String, data: [String: Any]) {
        guard
            let uid      = data["uid"]      as? String,
            let moodRaw  = data["mood"]     as? String,
            let mood     = CheckInMood(rawValue: moodRaw),
            let dateKey  = data["dateKey"]  as? String
        else { return nil }

        self.id      = id
        self.uid     = uid
        self.mood    = mood
        self.note    = data["note"] as? String ?? ""
        self.dateKey = dateKey

        if let ts = data["createdAt"] as? Timestamp {
            self.date = ts.dateValue()
        } else {
            self.date = Date()
        }
    }
}

// MARK: - ViewModel
@MainActor
class CheckInViewModel: ObservableObject {
    @Published var hasCheckedInToday: Bool = false
    @Published var todayMood: CheckInMood? = nil
    @Published var isLoading: Bool = false
    @Published var isSubmitting: Bool = false
    @Published var errorMessage: String? = nil
    @Published var successMessage: String? = nil
    @Published var recentCheckIns: [DailyCheckIn] = []

    private let db = Firestore.firestore()

    // MARK: - Today's date key
    private var todayKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    // MARK: - Check if already checked in today
    func loadTodayStatus(uid: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let snapshot = try await db.collection("checkIns")
                .whereField("uid", isEqualTo: uid)
                .whereField("dateKey", isEqualTo: todayKey)
                .limit(to: 1)
                .getDocuments()

            if let doc = snapshot.documents.first,
               let checkIn = DailyCheckIn(id: doc.documentID, data: doc.data()) {
                hasCheckedInToday = true
                todayMood = checkIn.mood
            } else {
                hasCheckedInToday = false
                todayMood = nil
            }
        } catch {
            errorMessage = "Could not load check-in status."
        }
    }

    // MARK: - Submit check-in
    func submitCheckIn(uid: String, mood: CheckInMood, note: String) async {
        isSubmitting = true
        errorMessage = nil
        successMessage = nil

        let data: [String: Any] = [
            "uid":       uid,
            "mood":      mood.rawValue,
            "note":      note,
            "dateKey":   todayKey,
            "createdAt": Timestamp(date: Date())
        ]

        do {
            try await db.collection("checkIns").addDocument(data: data)
            hasCheckedInToday = true
            todayMood = mood
            successMessage = "Check-in submitted! Have a great day 🎉"
        } catch {
            errorMessage = "Failed to submit check-in. Please try again."
        }

        isSubmitting = false
    }

    // MARK: - Load recent 7 check-ins for this employee
    func loadRecentCheckIns(uid: String) async {
        do {
            let snapshot = try await db.collection("checkIns")
                .whereField("uid", isEqualTo: uid)
                .order(by: "createdAt", descending: true)
                .limit(to: 7)
                .getDocuments()

            recentCheckIns = snapshot.documents.compactMap {
                DailyCheckIn(id: $0.documentID, data: $0.data())
            }
        } catch {
            // silently fail — non-critical
        }
    }
}
