//
//  CheckInViewModel.swift
//  DeskHive
//

import Foundation
import Combine
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

    // Theme accent used for mood-personalized employee UI.
    var themeAccent: String {
        switch self {
        case .great:    return "#34D399"
        case .good:     return "#4ECDC4"
        case .okay:     return "#F5A623"
        case .low:      return "#8AB4F8"
        case .stressed: return "#A78BFA"
        }
    }

    // Mood-based gradient palette for dashboard background.
    var themeGradient: [String] {
        switch self {
        case .great:
            return ["#0C2F28", "#145749", "#1D7A67"]
        case .good:
            return ["#133147", "#1B4D69", "#276B8A"]
        case .okay:
            return ["#2E2519", "#4A351D", "#6B4A1E"]
        case .low:
            return ["#1B2431", "#22364C", "#2A4E6C"]
        case .stressed:
            return ["#251A38", "#3A2860", "#503682"]
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
    @Published var totalCheckIns: Int = 0
    @Published var currentStreak: Int = 0

    private let db = Firestore.firestore()

    // MARK: - Today's date key
    private var todayKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
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
    func submitCheckIn(uid: String, mood: CheckInMood?, note: String) async {
        isSubmitting = true
        errorMessage = nil
        successMessage = nil

        var data: [String: Any] = [
            "uid":       uid,
            "note":      note,
            "dateKey":   todayKey,
            "createdAt": Timestamp(date: Date())
        ]
        if let mood = mood {
            data["mood"] = mood.rawValue
        }

        do {
            try await db.collection("checkIns").addDocument(data: data)
            hasCheckedInToday = true
            todayMood = mood
            successMessage = "Check-in submitted! Have a great day 🎉"
            // Refresh stats after successful submission
            await loadStats(uid: uid)
        } catch {
            errorMessage = "Failed to submit check-in. Please try again."
        }

        isSubmitting = false
    }

    // MARK: - Load recent 7 check-ins for the CheckInView history display
    func loadRecentCheckIns(uid: String) async {
        do {
            // Order by dateKey (yyyy-MM-dd lexicographic sort = chronological)
            let snapshot = try await db.collection("checkIns")
                .whereField("uid", isEqualTo: uid)
                .order(by: "dateKey", descending: true)
                .limit(to: 7)
                .getDocuments()

            recentCheckIns = snapshot.documents.compactMap {
                DailyCheckIn(id: $0.documentID, data: $0.data())
            }
        } catch {
            // Fallback: fetch without ordering and sort client-side
            do {
                let snapshot = try await db.collection("checkIns")
                    .whereField("uid", isEqualTo: uid)
                    .getDocuments()
                recentCheckIns = snapshot.documents
                    .compactMap { DailyCheckIn(id: $0.documentID, data: $0.data()) }
                    .sorted { $0.dateKey > $1.dateKey }
                    .prefix(7)
                    .map { $0 }
            } catch {
                // silently fail — non-critical
            }
        }
    }

    // MARK: - Load all-time stats: total count + streak
    func loadStats(uid: String) async {
        do {
            // Fetch all check-ins for this user (ordered by dateKey descending)
            // Using dateKey ordering avoids composite index requirement
            let snapshot = try await db.collection("checkIns")
                .whereField("uid", isEqualTo: uid)
                .order(by: "dateKey", descending: true)
                .getDocuments()

            let allCheckIns = snapshot.documents.compactMap {
                DailyCheckIn(id: $0.documentID, data: $0.data())
            }

            totalCheckIns = allCheckIns.count

            // Also update recentCheckIns (first 7)
            recentCheckIns = Array(allCheckIns.prefix(7))

            // Compute streak: consecutive days ending today or yesterday
            currentStreak = computeStreak(from: allCheckIns.map { $0.dateKey })

        } catch {
            // Fallback without ordering — sort client-side
            do {
                let snapshot = try await db.collection("checkIns")
                    .whereField("uid", isEqualTo: uid)
                    .getDocuments()

                let allCheckIns = snapshot.documents
                    .compactMap { DailyCheckIn(id: $0.documentID, data: $0.data()) }
                    .sorted { $0.dateKey > $1.dateKey }

                totalCheckIns = allCheckIns.count
                recentCheckIns = Array(allCheckIns.prefix(7))
                currentStreak = computeStreak(from: allCheckIns.map { $0.dateKey })
            } catch {
                // silently fail
            }
        }
    }

    // MARK: - Streak calculation helper
    private func computeStreak(from sortedKeys: [String]) -> Int {
        // sortedKeys should be sorted descending (most recent first)
        // Deduplicate (one check-in per day)
        let uniqueKeys = Array(NSOrderedSet(array: sortedKeys).array as! [String])

        guard !uniqueKeys.isEmpty else { return 0 }

        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")

        let today = f.string(from: Date())
        let yesterday = f.string(from: Calendar.current.date(byAdding: .day, value: -1, to: Date())!)

        // Streak must start from today or yesterday
        guard uniqueKeys[0] == today || uniqueKeys[0] == yesterday else { return 0 }

        var streak = 0
        var expected: Date = uniqueKeys[0] == today ? Date() : Calendar.current.date(byAdding: .day, value: -1, to: Date())!

        for key in uniqueKeys {
            let expectedKey = f.string(from: expected)
            if key == expectedKey {
                streak += 1
                expected = Calendar.current.date(byAdding: .day, value: -1, to: expected)!
            } else {
                break
            }
        }
        return streak
    }
}
