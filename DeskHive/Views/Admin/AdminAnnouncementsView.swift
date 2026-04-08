//
//  AdminAnnouncementsView.swift
//  DeskHive
//
//  Admin panel for managing broadcast announcements sent to all employees.
//  Supports three priority levels (Info, Warning, Urgent) and allows the
//  admin to delete any existing announcement. Announcements are persisted
//  in Firestore and fetched once on view appearance via AnnouncementViewModel.
//

import SwiftUI

struct AdminAnnouncementsView: View {
    // Owned here so the sheet and list share the same view-model instance
    @StateObject private var annVM = AnnouncementViewModel()

    // Controls presentation of the PostAnnouncementSheet
    @State private var showPost = false

    var body: some View {
        VStack(spacing: 16) {

            // Header — title on the left, "Post" button on the right
            HStack {
                Text("Announcements")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Button(action: { showPost = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("Post")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Color(hex: "#4ECDC4"))
                    .cornerRadius(10)
                }
            }
            .padding(.horizontal, 24)

            if let ok = annVM.successMessage {
                SuccessBanner(message: ok).padding(.horizontal, 24)
            }
            if let err = annVM.errorMessage {
                ErrorBanner(message: err).padding(.horizontal, 24)
            }

            if annVM.isLoading {
                Spacer()
                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                Spacer()
            } else if annVM.announcements.isEmpty {
                EmptyStateView(
                    icon: "megaphone",
                    title: "No Announcements",
                    subtitle: "Tap 'Post' to send an announcement to all employees."
                ).padding(.top, 40)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(annVM.announcements) { ann in
                        AdminAnnouncementRow(announcement: ann) {
                            Task { await annVM.deleteAnnouncement(ann) }
                        }
                    }
                }
                .padding(.horizontal, 24)
            }

            Spacer().frame(height: 40)
        }
        .sheet(isPresented: $showPost, onDismiss: { annVM.successMessage = nil }) {
            PostAnnouncementSheet(annVM: annVM)
        }
        .task { await annVM.fetchOnce() }
    }
}

// MARK: - Admin row

/// A single row in the announcements list.
/// Displays the priority badge, title, truncated body, post date, and a delete button.
/// The `onDelete` closure is called when the trash button is tapped; the
/// actual Firestore deletion is performed by the parent via `annVM.deleteAnnouncement`.
private struct AdminAnnouncementRow: View {
    let announcement: Announcement
    let onDelete: () -> Void

    /// Resolves the tint colour from the announcement's priority level.
    var priorityColor: Color { Color(hex: announcement.priority.color) }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Priority icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(priorityColor.opacity(0.12))
                    .frame(width: 42, height: 42)
                Image(systemName: announcement.priority.icon)
                    .foregroundColor(priorityColor)
                    .font(.system(size: 18))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(announcement.priority.label)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(priorityColor)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(priorityColor.opacity(0.12))
                        .cornerRadius(5)
                    Spacer()
                    Text(shortDate(announcement.createdAt))
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.3))
                }
                Text(announcement.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text(announcement.body)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(2)
            }

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#E94560").opacity(0.7))
                    .padding(8)
                    .background(Color(hex: "#E94560").opacity(0.08))
                    .cornerRadius(8)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.07))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMM d"
        return f.string(from: date)
    }
}

// MARK: - Post announcement sheet

/// Full-screen composition sheet for creating a new announcement.
/// The admin selects a priority level, writes a title and message body,
/// then taps "Post Announcement" to persist it to Firestore.
/// The sheet dismisses automatically after a successful post.
struct PostAnnouncementSheet: View {
    @ObservedObject var annVM: AnnouncementViewModel
    @Environment(\.dismiss) var dismiss

    @State private var title    = ""  // Announcement subject line
    @State private var body_    = ""  // Full message body (multiline)
    @State private var priority = Announcement.AnnouncementPriority.info  // Defaults to Info

