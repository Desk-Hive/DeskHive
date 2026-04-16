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

            VStack(spacing: 0) {
                // Top bar back button
                HStack {
                    Button(action: { appState.currentScreen = .login }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 56)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        Spacer().frame(height: 16)

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

                            Text("Create an admin account to manage your workspace")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                        }

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
                                        // Account creation + role document provisioning are handled in the auth view model.
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

                        Spacer().frame(height: 40)
                    } // inner VStack
                } // ScrollView
            } // outer VStack
        }
    }
}

#Preview {
    AdminSignUpView()
        .environmentObject(AppState())
}
