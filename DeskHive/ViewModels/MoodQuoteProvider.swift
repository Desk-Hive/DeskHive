//
//  MoodQuoteProvider.swift
//  DeskHive
//

import Foundation

struct MoodQuoteItem: Codable {
    let mood: String
    let quote: String
    let author: String
}

private struct ZenQuoteItem: Codable {
    let q: String
    let a: String
}

final class MoodQuoteProvider {
    static let shared = MoodQuoteProvider()

    private init() {
    }

    func fetchQuote(for mood: CheckInMood?) async -> MoodQuoteItem {
        if let live = await fetchFromAPI(for: mood) {
            return live
        }

        return fallbackQuote(for: mood)
    }

    private func fetchFromAPI(for mood: CheckInMood?) async -> MoodQuoteItem? {
        guard let url = URL(string: "https://zenquotes.io/api/quotes") else {
            return nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }

            let decoder = JSONDecoder()
            let remote = try decoder.decode([ZenQuoteItem].self, from: data)
            guard !remote.isEmpty else { return nil }

            let moodKey = mood?.rawValue.lowercased() ?? "default"
            let dayIndex = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
            let moodSeed = moodKey.unicodeScalars.map { Int($0.value) }.reduce(0, +)
            let idx = abs(dayIndex + moodSeed) % remote.count
            let picked = remote[idx]

            return MoodQuoteItem(
                mood: moodKey,
                quote: picked.q,
                author: picked.a
            )
        } catch {
            return nil
        }
    }

    private func fallbackQuote(for mood: CheckInMood?) -> MoodQuoteItem {
        let moodKey = mood?.rawValue.lowercased() ?? "default"
        let primary = Self.fallbackQuotes[moodKey] ?? []
        let pool = primary.isEmpty ? (Self.fallbackQuotes["default"] ?? []) : primary

        if pool.isEmpty {
            return MoodQuoteItem(
                mood: "default",
                quote: "One small step today creates a better tomorrow.",
                author: "DeskHive"
            )
        }

        let dayIndex = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let moodSeed = moodKey.unicodeScalars.map { Int($0.value) }.reduce(0, +)
        let idx = abs(dayIndex + moodSeed) % pool.count
        return pool[idx]
    }

    private static let fallbackQuotes: [String: [MoodQuoteItem]] = [
        "great": [
            MoodQuoteItem(mood: "great", quote: "Your energy is contagious. Turn it into momentum.", author: "DeskHive"),
            MoodQuoteItem(mood: "great", quote: "You are in flow today. Keep building while it feels natural.", author: "DeskHive")
        ],
        "good": [
            MoodQuoteItem(mood: "good", quote: "Consistency beats intensity. Keep your rhythm.", author: "DeskHive"),
            MoodQuoteItem(mood: "good", quote: "Good days are perfect for meaningful progress.", author: "DeskHive")
        ],
        "okay": [
            MoodQuoteItem(mood: "okay", quote: "You do not need perfect energy to do important work.", author: "DeskHive"),
            MoodQuoteItem(mood: "okay", quote: "Small focused steps still move big goals forward.", author: "DeskHive")
        ],
        "low": [
            MoodQuoteItem(mood: "low", quote: "Take one task, one breath, one win at a time.", author: "DeskHive"),
            MoodQuoteItem(mood: "low", quote: "A slower pace is still progress. Be kind to yourself today.", author: "DeskHive")
        ],
        "stressed": [
            MoodQuoteItem(mood: "stressed", quote: "Prioritize what matters most. Let the rest wait.", author: "DeskHive"),
            MoodQuoteItem(mood: "stressed", quote: "Calm focus turns pressure into clarity.", author: "DeskHive")
        ],
        "default": [
            MoodQuoteItem(mood: "default", quote: "Start where you are. Improve one thing today.", author: "DeskHive"),
            MoodQuoteItem(mood: "default", quote: "Your future self will thank you for the work you do now.", author: "DeskHive")
        ]
    ]
}
