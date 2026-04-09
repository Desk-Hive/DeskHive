//
//  AdminIssuesView.swift
//  DeskHive
//
//  Admin view for browsing, filtering, and responding to anonymous issue reports.
//  Reports are submitted by employees and stored in Firestore. The admin can
//  update the status (Open → In Review → Resolved) and attach a written response
//  that the reporting employee will see on their end.
//

import SwiftUI

struct AdminIssuesView: View {
    // Shared view-model passed down from AdminDashboardView
    @ObservedObject var adminVM: AdminViewModel

    /// Currently selected status filter; `nil` means show all reports.
    @State private var filterStatus: IssueStatus? = nil
    /// Non-nil value opens the IssueResponseSheet for that report.
    @State private var selectedIssue: IssueReport? = nil

    /// Returns the subset of issues matching the active filter chip,
    /// or the full list when no filter is applied.
    private var filteredIssues: [IssueReport] {
        guard let f = filterStatus else { return adminVM.issues }
        return adminVM.issues.filter { $0.status == f }
    }

    var body: some View {
        VStack(spacing: 16) {

            // ── Filter chips ─────────────────────────────────────────────
            // Horizontal row of pill buttons; tapping one narrows the list
            // to that status. "All" resets the filter to show every report.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    FilterChip(label: "All", icon: "tray.full", active: filterStatus == nil) {
                        filterStatus = nil
                    }
                    FilterChip(label: "Open", icon: IssueStatus.open.icon,
                               color: Color(hex: IssueStatus.open.color),
                               active: filterStatus == .open) {
                        filterStatus = .open
                    }
                    FilterChip(label: "In Review", icon: IssueStatus.inReview.icon,
                               color: Color(hex: IssueStatus.inReview.color),
                               active: filterStatus == .inReview) {
                        filterStatus = .inReview
                    }
                    FilterChip(label: "Resolved", icon: IssueStatus.resolved.icon,
                               color: Color(hex: IssueStatus.resolved.color),
                               active: filterStatus == .resolved) {
                        filterStatus = .resolved
                    }
                }
                .padding(.horizontal, 24)
            }

            // ── Error banner ─────────────────────────────────────────────
            // Displayed if the Firestore fetch or an update operation fails
            if let err = adminVM.issuesError {
                ErrorBanner(message: err).padding(.horizontal, 24)
            }

            // ── List ─────────────────────────────────────────────────────
            // Shows a spinner while loading, an empty state when the filtered
            // list is empty, or the full card list when data is available.
            if adminVM.isLoadingIssues {
                Spacer()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                Spacer()
            } else if filteredIssues.isEmpty {
                Spacer()
                EmptyStateView(
                    icon: "tray",
                    title: "No Issues",
                    subtitle: filterStatus == nil
                        ? "No issues have been submitted yet."
                        : "No \(filterStatus!.label.lowercased()) issues."
                )
                Spacer()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(filteredIssues) { issue in
                        IssueAdminRow(issue: issue) {
                            selectedIssue = issue
                        }
                    }
                }
                .padding(.horizontal, 24)
            }

            Spacer().frame(height: 40)
        }
        .sheet(item: $selectedIssue) { issue in
            IssueResponseSheet(issue: issue, adminVM: adminVM)
        }
        .task {
            // Fetch all issue reports when the tab first becomes visible
            await adminVM.fetchIssues()
        }
    }
}

// MARK: - Single issue row (admin list)

/// A tappable card that summarises one anonymous issue report.
/// Displays the case ID, status badge, category, title, description preview,
/// submission date, and a "Responded" indicator when the admin has already replied.
private struct IssueAdminRow: View {
    let issue: IssueReport
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {

                // Top: Case ID (monospaced for quick scanning) + coloured status badge
                HStack {
                    Text(issue.id)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.45))

                    Spacer()

