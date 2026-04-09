//
//  AIChatView.swift
//  DeskHive
//
//  Full-screen AI chat grounded on the project docs of a community.
//

import SwiftUI

struct AIChatView: View {

    let community: Microcommunity

    @StateObject private var vm = AIChatViewModel()
    @State private var inputText = ""
    @FocusState private var fieldFocused: Bool
    @Environment(\.dismiss) private var dismiss

    // accent colour for this chat
    private let accent = Color(hex: "#7C3AED")
    private let accentAlt = Color(hex: "#4ECDC4")

    var body: some View {
        ZStack {
            AppBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Divider().background(Color.white.opacity(0.08))
                messageList
                inputBar
            }
        }
        .navigationBarHidden(true)
        .task {
            await vm.loadChunks(communityID: community.id)
        }
    }

    // ── Header ───────────────────────────────────────────────────────────
    private var header: some View {
        HStack(spacing: 12) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(10)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }

            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(colors: [accent, accentAlt],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 38, height: 38)
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("AI Assistant")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(community.name)
                    .font(.system(size: 11))
                    .foregroundColor(accentAlt)
                    .lineLimit(1)
            }

            Spacer()

            // Status indicator
            if vm.isThinking {
                HStack(spacing: 5) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: accent))
                        .scaleEffect(0.75)
                    Text("Thinking…")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                }
            } else if vm.chunksReady {
                HStack(spacing: 4) {
                    Circle().fill(accentAlt).frame(width: 6, height: 6)
                    Text("Ready")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            Button(action: { vm.clearChat() }) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.35))
                    .padding(8)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // ── Message list ─────────────────────────────────────────────────────
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    ForEach(vm.messages) { msg in
                        MessageBubble(message: msg, accent: accent, accentAlt: accentAlt)
                            .id(msg.id)
                    }
                    if vm.isThinking && vm.messages.last?.role != .assistant {
                        TypingIndicator(accent: accent)
                            .id("typing")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: vm.messages.count) { _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo(vm.messages.last?.id, anchor: .bottom)
                }
            }
            .onChange(of: vm.isThinking) { thinking in
                withAnimation(.easeOut(duration: 0.3)) {
                    if thinking {
                        proxy.scrollTo("typing", anchor: .bottom)
                    } else {
                        proxy.scrollTo(vm.messages.last?.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // ── Input bar ────────────────────────────────────────────────────────
    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider().background(Color.white.opacity(0.08))
            HStack(spacing: 10) {
                TextField("Ask about this project…", text: $inputText, axis: .vertical)
                    .lineLimit(1...5)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .focused($fieldFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(22)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(fieldFocused ? accent.opacity(0.5) : Color.clear, lineWidth: 1)
                    )
                    .onSubmit { sendMessage() }

                Button(action: sendMessage) {
                    ZStack {
                        Circle()
                            .fill(
                                vm.isThinking || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? AnyShapeStyle(Color.white.opacity(0.1))
                                : AnyShapeStyle(LinearGradient(colors: [accent, accentAlt],
                                                  startPoint: .topLeading, endPoint: .bottomTrailing))
                            )
                            .frame(width: 42, height: 42)
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(
                                vm.isThinking || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? .white.opacity(0.2) : .white
                            )
                    }
                }
                .disabled(vm.isThinking || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(Color(hex: "#1A1A2E").opacity(0.97))
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !vm.isThinking else { return }
        inputText = ""
        fieldFocused = false
        Task { await vm.send(userText: text) }
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: ChatMessage
    let accent: Color
    let accentAlt: Color

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .user { Spacer(minLength: 48) }

            if message.role == .assistant {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [accent, accentAlt],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 30, height: 30)
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }
                .alignmentGuide(.bottom) { d in d[.bottom] }
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if message.role == .user {
                    Text("You")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.horizontal, 4)
                }
                Text(LocalizedStringKey(message.text))
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Group {
                            if message.role == .user {
                                LinearGradient(colors: [accent.opacity(0.85), accentAlt.opacity(0.75)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)
                            } else {
                                LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.06)],
                                               startPoint: .top, endPoint: .bottom)
                            }
                        }
                    )
                    .cornerRadius(message.role == .user ? 18 : 16, corners: message.role == .user
                        ? [.topLeft, .topRight, .bottomLeft]
                        : [.topLeft, .topRight, .bottomRight])
                    .overlay(
                        Group {
                            if message.role != .user {
                                RoundedCorner(radius: 16, corners: [.topLeft, .topRight, .bottomRight])
                                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
                            }
                        }
                    )
                    .textSelection(.enabled)
            }

            if message.role == .assistant { Spacer(minLength: 48) }
            if message.role == .user {
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 30, height: 30)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.5))
                    )
                    .alignmentGuide(.bottom) { d in d[.bottom] }
            }
        }
    }
}

// MARK: - Typing Indicator

private struct TypingIndicator: View {
    let accent: Color
    @State private var animating = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.3))
                    .frame(width: 30, height: 30)
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundColor(accent)
            }
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.white.opacity(0.4))
                        .frame(width: 7, height: 7)
                        .scaleEffect(animating ? 1.0 : 0.5)
                        .opacity(animating ? 1.0 : 0.3)
                        .animation(
                            .easeInOut(duration: 0.5)
                                .repeatForever()
                                .delay(Double(i) * 0.18),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.07))
            .cornerRadius(16, corners: [.topLeft, .topRight, .bottomRight])
            Spacer(minLength: 48)
        }
        .onAppear { animating = true }
        .onDisappear { animating = false }
    }
}

// RoundedCorner and cornerRadius(_:corners:) are declared in SharedComponents.swift
