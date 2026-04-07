//
//  AddMemberSheet.swift
//  DeskHive
//

import SwiftUI

struct AddMemberSheet: View {
    @ObservedObject var adminVM: AdminViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var email: String = ""

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: "#1A1A2E"), Color(hex: "#0F3460")]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                // Handle
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)

                // Header
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#E94560").opacity(0.2))
                            .frame(width: 70, height: 70)
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 28))
                            .foregroundColor(Color(hex: "#E94560"))
                    }

                    Text("Add New Member")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("A secure password will be auto-generated\nand emailed to the member.")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                // Info notice
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundColor(Color(hex: "#4ECDC4"))
                        .font(.system(size: 16))
                    Text("Password is securely generated via Cloud Function and never stored in plain text.")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(14)
                .background(Color(hex: "#4ECDC4").opacity(0.1))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#4ECDC4").opacity(0.3), lineWidth: 1))
                .padding(.horizontal, 24)

                // Form
                VStack(spacing: 16) {
                    DeskHiveTextField(
                        placeholder: "Member's email address",
                        text: $email,
                        icon: "envelope"
                    )
                    .keyboardType(.emailAddress)

                    if let error = adminVM.errorMessage {
                        ErrorBanner(message: error)
                    }

                    if let success = adminVM.successMessage {
                        SuccessBanner(message: success)
                    }

                    PrimaryButton(title: "Create Member Account", isLoading: adminVM.isAddingMember) {
                        Task {
                            await adminVM.addMember(email: email)
                            if adminVM.successMessage != nil {
                                email = ""
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    dismiss()
                                }
                            }
                        }
                    }

                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .onAppear {
            adminVM.errorMessage = nil
            adminVM.successMessage = nil
        }
    }
}
