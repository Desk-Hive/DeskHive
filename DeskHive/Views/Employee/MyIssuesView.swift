//
//  MyIssuesView.swift
//  DeskHive
//

import SwiftUI

struct MyIssuesView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: IssueReportViewModel
    @Environment(\.dismiss) var dismiss

    @State private var caseIDInput: String = ""
    @State private var showReport: Bool = false

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: 20)

                    // Header
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#A78BFA").opacity(0.15))
                                .frame(width: 64, height: 64)
                            Image(systemName: "magnifyingglass.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(Color(hex: "#A78BFA"))
                        }
                        Text("Track Your Issue")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Enter your Case ID to check the status")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.5))
                    }

                    // Case ID input
                    DeskHiveCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Case ID")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))

                            HStack(spacing: 10) {
                                Image(systemName: "number")
                                    .foregroundColor(.white.opacity(0.4))
                                TextField("", text: $caseIDInput, prompt: Text("e.g. ISS-A3F9B2").foregroundColor(.white.opacity(0.3)))
                                    .foregroundColor(.white)
                                    .tint(Color(hex: "#A78BFA"))
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.characters)
                                if !caseIDInput.isEmpty {
                                    Button(action: { caseIDInput = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.white.opacity(0.3))
                                    }
                                }
                            }
                            .padding(14)
                            .background(Color.white.opacity(0.07))
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#A78BFA").opacity(0.3), lineWidth: 1))
                        }
                    }

                    // Lookup error
                    if let err = viewModel.lookupError {
                        ErrorBanner(message: err)
                    }

                    // Lookup button
                    Button(action: {
                        Task { await viewModel.lookupIssue(caseID: caseIDInput) }
                    }) {
                        ZStack {
                            LinearGradient(
                                gradient: Gradient(colors: [Color(hex: "#A78BFA"), Color(hex: "#7C3AED")]),
                                startPoint: .leading, endPoint: .trailing
                            )
                            .cornerRadius(14)
                            .shadow(color: Color(hex: "#A78BFA").opacity(0.4), radius: 10, x: 0, y: 5)

                            if viewModel.isLooking {
                                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                HStack(spacing: 8) {
                                    Image(systemName: "magnifyingglass")
                                    Text("Look Up Issue")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                    }
                    .disabled(caseIDInput.isEmpty || viewModel.isLooking)
                    .opacity(caseIDInput.isEmpty ? 0.5 : 1.0)

                    // Result card
                    if let issue = viewModel.lookedUpIssue {
                        issueResultCard(issue)
                    }

                    Divider().background(Color.white.opacity(0.08))

                    // New report button
                    Button(action: { showReport = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(Color(hex: "#E94560"))
                            Text("Submit a New Issue")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Color(hex: "#E94560"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(hex: "#E94560").opacity(0.08))
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#E94560").opacity(0.25), lineWidth: 1))
                    }

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 24)
            }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 24)
                    .padding(.top, 56)
                }
                Spacer()
            }
        }
        .sheet(isPresented: $showReport) {
            IssueReportView(viewModel: viewModel)
                .environmentObject(appState)
        }
    }

    // MARK: - Issue result card
    private func issueResultCard(_ issue: IssueReport) -> some View {
        DeskHiveCard {
            VStack(alignment: .leading, spacing: 16) {

                // Case ID + status badge
                HStack {
                    Text(issue.id)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                    // Status badge
                    HStack(spacing: 5) {
                        Image(systemName: issue.status.icon)
                            .font(.system(size: 11))
                        Text(issue.status.label)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(Color(hex: issue.status.color))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(hex: issue.status.color).opacity(0.15))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: issue.status.color).opacity(0.4), lineWidth: 1))
                }

                Divider().background(Color.white.opacity(0.1))

                // Category
                HStack(spacing: 6) {
                    Image(systemName: issue.category.icon)
                        .foregroundColor(Color(hex: issue.category.color))
                        .font(.system(size: 12))
                    Text(issue.category.label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: issue.category.color))
                }

                // Title
                Text(issue.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                // Description
                Text(issue.description)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(4)

                // Date
                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.3))
                    Text(formattedDate(issue.createdAt))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                }

                // Admin response (if any)
                if !issue.adminResponse.isEmpty {
                    Divider().background(Color.white.opacity(0.1))
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "bubble.left.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#4ECDC4"))
                            Text("HR/Admin Response")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: "#4ECDC4"))
                        }
                        Text(issue.adminResponse)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(12)
                            .background(Color(hex: "#4ECDC4").opacity(0.08))
                            .cornerRadius(10)
                    }
                }
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}

#Preview {
    MyIssuesView(viewModel: IssueReportViewModel())
        .environmentObject(AppState())
}
