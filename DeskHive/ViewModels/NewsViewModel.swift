//
//  NewsViewModel.swift
//  DeskHive
//

import Foundation
import SwiftUI

@MainActor
final class NewsViewModel: ObservableObject {

    // MARK: - Published State
    @Published var articles:     [NewsArticle] = []
    @Published var isLoading:    Bool          = false
    @Published var errorMessage: String?       = nil

    // MARK: - Private
    private let apiKey   = "f4b85f669cdf43bc83d110fe31fb5554"
    private let pageSize = 20

    // MARK: - Fetch
    func fetchTechNews() async {
        guard !isLoading else { return }
        isLoading    = true
        errorMessage = nil

        let urlString =
            "https://newsapi.org/v2/everything" +
            "?q=software+OR+programming+OR+developer+OR+technology" +
            "&language=en" +
            "&sortBy=publishedAt" +
            "&pageSize=\(pageSize)" +
            "&apiKey=\(apiKey)"

        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL."
            isLoading = false
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                // Try to parse the error message from NewsAPI
                if let body = try? JSONDecoder().decode([String: String].self, from: data),
                   let msg  = body["message"] {
                    errorMessage = msg
                } else {
                    errorMessage = "Server error (\(http.statusCode))."
                }
                isLoading = false
                return
            }

            let decoded = try JSONDecoder().decode(NewsAPIResponse.self, from: data)
            // Filter out articles with "[Removed]" titles
            articles = decoded.articles.filter { $0.title != "[Removed]" && !$0.title.isEmpty }

        } catch {
            errorMessage = "Failed to load news: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func refresh() async {
        articles = []
        await fetchTechNews()
    }
}
