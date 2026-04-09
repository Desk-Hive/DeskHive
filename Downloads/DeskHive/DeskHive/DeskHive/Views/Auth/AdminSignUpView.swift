//
//  AdminSignUpView.swift
//  DeskHive
//

import SwiftUI

struct AdminSignUpView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = AuthViewModel()

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    Spacer().frame(height: 50)

                    // Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color(hex: "#F5A623"), Color(hex: "#E94560")]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                                .shadow(color: Color(hex: "#F5A623").opacity(0.5), radius: 15, x: 0, y: 8)

                            Image(systemName: "shield.checkered")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 36, height: 36)
                                .foregroundColor(.white)
                        }

                        Text("Admin Registration")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("Only one admin account is allowed")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }

                    // Warning badge
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(Color(hex: "#F5A623"))
                        Text("This option is only available once. The first admin controls all member access.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.leading)
                    }
                    .padding(14)
                    .background(Color(hex: "#F5A623").opacity(0.1))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#F5A623").opacity(0.4), lineWidth: 1))
                    .padding(.horizontal, 24)

                    // Form
                    DeskHiveCard {
                        VStack(spacing: 16) {
                            DeskHiveTextField(
                                placeholder: "Admin email address",
                                text: $email,
                                icon: "envelope"
                            )
                            .keyboardType(.emailAddress)

                            DeskHiveTextField(
                                placeholder: "Create password",
                                text: $password,
                                isSecure: true,
                                icon: "lock"
                            )

                            DeskHiveTextField(
                                placeholder: "Confirm password",
                                text: $confirmPassword,
                                isSecure: true,
                                icon: "lock.fill"
                            )

                            if let error = viewModel.errorMessage {
                                ErrorBanner(message: error)
                            }

                            if let success = viewModel.successMessage {
                                SuccessBanner(message: success)
                            }

                            PrimaryButton(title: "Create Admin Account", isLoading: viewModel.isLoading) {
                                Task {
                                    await viewModel.adminSignUp(
                                        email: email,
                                        password: password,
                                        confirmPassword: confirmPassword,
                                        appState: appState
                                    )
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 24)

                    SecondaryButton(title: "← Back to Login") {
                        appState.currentScreen = .login
                    }

                    Spacer().frame(height: 40)
                }
            }
        }
    }
}

#Preview {
    AdminSignUpView()
        .environmentObject(AppState())
}
