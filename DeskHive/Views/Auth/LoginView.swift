//
//  LoginView.swift
//  DeskHive
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = AuthViewModel()

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var selectedRole: LoginRole = .employee

    enum LoginRole: String, CaseIterable {
        case employee = "Employee"
        case admin    = "Admin"

        var icon: String {
            switch self {
            case .employee: return "person.fill"
            case .admin:    return "shield.checkered"
            }
        }
        var accentColor: Color {
            switch self {
            case .employee: return Color(hex: "#4ECDC4")
            case .admin:    return Color(hex: "#F5A623")
            }
        }
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    Spacer().frame(height: 60)

                    // Logo & Title
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color(hex: "#E94560"), Color(hex: "#F5A623")]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                                .shadow(color: Color(hex: "#E94560").opacity(0.5), radius: 15, x: 0, y: 8)

                            Image(systemName: "building.2.crop.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40, height: 40)
                                .foregroundColor(.white)
                        }

                        Text("DeskHive")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("Sign in to your workspace")
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    // Role Selector
                    HStack(spacing: 0) {
                        ForEach(LoginRole.allCases, id: \.self) { role in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedRole = role
                                    viewModel.errorMessage = nil
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: role.icon)
                                        .font(.system(size: 13))
                                    Text(role.rawValue)
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundColor(selectedRole == role ? .white : .white.opacity(0.4))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    selectedRole == role
                                    ? role.accentColor.opacity(0.25)
                                    : Color.clear
                                )
                                .overlay(
                                    selectedRole == role
                                    ? RoundedRectangle(cornerRadius: 12)
                                        .stroke(role.accentColor.opacity(0.6), lineWidth: 1)
                                    : nil
                                )
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(4)
                    .background(Color.white.opacity(0.07))
                    .cornerRadius(14)
                    .padding(.horizontal, 24)

                    // Form Card
                    DeskHiveCard {
                        VStack(spacing: 16) {
                            DeskHiveTextField(
                                placeholder: "\(selectedRole.rawValue) email address",
                                text: $email,
                                icon: "envelope"
                            )
                            .keyboardType(.emailAddress)

                            DeskHiveTextField(
                                placeholder: "Password",
                                text: $password,
                                isSecure: true,
                                icon: "lock"
                            )

                            if let error = viewModel.errorMessage {
                                ErrorBanner(message: error)
                            }

                            PrimaryButton(title: "Sign In as \(selectedRole.rawValue)", isLoading: viewModel.isLoading) {
                                Task {
                                    await viewModel.login(email: email, password: password, appState: appState)
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 24)

                    // Register links
                    VStack(spacing: 12) {
                        Text("Don't have an account?")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.5))

                        HStack(spacing: 16) {
                            // Employee Register
                            Button(action: { appState.currentScreen = .employeeSignUp }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "person.badge.plus")
                                    Text("Register as Employee")
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "#4ECDC4"))
                                .padding(.vertical, 10)
                                .padding(.horizontal, 16)
                                .background(Color(hex: "#4ECDC4").opacity(0.1))
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#4ECDC4").opacity(0.3), lineWidth: 1))
                            }

                            // Admin Register
                            Button(action: { appState.currentScreen = .adminSignUp }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "shield.checkered")
                                    Text("Register as Admin")
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "#F5A623"))
                                .padding(.vertical, 10)
                                .padding(.horizontal, 16)
                                .background(Color(hex: "#F5A623").opacity(0.1))
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#F5A623").opacity(0.3), lineWidth: 1))
                            }
                        }
                    }

                    Spacer().frame(height: 40)
                }
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AppState())
}
