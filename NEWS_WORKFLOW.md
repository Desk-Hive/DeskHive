# Tech News Feature — Complete Workflow

## Overview

The tech news feature fetches live articles from the **NewsAPI** and displays them inline on all dashboards and in a full-screen sheet. There is no Firebase involvement — all data comes directly from the external REST API.

---

## Files Involved

| File | Role |
|------|------|
| `Models/NewsArticle.swift` | Data models mapping NewsAPI JSON response |
| `ViewModels/NewsViewModel.swift` | Async fetch logic, state management |
| `Views/TechNewsView.swift` | All news UI components (full screen + inline widgets) |
| `Views/SafariView.swift` | In-app browser to open full articles |
| `Views/Admin/AdminDashboardView.swift` | Embeds `NewsPreviewSection` + opens `TechNewsView` |
| `Views/Employee/EmployeeDashboardView.swift` | Embeds `NewsPreviewSection` + opens `TechNewsView` |
| `Views/ProjectLead/ProjectLeadDashboardView.swift` | Embeds `NewsPreviewSection` + opens `TechNewsView` |

---

## Step 1 — Data Model (`Models/NewsArticle.swift`)

Two `Decodable` structs mirror the NewsAPI JSON shape:

```swift
// Top-level API response wrapper
struct NewsAPIResponse: Decodable {
    let status: String
    let totalResults: Int?
    let articles: [NewsArticle]
}

// Individual article
struct NewsArticle: Identifiable, Decodable {
    var id: String { url }        // URL used as unique ID

    let source:      NewsSource
    let author:      String?
    let title:       String
    let description: String?
    let url:         String
    let urlToImage:  String?
    let publishedAt: String
    let content:     String?
}

struct NewsSource: Decodable {
    let id:   String?
    let name: String
}
```

### Computed Helpers

**`relativeDate`** — converts ISO 8601 `publishedAt` into a human-readable string:

```
"Just now"  →  diff < 60 seconds
"5m ago"    →  diff < 1 hour
"3h ago"    →  diff < 1 day
"2d ago"    →  anything older
```

**`cleanTitle`** — strips the ` - Source Name` suffix that NewsAPI appends to all titles:

```swift
var cleanTitle: String {
    if let dash = title.lastIndex(of: "-") {
        let suffix = title[dash...].count
        if suffix < 40 { return String(title[..<dash]).trimmingCharacters(in: .whitespaces) }
    }
    return title
}
```

---

## Step 2 — ViewModel (`ViewModels/NewsViewModel.swift`)

```swift
@MainActor
final class NewsViewModel: ObservableObject {
    @Published var articles:     [NewsArticle] = []
    @Published var isLoading:    Bool          = false
    @Published var errorMessage: String?       = nil

    private let apiKey   = "f4b85f669cdf43bc83d110fe31fb5554"
    private let pageSize = 20
}
```

### `fetchTechNews()` — Async Flow

```
1. Guard against double-fetching (isLoading check)
2. Set isLoading = true, errorMessage = nil

3. Build URL:
   https://newsapi.org/v2/everything
     ?q=software+OR+programming+OR+developer+OR+technology
     &language=en
     &sortBy=publishedAt
     &pageSize=20
     &apiKey=<key>

4. URLSession.shared.data(from: url)   ← native Swift async/await HTTP GET

5. Check HTTP status code
   - Non-200 → parse NewsAPI error message → set errorMessage

6. JSONDecoder().decode(NewsAPIResponse.self, from: data)

7. Filter out articles where title == "[Removed]" or is empty

8. Publish to self.articles

9. Set isLoading = false
```

### `refresh()`

```swift
func refresh() async {
    articles = []              // clears current list first
    await fetchTechNews()      // re-fetches from scratch
}
```

---

## Step 3 — Entry Points (3 Dashboards)

All three dashboards wire up the news feature identically:

### Inline Preview (top 3 articles in dashboard)

```swift
// EmployeeDashboardView.swift (line ~280)
NewsPreviewSection(accentColor: Color(hex: "#4ECDC4")) {
    showTechNews = true
}

// AdminDashboardView.swift (line ~212)
NewsPreviewSection(accentColor: Color(hex: "#E94560")) {
    showTechNews = true
}

// ProjectLeadDashboardView.swift (line ~217)
NewsPreviewSection(accentColor: Color(hex: "#F5A623")) {
    showTechNews = true
}
```

### Full Screen Sheet (on "See All" tap)

```swift
// Each dashboard (lines ~91–97)
.sheet(isPresented: $showTechNews) {
    TechNewsView()
}
```

Each role has its own accent color but shares the same underlying components.

---

## Step 4 — UI Components (`Views/TechNewsView.swift`)

### A. `TechNewsView` — Full Screen Sheet