    var body: some View {
        ZStack {
            AppBackground().ignoresSafeArea()

            VStack(spacing: 0) {

                // Top bar
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("New Announcement")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Color.clear.frame(width: 34, height: 34)
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)
                .padding(.bottom, 16)

                ScrollView(showsIndicators: true) {
                    VStack(spacing: 20) {

                        // Decorative icon and subtitle shown at the top of the sheet
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "#4ECDC4").opacity(0.15))
                                    .frame(width: 64, height: 64)
                                Image(systemName: "megaphone.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(Color(hex: "#4ECDC4"))
                            }
                            Text("Broadcast to all employees")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.5))
                        }

                        // Priority picker — tapping a level highlights it and stores the selection
                        DeskHiveCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Priority", systemImage: "flag.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.6))
                                HStack(spacing: 10) {
                                    ForEach([Announcement.AnnouncementPriority.info,
                                             .warning, .urgent], id: \.rawValue) { p in
                                        Button(action: { priority = p }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: p.icon).font(.system(size: 11))
                                                Text(p.label).font(.system(size: 12, weight: .semibold))
                                            }
                                            .foregroundColor(priority == p
                                                             ? Color(hex: p.color) : .white.opacity(0.4))
                                            .frame(maxWidth: .infinity).padding(.vertical, 9)
                                            .background(priority == p
                                                        ? Color(hex: p.color).opacity(0.15)
                                                        : Color.white.opacity(0.05))
                                            .cornerRadius(9)
                                            .overlay(RoundedRectangle(cornerRadius: 9)
                                                .stroke(priority == p
                                                        ? Color(hex: p.color).opacity(0.4)
                                                        : Color.white.opacity(0.1), lineWidth: 1))
                                        }
                                    }
                                }
                            }
                        }

                        // Title input — required field; button stays disabled while empty
                        DeskHiveCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Title *", systemImage: "pencil")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.6))
                                TextField("", text: $title,
                                          prompt: Text("e.g. Office Closed Friday")
                                            .foregroundColor(.white.opacity(0.3)))
                                    .foregroundColor(.white)
                                    .tint(Color(hex: "#4ECDC4"))
                            }
                        }

                        // Message body — required; grows vertically up to 10 lines
                        DeskHiveCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Message *", systemImage: "text.alignleft")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.6))
                                TextField("", text: $body_,
                                          prompt: Text("Write your announcement…")
                                            .foregroundColor(.white.opacity(0.3)),
                                          axis: .vertical)
                                    .foregroundColor(.white)
                                    .tint(Color(hex: "#4ECDC4"))
                                    .lineLimit(4...10)
                            }
                        }

                        if let err = annVM.errorMessage { ErrorBanner(message: err) }

                        Spacer().frame(height: 8)
                    }
                    .padding(.horizontal, 20)
                }

                // Sticky bottom bar with the "Post Announcement" action button.
                // Disabled and dimmed until both title and body are non-empty.
                VStack(spacing: 0) {
                    Divider().background(Color.white.opacity(0.08))
                    Button(action: {
                        Task {
                            await annVM.postAnnouncement(title: title, body: body_, priority: priority)
                            if annVM.errorMessage == nil { dismiss() }
                        }
                    }) {
                        ZStack {
                            LinearGradient(
                                gradient: Gradient(colors: [Color(hex: "#4ECDC4"), Color(hex: "#2AAFA5")]),
                                startPoint: .leading, endPoint: .trailing)
                                .cornerRadius(14)
                                .shadow(color: Color(hex: "#4ECDC4").opacity(0.35), radius: 8, x: 0, y: 4)

                            if annVM.isPosting {
                                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                HStack(spacing: 8) {
                                    Image(systemName: "megaphone.fill")
                                    Text("Post Announcement")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity).frame(height: 54)
                    }
                    .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 32)
                    .disabled(annVM.isPosting
                              || title.trimmingCharacters(in: .whitespaces).isEmpty
                              || body_.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(title.trimmingCharacters(in: .whitespaces).isEmpty
                             || body_.trimmingCharacters(in: .whitespaces).isEmpty ? 0.45 : 1)
                }
                .background(Color(hex: "#1A1A2E").opacity(0.95))
            }
        }
    }
}
