//
//  NewsArticle.swift
//  DeskHive
//

import Foundation

// MARK: - Top-level API Response
struct NewsAPIResponse: Decodable {
    let status: String
    let totalResults: Int?
    let articles: [NewsArticle]
}

// MARK: - Article
struct NewsArticle: Identifiable, Decodable {
    var id: String { url }

    let source:      NewsSource
    let author:      String?
    let title:       String
    let description: String?
    let url:         String
    let urlToImage:  String?
    let publishedAt: String
    let content:     String?

    /// Human-readable relative date, e.g. "2h ago"
    var relativeDate: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: publishedAt)
               ?? ISO8601DateFormatter().date(from: publishedAt)
               ?? Date()

        let diff = Int(Date().timeIntervalSince(date))
        switch diff {
        case ..<60:           return "Just now"
        case 60..<3600:       return "\(diff / 60)m ago"
        case 3600..<86400:    return "\(diff / 3600)h ago"
        default:              return "\(diff / 86400)d ago"
        }
    }

    /// Sanitised title — remove " - Source" suffix that NewsAPI appends
    var cleanTitle: String {
        if let dash = title.lastIndex(of: "-") {
            let suffix = title[dash...].count
            if suffix < 40 { return String(title[..<dash]).trimmingCharacters(in: .whitespaces) }
        }
        return title
    }
}

// MARK: - Source
struct NewsSource: Decodable {
    let id:   String?
    let name: String
}