```
@StateObject var viewModel = NewsViewModel()   ← own instance

.task { await viewModel.fetchTechNews() }      ← fires on appear

State machine:
  isLoading && articles.isEmpty  →  loadingView   (spinner)
  errorMessage && articles.isEmpty →  errorView   (wifi.slash icon + retry)
  otherwise                      →  articleList
```

**`articleList` rendering logic:**

```
ForEach(articles.enumerated()) { index, article in
    index == 0  →  FeaturedNewsCard    (large banner, 180pt image)
    index >= 1  →  CompactNewsCard     (80×80 thumbnail row)
}
```

Supports **pull-to-refresh** via `.refreshable { await viewModel.refresh() }` and a manual **Refresh button** at the bottom.

---

### B. `FeaturedNewsCard` — First Article (index 0)

```
┌─────────────────────────────────┐
│  AsyncImage (180pt tall banner) │  ← urlToImage or cpu icon placeholder
│  or gradient placeholder        │
├─────────────────────────────────┤
│  📰 Source Name       "2h ago"  │
│  Clean Title (bold, 3 lines)    │
│  Description (2 lines, dimmed)  │
│  "Read full story →"            │
└─────────────────────────────────┘
         Tap → SafariView sheet
```

---

### C. `CompactNewsCard` — Articles 1+ (index >= 1)

```
┌──────┬──────────────────────────┐
│ 80×80│  Source Name   "3h ago"  │
│ img  │  Clean Title (3 lines)   │
│      │  ↗ Open                  │
└──────┴──────────────────────────┘
         Tap → SafariView sheet
```

---

### D. `NewsPreviewSection` — Dashboard Inline Widget

```
@StateObject var viewModel = NewsViewModel()   ← its OWN separate instance

.task { await viewModel.fetchTechNews() }

States:
  isLoading     → newsSkeletonView  (3 shimmer placeholder rows)
  errorMessage  → ErrorBanner
  otherwise     → articles.prefix(3) as InlineNewsRow
```

Header row shows "Tech News" label + "See All ›" button (calls `onSeeAll` closure → opens `TechNewsView` sheet in parent dashboard).

---

### E. `InlineNewsRow` — Used inside `NewsPreviewSection`

```
┌──────┬──────────────────────────┐
│ 60×60│  Source Name (accent)    │
│ img  │  Clean Title (2 lines)   │
│      │  "3d ago"                │
└──────┴──────────────────────────┘ › (chevron)
         Tap → SafariView sheet
```

---

## Step 5 — In-App Browser (`Views/SafariView.swift`)

Every card type has:
```swift
@State private var showSafari = false

Button(action: { showSafari = true }) { /* card UI */ }
.sheet(isPresented: $showSafari) {
    SafariView(url: URL(string: article.url)!)
        .ignoresSafeArea()
}
```

`SafariView` wraps `SFSafariViewController`:
```swift
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.preferredControlTintColor = UIColor(Color(hex: "#4ECDC4"))
        vc.dismissButtonStyle = .close
        return vc
    }
}
```

This opens the full article **inside the app** using the system Safari engine — no external app switch.

---

## Complete Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        Dashboard Appears                        │
│           (Admin / Employee / ProjectLead)                      │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
              NewsPreviewSection.task fires
                             │
                             ▼
              NewsViewModel.fetchTechNews()
                             │
                             ▼
         HTTP GET  newsapi.org/v2/everything
         ?q=software+OR+programming+OR+developer+OR+technology
         &language=en&sortBy=publishedAt&pageSize=20
                             │
                    ┌────────┴────────┐
                    │                 │
                 Success            Failure
                    │                 │
         JSONDecoder → NewsAPIResponse   errorMessage published
                    │
         Filter "[Removed]" titles
                    │
         articles[] published (ObservableObject)
                    │
         ┌──────────▼──────────┐
         │  NewsPreviewSection  │
         │  shows top 3 as      │
         │  InlineNewsRow       │
         └──────────┬──────────┘
                    │
         User taps "See All"
                    │
                    ▼
         TechNewsView (sheet)
         ├─ own NewsViewModel.fetchTechNews()
         ├─ articles[0] → FeaturedNewsCard
         └─ articles[1..N] → CompactNewsCard
                    │
         User taps any card
                    │
                    ▼
         SafariView (SFSafariViewController)
         Opens article.url inside the app
```

---

## Key Design Notes

- **No caching** — every `fetchTechNews()` call hits the network fresh.
- **Independent ViewModels** — `NewsPreviewSection` and `TechNewsView` each instantiate their own `NewsViewModel`, so they fetch independently and don't share state.
- **API key is hardcoded** in `NewsViewModel.swift` — not stored in environment or plist.
- **No pagination** — `pageSize=20` is the hard limit; there is no page 2 loading.
- **Image loading** uses SwiftUI's built-in `AsyncImage` — no third-party library (no Kingfisher/SDWebImage).
- The article `id` is derived from `url` (not a UUID), so duplicate URLs would cause SwiftUI `ForEach` identity conflicts.
