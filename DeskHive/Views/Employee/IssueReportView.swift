//
//  IssueReportView.swift
//  DeskHive
//

import SwiftUI

struct IssueReportView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: IssueReportViewModel
    @Environment(\.dismiss) var dismiss

    @State private var selectedCategory: IssueCategory = .workplace
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var showSuccess: Bool = false

    var body: some View {
        ZStack {
            AppBackground().ignoresSafeArea()

            if showSuccess, let caseID = viewModel.submittedCaseID {
                successView(caseID: caseID)
            } else {
                formView
            }
        }
    }

    // MARK: - Form
    private var formView: some View {
        VStack(spacing: 0) {

            // ── Top bar ──────────────────────────────────────────────────
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                Spacer()
                Text("Report Issue")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                // invisible balance
                Color.clear.frame(width: 34, height: 34)
            }
            .padding(.horizontal, 20)
            .padding(.top, 56)
            .padding(.bottom, 16)

            // ── Scrollable body ──────────────────────────────────────────
            ScrollView(showsIndicators: true) {
                VStack(spacing: 20) {

                    // Header
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#E94560").opacity(0.15))
                                .frame(width: 64, height: 64)
                            Image(systemName: "exclamationmark.shield.fill")
                                .font(.system(size: 28))
                                .foregroundColor(Color(hex: "#E94560"))
                        }
                        Text("Anonymous Report")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Your identity is never stored")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.top, 4)

                    // Category picker
                    DeskHiveCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Label("Category", systemImage: "tag.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.6))

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(IssueCategory.allCases, id: \.self) { cat in
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3)) { selectedCategory = cat }
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: cat.icon).font(.system(size: 12))
                                            Text(cat.label).font(.system(size: 12, weight: .medium))
                                        }
                                        .foregroundColor(selectedCategory == cat
                                                         ? Color(hex: cat.color) : .white.opacity(0.45))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(selectedCategory == cat
                                                    ? Color(hex: cat.color).opacity(0.15)
                                                    : Color.white.opacity(0.05))
                                        .cornerRadius(10)
                                        .overlay(RoundedRectangle(cornerRadius: 10)
                                            .stroke(selectedCategory == cat
                                                    ? Color(hex: cat.color).opacity(0.45)
                                                    : Color.white.opacity(0.08), lineWidth: 1))
                                    }
                                }
                            }
                        }
                    }

                    // Title field
                    DeskHiveCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Issue Title", systemImage: "pencil")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.6))
                            TextField("", text: $title,
                                      prompt: Text("Brief title of the issue…")
                                        .foregroundColor(.white.opacity(0.3)))
                                .foregroundColor(.white)
                                .tint(Color(hex: "#E94560"))
                        }
                    }

                    // Description field
                    DeskHiveCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Description", systemImage: "text.alignleft")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.6))
                            TextField("", text: $description,
                                      prompt: Text("Describe the issue in detail…")
                                        .foregroundColor(.white.opacity(0.3)),
                                      axis: .vertical)
                                .foregroundColor(.white)
                                .tint(Color(hex: "#E94560"))
                                .lineLimit(5...10)
                        }
                    }

                    // Privacy notice
                    HStack(spacing: 10) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(Color(hex: "#A78BFA"))
                            .font(.system(size: 16))
                        Text("A unique Case ID will be generated so you can track your report — no personal information is stored.")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.55))
                            .multilineTextAlignment(.leading)
                    }
                    .padding(14)
                    .background(Color(hex: "#A78BFA").opacity(0.08))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "#A78BFA").opacity(0.2), lineWidth: 1))

                    // Error banner
                    if let err = viewModel.submitError {
                        ErrorBanner(message: err)
                    }

                    Spacer().frame(height: 8)
                }
                .padding(.horizontal, 20)
            }

            // ── Submit button — always pinned at bottom ──────────────────
            VStack(spacing: 0) {
                Divider().background(Color.white.opacity(0.08))

                Button(action: {
                    Task {
                        await viewModel.submitIssue(
                            category: selectedCategory,
                            title: title,
                            description: description
                        )
                        if viewModel.submittedCaseID != nil {
                            withAnimation { showSuccess = true }
                        }
                    }
                }) {
                    ZStack {
                        LinearGradient(
                            gradient: Gradient(colors: [Color(hex: "#E94560"), Color(hex: "#C73652")]),
                            startPoint: .leading, endPoint: .trailing
                        )
                        .cornerRadius(14)
                        .shadow(color: Color(hex: "#E94560").opacity(0.35), radius: 8, x: 0, y: 4)

                        if viewModel.isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "paperplane.fill")
                                Text("Submit Anonymously")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 32)
                .disabled(viewModel.isSubmitting
                          || title.trimmingCharacters(in: .whitespaces).isEmpty
                          || description.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(title.trimmingCharacters(in: .whitespaces).isEmpty
                         || description.trimmingCharacters(in: .whitespaces).isEmpty ? 0.45 : 1.0)
            }
            .background(Color(hex: "#1A1A2E").opacity(0.95))
        }
    }

    // MARK: - Success screen
    private func successView(caseID: String) -> some View {
        VStack(spacing: 0) {

            // Top bar
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .padding(.trailing, 20)
            }
            .padding(.top, 56)
            .padding(.bottom, 8)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {

                    Spacer().frame(height: 24)

                    // Check icon
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#4ECDC4").opacity(0.15))
                            .frame(width: 100, height: 100)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 52))
                            .foregroundColor(Color(hex: "#4ECDC4"))
                    }

                    VStack(spacing: 8) {
                        Text("Issue Reported!")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Your report has been submitted anonymously.")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }

                    // Case ID box
                    DeskHiveCard {
                        VStack(spacing: 14) {
                            Text("Your Case ID")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))

                            Text(caseID)
                                .font(.system(size: 26, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(hex: "#4ECDC4"))
                                .tracking(4)

                            Text("Save this ID to track your issue status")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.5))
                                .multilineTextAlignment(.center)

                            Button(action: { UIPasteboard.general.string = caseID }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "doc.on.doc")
                                    Text("Copy Case ID")
                                }
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(hex: "#4ECDC4"))
                                .padding(.vertical, 9)
                                .padding(.horizontal, 20)
                                .background(Color(hex: "#4ECDC4").opacity(0.1))
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(hex: "#4ECDC4").opacity(0.3), lineWidth: 1))
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }

                    Button(action: { dismiss() }) {
                        Text("Done")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1))
                    }

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

#Preview {
    IssueReportView(viewModel: IssueReportViewModel())
        .environmentObject(AppState())
}