                    // Status badge
                    HStack(spacing: 4) {
                        Image(systemName: issue.status.icon)
                            .font(.system(size: 10))
                        Text(issue.status.label)
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(Color(hex: issue.status.color))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color(hex: issue.status.color).opacity(0.15))
                    .cornerRadius(7)
                    .overlay(RoundedRectangle(cornerRadius: 7)
                        .stroke(Color(hex: issue.status.color).opacity(0.4), lineWidth: 1))
                }

                // Category chip — coloured icon + label (e.g. "Workplace", "IT")
                HStack(spacing: 5) {
                    Image(systemName: issue.category.icon)
                        .font(.system(size: 11))
                    Text(issue.category.label)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(Color(hex: issue.category.color))

                // Title
                Text(issue.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                // Description preview — truncated to 2 lines for compact display
                Text(issue.description)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(2)

                // Footer: relative submission date and optional "Responded" pill
                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.3))
                    Text(relativeDate(issue.createdAt))
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.35))
                    Spacer()
                    if !issue.adminResponse.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.left.fill")
                                .font(.system(size: 10))
                            Text("Responded")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(Color(hex: "#4ECDC4"))
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.07))
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func relativeDate(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Response sheet

/// Full-screen detail sheet where the admin reads the full issue report,
/// updates its status (Open / In Review / Resolved), and writes a response
/// that will be visible to the employee who submitted the report.
/// Initial values are pre-populated from the existing issue data.
struct IssueResponseSheet: View {
    let issue: IssueReport
    @ObservedObject var adminVM: AdminViewModel
    @Environment(\.dismiss) var dismiss

    @State private var responseText: String   // Pre-filled with any existing admin response
    @State private var selectedStatus: IssueStatus  // Pre-filled with current issue status

    /// Seeds the editable state from the issue passed in so the form
    /// always reflects the latest persisted values when opened.
    init(issue: IssueReport, adminVM: AdminViewModel) {
        self.issue = issue
        self.adminVM = adminVM
        _responseText = State(initialValue: issue.adminResponse)
        _selectedStatus = State(initialValue: issue.status)
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: 20)

                    // Header — icon, "Issue Details" title, and case ID
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#E94560").opacity(0.15))
                                .frame(width: 64, height: 64)
                            Image(systemName: "bubble.left.and.text.bubble.right.fill")
                                .font(.system(size: 26))
                                .foregroundColor(Color(hex: "#E94560"))
                        }
                        Text("Issue Details")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text(issue.id)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                    }

                    // Issue summary — read-only card showing category, status, title, and full description
                    DeskHiveCard {
                        VStack(alignment: .leading, spacing: 12) {

                            // Category + current status
                            HStack {
                                HStack(spacing: 5) {
                                    Image(systemName: issue.category.icon)
                                        .font(.system(size: 12))
                                    Text(issue.category.label)
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(Color(hex: issue.category.color))
                                Spacer()
                                HStack(spacing: 4) {
                                    Image(systemName: issue.status.icon)
                                        .font(.system(size: 11))
                                    Text(issue.status.label)
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .foregroundColor(Color(hex: issue.status.color))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(Color(hex: issue.status.color).opacity(0.15))
                                .cornerRadius(7)
                            }

                            Divider().background(Color.white.opacity(0.1))

                            Text(issue.title)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)

                            Text(issue.description)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }

                    // Status picker — tapping a pill updates `selectedStatus` locally;
                    // the change is persisted to Firestore when "Send Response" is tapped.
                    DeskHiveCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Update Status")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))

                            HStack(spacing: 10) {
                                ForEach([IssueStatus.open, .inReview, .resolved], id: \.self) { s in
                                    Button(action: { selectedStatus = s }) {
                                        HStack(spacing: 5) {
                                            Image(systemName: s.icon)
                                                .font(.system(size: 11))
                                            Text(s.label)
                                                .font(.system(size: 12, weight: .medium))
                                        }
                                        .foregroundColor(selectedStatus == s ? Color(hex: s.color) : .white.opacity(0.4))
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity)
                                        .background(selectedStatus == s ? Color(hex: s.color).opacity(0.15) : Color.white.opacity(0.05))
                                        .cornerRadius(9)
                                        .overlay(RoundedRectangle(cornerRadius: 9)
                                            .stroke(selectedStatus == s ? Color(hex: s.color).opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1))
                                    }
                                }
                            }
                        }
                    }

                    // Response text field — multiline, grows up to 10 lines
                    DeskHiveCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Admin Response")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))

                            TextField("",
                                      text: $responseText,
                                      prompt: Text("Write your response here…").foregroundColor(.white.opacity(0.3)),
                                      axis: .vertical)
                                .foregroundColor(.white)
                                .tint(Color(hex: "#4ECDC4"))
                                .lineLimit(4...10)
                                .padding(12)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(10)
                        }
                    }

                    // Inline error banner if the submit call fails
                    if let err = adminVM.issuesError {
                        ErrorBanner(message: err)
                    }

                    // Submit button — persists status + response to Firestore, then dismisses
                    Button(action: {
                        Task {
                            await adminVM.respondToIssue(
                                issueID: issue.id,
                                response: responseText,
                                newStatus: selectedStatus
                            )
                            if adminVM.issuesError == nil {
                                dismiss()
                            }
                        }
                    }) {
                        ZStack {
                            LinearGradient(
                                gradient: Gradient(colors: [Color(hex: "#4ECDC4"), Color(hex: "#2AAFA5")]),
                                startPoint: .leading, endPoint: .trailing
                            )
                            .cornerRadius(14)
                            .shadow(color: Color(hex: "#4ECDC4").opacity(0.4), radius: 10, x: 0, y: 5)

                            if adminVM.isRespondingToIssue {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                HStack(spacing: 8) {
                                    Image(systemName: "paperplane.fill")
                                    Text("Send Response")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                    }
                    .disabled(adminVM.isRespondingToIssue)

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 24)
            }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 24)
                    .padding(.top, 56)
                }
                Spacer()
            }
        }
    }
}

// MARK: - Filter chip helper

/// A small pill-shaped toggle button used in the horizontal filter bar.
/// Highlighted in `color` when `active` is true; muted white otherwise.
private struct FilterChip: View {
    let label: String
    let icon: String
    var color: Color = .white  // Defaults to white for the "All" chip
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(active ? color : .white.opacity(0.5))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(active ? color.opacity(0.15) : Color.white.opacity(0.06))
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20)
                .stroke(active ? color.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1))
        }
    }
}
