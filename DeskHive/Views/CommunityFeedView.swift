//
//  CommunityFeedView.swift
//  DeskHive
//
//  Reusable feed screen for a single microcommunity.
//  Works for both admin (isAdmin=true) and employees (isAdmin=false).
//

import SwiftUI

struct CommunityFeedView: View {
    let community: Microcommunity
    let senderEmail: String      // logged-in user email
    let senderID: String         // logged-in user UID
    let isAdmin: Bool

    @StateObject private var feedVM = FeedViewModel()
    @State private var messageText = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {

                // MARK: - Top bar
                HStack(spacing: 12) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(community.name)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        if !community.project.isEmpty {
                            Text(community.project)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(hex: "#F5A623"))
                        }
                        if !community.projectLeadEmail.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 9))
                                Text("Lead: \(community.projectLeadEmail.components(separatedBy: "@").first ?? community.projectLeadEmail)")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(Color(hex: "#F5A623").opacity(0.8))
                        }
                    }

                    Spacer()

                    // Member count pill
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 11))
                        Text("\(community.memberIDs.count)")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(Color(hex: "#4ECDC4"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(hex: "#4ECDC4").opacity(0.12))
                    .cornerRadius(10)
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)
                .padding(.bottom, 14)

                Divider().background(Color.white.opacity(0.1))

                // MARK: - Feed messages
                if feedVM.isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Spacer()
                } else if feedVM.messages.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.2))
                        Text("No messages yet")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.4))
                        Text("Be the first to post in this community.")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    Spacer()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: true) {
                            LazyVStack(spacing: 12) {
                                ForEach(feedVM.messages) { msg in
                                    FeedMessageBubble(
                                        message: msg,
                                        isMine: msg.senderID == senderID || (isAdmin && msg.isAdminPost),
                                        isAdmin: isAdmin
                                    ) {
                                        Task { await feedVM.deleteMessage(communityID: community.id, messageID: msg.id) }
                                    }
                                    .id(msg.id)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        .onChange(of: feedVM.messages.count) { _ in
                            if let last = feedVM.messages.last {
                                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                            }
                        }
                        .onAppear {
                            if let last = feedVM.messages.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                // Error banner
                if let err = feedVM.errorMessage {
                    ErrorBanner(message: err).padding(.horizontal, 16).padding(.bottom, 4)
                }

                // MARK: - Compose bar
                VStack(spacing: 0) {
                    Divider().background(Color.white.opacity(0.1))
                    HStack(spacing: 12) {
                        TextField("",
                                  text: $messageText,
                                  prompt: Text("Write a message…").foregroundColor(.white.opacity(0.3)),
                                  axis: .vertical)
                            .foregroundColor(.white)
                            .tint(Color(hex: "#4ECDC4"))
                            .lineLimit(1...4)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 1))

                        Button(action: sendMessage) {
                            ZStack {
                                Circle()
                                    .fill(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                          ? Color.white.opacity(0.1)
                                          : Color(hex: "#4ECDC4"))
                                    .frame(width: 42, height: 42)
                                if feedVM.isSending {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.7)
                                } else {
                                    Image(systemName: "paperplane.fill")
                                        .foregroundColor(.white)
                                        .font(.system(size: 16))
                                }
                            }
                        }
                        .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || feedVM.isSending)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .padding(.bottom, 20)
                }
                .background(Color(hex: "#1A1A2E"))
            }
        }
        .onAppear  { feedVM.startListening(communityID: community.id) }
        .onDisappear { feedVM.stopListening() }
    }

    private func sendMessage() {
        Task {
            await feedVM.postMessage(
                communityID: community.id,
                body: messageText,
                senderEmail: senderEmail,
                senderID: senderID,
                isAdminPost: isAdmin
            )
            messageText = ""
        }
    }
}

// MARK: - Message Bubble

private struct FeedMessageBubble: View {
    let message: FeedMessage
    let isMine: Bool
    let isAdmin: Bool          // viewer is admin (can delete any message)
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isMine { Spacer(minLength: 40) }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {

                // Sender name + admin badge
                HStack(spacing: 6) {
                    if message.isAdminPost {
                        Text("Admin")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: "#E94560"))
                            .cornerRadius(4)
                    }
                    Text(message.senderEmail.components(separatedBy: "@").first ?? message.senderEmail)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                }

                // Bubble
                Text(message.body)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        isMine
                        ? (message.isAdminPost ? Color(hex: "#E94560").opacity(0.7) : Color(hex: "#4ECDC4").opacity(0.6))
                        : Color.white.opacity(0.1)
                    )
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isMine ? Color.clear : Color.white.opacity(0.1), lineWidth: 1)
                    )

                // Timestamp + delete
                HStack(spacing: 8) {
                    Text(timeString(message.createdAt))
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.3))

                    // Admin can delete any message
                    if isAdmin {
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: "#E94560").opacity(0.6))
                        }
                    }
                }
            }

            if !isMine { Spacer(minLength: 40) }
        }
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, h:mm a"
        return f.string(from: date)
    }
}
