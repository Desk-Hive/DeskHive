//
//  TechNewsView.swift
//  DeskHive
//

import SwiftUI

// MARK: - Full News Screen
struct TechNewsView: View {
    @StateObject private var viewModel = NewsViewModel()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                // ── Header ───────────────────────────────────────────────
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tech News")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Latest in software & technology")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
                .padding(.bottom, 20)

                // ── Live indicator ───────────────────────────────────────
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: "#4ECDC4"))
                        .frame(width: 7, height: 7)
                        .overlay(
                            Circle()
                                .stroke(Color(hex: "#4ECDC4").opacity(0.4), lineWidth: 4)
                                .scaleEffect(1.8)
                        )
                    Text("Live Feed")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "#4ECDC4"))
                    Spacer()
                    if !viewModel.articles.isEmpty {
                        Text("\(viewModel.articles.count) articles")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.35))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)

                // ── Content ──────────────────────────────────────────────
                if viewModel.isLoading && viewModel.articles.isEmpty {
                    loadingView
                } else if let err = viewModel.errorMessage, viewModel.articles.isEmpty {
                    errorView(message: err)
                } else {
                    articleList
                }
            }
        }
        .task { await viewModel.fetchTechNews() }
    }

    // MARK: - Article List
    private var articleList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 14) {
                // Pull to refresh hint
                if viewModel.isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#4ECDC4")))
                            .scaleEffect(0.8)
                        Text("Refreshing…")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(.bottom, 4)
                }

                ForEach(Array(viewModel.articles.enumerated()), id: \.element.id) { index, article in
                    if index == 0 {
                        FeaturedNewsCard(article: article)
                    } else {
                        CompactNewsCard(article: article)
                    }
                }

                if let err = viewModel.errorMessage {
                    ErrorBanner(message: err).padding(.horizontal, 24)
                }

                // Refresh button at bottom
                Button(action: { Task { await viewModel.refresh() } }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh News")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "#4ECDC4"))
                    .padding(.vertical, 12)
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
        }
        .refreshable { await viewModel.refresh() }
    }

    // MARK: - Loading State
    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .stroke(Color(hex: "#4ECDC4").opacity(0.15), lineWidth: 3)
                    .frame(width: 60, height: 60)
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#4ECDC4")))
                    .scaleEffect(1.2)
            }
            Text("Fetching latest tech news…")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
            Spacer()
        }
    }

    // MARK: - Error State
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "wifi.slash")
                .font(.system(size: 44))
                .foregroundColor(.white.opacity(0.25))
            Text("Couldn't load news")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button(action: { Task { await viewModel.refresh() } }) {
                Text("Try Again")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#4ECDC4").opacity(0.2))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "#4ECDC4").opacity(0.4), lineWidth: 1))
            }
            Spacer()
        }
    }
}

// MARK: - Featured (First) Article Card
struct FeaturedNewsCard: View {
    let article: NewsArticle
    @State private var showSafari = false

    var body: some View {
        Button(action: { showSafari = true }) {
            VStack(alignment: .leading, spacing: 0) {
                // Image banner or placeholder
                ZStack {
                    if let imageURL = article.urlToImage, let url = URL(string: imageURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().aspectRatio(contentMode: .fill)
                            default:
                                newsPlaceholder
                            }
                        }
                    } else {
                        newsPlaceholder
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipped()
                .cornerRadius(16, corners: [.topLeft, .topRight])

                // Text content
                VStack(alignment: .leading, spacing: 10) {
                    // Source + time
                    HStack(spacing: 6) {
                        Image(systemName: "newspaper.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "#4ECDC4"))
                        Text(article.source.name)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(hex: "#4ECDC4"))
                        Spacer()
                        Text(article.relativeDate)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.4))
                    }

                    Text(article.cleanTitle)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    if let desc = article.description, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.55))
                            .lineLimit(2)
                    }

                    HStack(spacing: 4) {
                        Text("Read full story")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: "#4ECDC4"))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color(hex: "#4ECDC4"))
                    }
                    .padding(.top, 2)
                }
                .padding(16)
                .background(Color.white.opacity(0.08))
                .cornerRadius(16, corners: [.bottomLeft, .bottomRight])
            }
            .background(Color.white.opacity(0.08))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "#4ECDC4").opacity(0.25), lineWidth: 1))
            .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSafari) {
            if let url = URL(string: article.url) {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
    }

    private var newsPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#0F3460"), Color(hex: "#16213E")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 8) {
                Image(systemName: "cpu")
                    .font(.system(size: 36))
                    .foregroundColor(Color(hex: "#4ECDC4").opacity(0.5))
                Text("Tech News")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
    }
}

