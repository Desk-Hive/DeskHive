//
//  SharedComponents.swift
//  DeskHive
//  Shared UI components used across views.
//

import SwiftUI

// MARK: - Custom Text Field
struct DeskHiveTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 20)
            }

            if isSecure {
                SecureField(placeholder, text: $text)
                    .foregroundColor(.white)
                    .tint(.white)
                    .autocorrectionDisabled()
            } else {
                TextField(placeholder, text: $text)
                    .foregroundColor(.white)
                    .tint(.white)
                    .autocorrectionDisabled()
                    .autocapitalization(.none)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.1))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Primary Button
struct PrimaryButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color(hex: "#E94560"), Color(hex: "#C73652")]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .cornerRadius(14)
                .shadow(color: Color(hex: "#E94560").opacity(0.5), radius: 10, x: 0, y: 5)

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.1)
                } else {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.8 : 1.0)
    }
}

// MARK: - Secondary Button
struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(Color(hex: "#E94560"))
                .padding(.vertical, 10)
        }
    }
}

// MARK: - Error Banner
struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.red.opacity(0.2))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.4), lineWidth: 1))
    }
}

// MARK: - Success Banner
struct SuccessBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.green.opacity(0.2))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.green.opacity(0.4), lineWidth: 1))
    }
}

// MARK: - App Background
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

// MARK: - Card
struct DeskHiveCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .background(Color.white.opacity(0.08))
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Role Banner Card
struct RoleBannerCard: View {
    let role: UserRole

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: roleIcon)
                .font(.system(size: 24))
                .foregroundColor(roleColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("Your Role")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                Text(role.displayName)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            Spacer()
            ZStack {
                Circle().fill(roleColor.opacity(0.15)).frame(width: 36, height: 36)
                Circle().stroke(roleColor.opacity(0.3), lineWidth: 1).frame(width: 36, height: 36)
                Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundColor(roleColor)
            }
        }
        .padding(16)
        .background(roleColor.opacity(0.08))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(roleColor.opacity(0.3), lineWidth: 1))
    }

    var roleColor: Color {
        switch role {
        case .admin:       return Color(hex: "#E94560")
        case .projectLead: return Color(hex: "#F5A623")
        case .employee:    return Color(hex: "#4ECDC4")
        }
    }

    var roleIcon: String {
        switch role {
        case .admin:       return "shield.checkered"
        case .projectLead: return "star.fill"
        case .employee:    return "person.fill"
        }
    }
}

// MARK: - Info Row
struct InfoRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 20)
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
        }
    }
}
