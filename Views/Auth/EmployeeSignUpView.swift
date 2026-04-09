//
//  EmployeeSignUpView.swift
//  DeskHive
//

import SwiftUI

struct EmployeeSignUpView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = AuthViewModel()

    @State private var fullName: String = ""
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
                                        gradient: Gradient(colors: [Color(hex: "#4ECDC4"), Color(hex: "#44A8B3")]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                                .shadow(color: Color(hex: "#4ECDC4").opacity(0.5), radius: 15, x: 0, y: 8)

                            Image(systemName: "person.badge.plus")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 36, height: 36)
                                .foregroundColor(.white)
                        }

                        Text("Employee Registration")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("Create your employee account")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }

                    // Form
                    DeskHiveCard {
                        VStack(spacing: 16) {
                            DeskHiveTextField(
                                placeholder: "Full name",
                                text: $fullName,
                                icon: "person"
                            )

                            DeskHiveTextField(
                                placeholder: "Email address",
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

                            PrimaryButton(title: "Create Employee Account", isLoading: viewModel.isLoading) {
                                Task {
                                    await viewModel.employeeSignUp(
                                        email: email,
                                        password: password,
                                        confirmPassword: confirmPassword,
                                        fullName: fullName,
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
    EmployeeSignUpView()
        .environmentObject(AppState())
}