// MARK: - Compact Article Card
struct CompactNewsCard: View {
    let article: NewsArticle
    @State private var showSafari = false

    var body: some View {
        Button(action: { showSafari = true }) {
            HStack(alignment: .top, spacing: 14) {
                // Thumbnail or icon
                ZStack {
                    if let imageURL = article.urlToImage, let url = URL(string: imageURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().aspectRatio(contentMode: .fill)
                            default:
                                compactPlaceholder
                            }
                        }
                    } else {
                        compactPlaceholder
                    }
                }
                .frame(width: 80, height: 80)
                .clipped()
                .cornerRadius(12)

                // Text
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Text(article.source.name)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color(hex: "#4ECDC4"))
                            .lineLimit(1)
                        Spacer()
                        Text(article.relativeDate)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.35))
                    }

                    Text(article.cleanTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 10))
                        Text("Open")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.3))
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .background(Color.white.opacity(0.07))
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSafari) {
            if let url = URL(string: article.url) {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
    }

    private var compactPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "#0F3460"))
            Image(systemName: "cpu")
                .font(.system(size: 22))
                .foregroundColor(Color(hex: "#4ECDC4").opacity(0.4))
        }
    }
}

// MARK: - News Preview Section (used inline in dashboards)
struct NewsPreviewSection: View {
    @StateObject private var viewModel = NewsViewModel()
    let accentColor: Color
    let onSeeAll: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            // Section header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "newspaper.fill")
                        .font(.system(size: 15))
                        .foregroundColor(accentColor)
                    Text("Tech News")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                Spacer()
                Button(action: onSeeAll) {
                    HStack(spacing: 4) {
                        Text("See All")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(accentColor)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(accentColor)
                    }
                }
            }

            if viewModel.isLoading {
                newsSkeletonView
            } else if let err = viewModel.errorMessage {
                ErrorBanner(message: err)
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.articles.prefix(3)) { article in
                        InlineNewsRow(article: article, accentColor: accentColor)
                    }
                }
            }
        }
        .task { await viewModel.fetchTechNews() }
    }

    private var newsSkeletonView: some View {
        VStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.07))
                        .frame(width: 60, height: 60)
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.07))
                            .frame(height: 12)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.05))
                            .frame(height: 10)
                            .padding(.trailing, 40)
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - Inline News Row (for dashboard preview)
struct InlineNewsRow: View {
    let article: NewsArticle
    let accentColor: Color
    @State private var showSafari = false

    var body: some View {
        Button(action: { showSafari = true }) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    if let imageURL = article.urlToImage, let url = URL(string: imageURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().aspectRatio(contentMode: .fill)
                            default:
                                inlinePlaceholder
                            }
                        }
                    } else {
                        inlinePlaceholder
                    }
                }
                .frame(width: 60, height: 60)
                .clipped()
                .cornerRadius(10)

                VStack(alignment: .leading, spacing: 4) {
                    Text(article.source.name)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(accentColor)
                    Text(article.cleanTitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    Text(article.relativeDate)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.35))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.2))
            }
            .padding(12)
            .background(Color.white.opacity(0.06))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.09), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSafari) {
            if let url = URL(string: article.url) {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
    }

    private var inlinePlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: "#0F3460"))
            Image(systemName: "cpu")
                .font(.system(size: 18))
                .foregroundColor(accentColor.opacity(0.4))
        }
    }
}

#Preview {
    TechNewsView()
}
