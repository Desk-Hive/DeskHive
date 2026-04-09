//
//  UIComponents.swift
//  DeskHive
//
//  Reusable UI components used across all views.
//

import SwiftUI

// MARK: - App Background
/// Full-screen dark gradient used as the standard background on every screen.
struct AppBackground: View {
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(hex: "#1A1A2E"),
                Color(hex: "#16213E"),
                Color(hex: "#0F3460")
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

// MARK: - DeskHive Card
/// A frosted-glass style card container with rounded corners and subtle border.
struct DeskHiveCard<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .padding(20)
        .background(Color.white.opacity(0.08))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}

// MARK: - DeskHive Text Field
/// A styled text field with an optional leading SF Symbol icon.
/// Supports both plain and secure (password) input.
struct DeskHiveTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var icon: String = ""

    var body: some View {
        HStack(spacing: 12) {
            if !icon.isEmpty {
                Image(systemName: icon)
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 20)
            }

            if isSecure {
                SecureField(placeholder, text: $text)
                    .foregroundColor(.white)
                    .textInputAutocapitalization(.never)
            } else {
                TextField(placeholder, text: $text)
                    .foregroundColor(.white)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.06))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Primary Button
/// A gradient-filled action button with built-in loading spinner.
struct PrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: {
            if !isLoading { action() }
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(hex: "#E94560"),
                                Color(hex: "#C62A4F")
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 52)
                    .shadow(color: Color(hex: "#E94560").opacity(0.4), radius: 10, x: 0, y: 5)

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
        }
        .disabled(isLoading)
    }
}

// MARK: - Secondary Button
/// A text-only button styled with the accent colour.
struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(Color(hex: "#E94560"))
        }
    }
}

// MARK: - Error Banner
/// An inline error message with a red icon and tinted background.
struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(Color(hex: "#E94560"))
                .font(.system(size: 16))
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: "#E94560"))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#E94560").opacity(0.1))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(hex: "#E94560").opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Success Banner
/// An inline success message with a green icon and tinted background.
struct SuccessBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Color(hex: "#4ECDC4"))
                .font(.system(size: 16))
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: "#4ECDC4"))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#4ECDC4").opacity(0.1))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(hex: "#4ECDC4").opacity(0.3), lineWidth: 1)
        )
    }
}
