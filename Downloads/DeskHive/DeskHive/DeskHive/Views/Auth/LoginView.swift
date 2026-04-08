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

                    // Form Card
                    DeskHiveCard {
                        VStack(spacing: 16) {
                            DeskHiveTextField(
                                placeholder: "Email address",
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

                            PrimaryButton(title: "Sign In", isLoading: viewModel.isLoading) {
                                Task {
                                    await viewModel.login(email: email, password: password, appState: appState)
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 24)

                    // Admin sign-up link
                    VStack(spacing: 6) {
                        Text("First time setup?")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.5))

                        SecondaryButton(title: "Register as Admin") {
                            appState.currentScreen = .adminSignUp
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
