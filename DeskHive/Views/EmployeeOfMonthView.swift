//
//  EmployeeOfMonthView.swift
//  DeskHive
//

import SwiftUI

// MARK: - Shared spotlight card shown on ALL dashboards
struct EmployeeOfMonthCard: View {
    let award: EmployeeOfMonth
    var isHighlighted: Bool = false   // true when the viewer IS the winner

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [Color(hex: "#F5A623").opacity(0.18), Color(hex: "#E94560").opacity(0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .cornerRadius(20)

            // Decorative large trophy watermark
            Image(systemName: "trophy.fill")
                .font(.system(size: 100))
                .foregroundColor(Color(hex: "#F5A623").opacity(0.07))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 12)
                .padding(.bottom, -8)
                .clipped()

            VStack(alignment: .leading, spacing: 16) {

                // Header row
                HStack(spacing: 10) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: "#F5A623"))
                    Text("Employee of the Month")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(hex: "#F5A623"))
                    Spacer()
                    Text(award.month)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.45))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(20)
                }

                // Winner row
                HStack(spacing: 16) {
                    // Avatar with animated glow ring
                    ZStack {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color(hex: "#F5A623"), Color(hex: "#E94560")],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                            .frame(width: 66, height: 66)

                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#F5A623").opacity(0.3), Color(hex: "#E94560").opacity(0.2)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 58, height: 58)

                        Text(award.initials)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        if isHighlighted {
                            Text("🎉 That's you!")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(hex: "#4ECDC4"))
                        }
                        Text(award.displayName)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(award.employeeEmail)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.45))
                            .lineLimit(1)
                    }

                    Spacer()

                    // Crown badge
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#F5A623").opacity(0.15))
                            .frame(width: 44, height: 44)
                        Circle()
                            .stroke(Color(hex: "#F5A623").opacity(0.35), lineWidth: 1)
                            .frame(width: 44, height: 44)
                        Image(systemName: "crown.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "#F5A623"))
                    }
                }

                // Reason quote
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "quote.opening")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#F5A623").opacity(0.6))
                        .padding(.top, 2)
                    Text(award.reason)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(3)
                }
                .padding(12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "#F5A623").opacity(0.15), lineWidth: 1)
                )
            }
            .padding(20)
        }
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: "#F5A623").opacity(0.5), Color(hex: "#E94560").opacity(0.3)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: Color(hex: "#F5A623").opacity(0.15), radius: 16, x: 0, y: 6)
    }
}

// MARK: - Empty state card (no winner yet this month)
struct EmployeeOfMonthEmptyCard: View {
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#F5A623").opacity(0.1))
                    .frame(width: 52, height: 52)
                Circle()
                    .stroke(Color(hex: "#F5A623").opacity(0.25), lineWidth: 1)
                    .frame(width: 52, height: 52)
                Image(systemName: "trophy")
                    .font(.system(size: 22))
                    .foregroundColor(Color(hex: "#F5A623").opacity(0.6))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Employee of the Month")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Not selected yet for \(EmployeeOfMonth.monthString())")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.45))
            }
            Spacer()
        }
        .padding(16)
        .background(Color(hex: "#F5A623").opacity(0.06))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "#F5A623").opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Admin picker sheet
struct AdminEmployeeOfMonthView: View {
    @ObservedObject var vm: EmployeeOfMonthViewModel
    let members: [DeskHiveUser]
    let adminEmail: String
    @Environment(\.dismiss) var dismiss

    @State private var selectedEmployee: DeskHiveUser? = nil
    @State private var reason = ""
    @State private var showConfirm = false
    @State private var searchText = ""

    private var employees: [DeskHiveUser] {
        let filtered = members.filter { $0.role == .employee || $0.role == .projectLead }
        if searchText.isEmpty { return filtered }
        return filtered.filter { $0.email.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Employee of the Month")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text(EmployeeOfMonth.monthString())
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.45))
                    }
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 56)
                .padding(.bottom, 20)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        // Current winner banner
                        if let current = vm.current {
                            VStack(alignment: .leading, spacing: 10) {
                                sectionLabel("Current Winner")
                                EmployeeOfMonthCard(award: current)

                                Button(action: {
                                    Task { await vm.clearAward() }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "trash")
                                        Text("Clear Award")
                                    }
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color(hex: "#E94560"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color(hex: "#E94560").opacity(0.08))
                                    .cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(hex: "#E94560").opacity(0.25), lineWidth: 1))
                                }
                            }
                        }

                        // Messages
                        if let err = vm.errorMessage {
                            ErrorBanner(message: err)
                        }
                        if let suc = vm.successMessage {
                            SuccessBanner(message: suc)
                        }

                        // Pick new winner
                        sectionLabel(vm.current == nil ? "Select Winner" : "Change Winner")

                        // Search bar
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.white.opacity(0.4))
                            TextField("Search employees…", text: $searchText)
                                .foregroundColor(.white)
                                .tint(.white)
                                .autocorrectionDisabled()
                                .autocapitalization(.none)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1))

                        // Employee list
                        if employees.isEmpty {
                            Text("No employees found.")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.4))
                                .padding(.vertical, 20)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(employees) { emp in
                                    employeeRow(emp)
                                }
                            }
                        }

                        // Reason + Confirm
                        if let selected = selectedEmployee {
                            VStack(alignment: .leading, spacing: 12) {
                                sectionLabel("Why \(selected.email.components(separatedBy:"@").first?.capitalized ?? "them")?")

                                ZStack(alignment: .topLeading) {
                                    if reason.isEmpty {
                                        Text("Write a short reason for this award…")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white.opacity(0.3))
                                            .padding(.horizontal, 14)
                                            .padding(.top, 14)
                                    }
                                    TextEditor(text: $reason)
                                        .foregroundColor(.white)
                                        .tint(Color(hex: "#F5A623"))
                                        .scrollContentBackground(.hidden)
                                        .font(.system(size: 14))
                                        .padding(10)
                                        .frame(minHeight: 100)
                                }
                                .background(Color.white.opacity(0.07))
                                .cornerRadius(14)
                                .overlay(RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color(hex: "#F5A623").opacity(0.3), lineWidth: 1))

                                Button(action: { showConfirm = true }) {
                                    ZStack {
                                        LinearGradient(
                                            colors: [Color(hex: "#F5A623"), Color(hex: "#E08C00")],
                                            startPoint: .leading, endPoint: .trailing
                                        )
                                        .cornerRadius(14)
                                        .shadow(color: Color(hex: "#F5A623").opacity(0.4), radius: 10, x: 0, y: 4)

                                        if vm.isSaving {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        } else {
                                            HStack(spacing: 8) {
                                                Image(systemName: "trophy.fill")
                                                Text("Award Employee of the Month")
                                                    .font(.system(size: 15, weight: .bold))
                                            }
                                            .foregroundColor(.white)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                }
                                .disabled(vm.isSaving || reason.trimmingCharacters(in: .whitespaces).isEmpty)
                                .opacity(reason.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                            }
                        }

                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .confirmationDialog(
            "Award \(selectedEmployee?.email.components(separatedBy:"@").first?.capitalized ?? "") as Employee of the Month?",
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button("Award 🏆", role: .none) {
                guard let emp = selectedEmployee else { return }
                Task {
                    await vm.saveAward(employee: emp, reason: reason, adminEmail: adminEmail)
                    if vm.errorMessage == nil {
                        reason = ""
                        selectedEmployee = nil
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func employeeRow(_ emp: DeskHiveUser) -> some View {
        let isSelected = selectedEmployee?.id == emp.id
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedEmployee = isSelected ? nil : emp
                vm.errorMessage = nil
                vm.successMessage = nil
            }
        }) {
            HStack(spacing: 14) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(isSelected
                              ? Color(hex: "#F5A623").opacity(0.25)
                              : Color.white.opacity(0.08))
                        .frame(width: 46, height: 46)
                    if isSelected {
                        Circle()
                            .stroke(Color(hex: "#F5A623"), lineWidth: 2)
                            .frame(width: 46, height: 46)
                    }
                    Text(String(emp.email.prefix(1)).uppercased())
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(isSelected ? Color(hex: "#F5A623") : .white.opacity(0.7))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(emp.email.components(separatedBy: "@").first?.capitalized ?? emp.email)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Text(emp.email)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                        .lineLimit(1)
                }

                Spacer()

                // Role badge + checkmark
                HStack(spacing: 8) {
                    Text(emp.role.displayName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(emp.role == .projectLead ? Color(hex: "#F5A623") : Color(hex: "#4ECDC4"))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background((emp.role == .projectLead ? Color(hex: "#F5A623") : Color(hex: "#4ECDC4")).opacity(0.12))
                        .cornerRadius(6)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color(hex: "#F5A623"))
                            .font(.system(size: 18))
                    }
                }
            }
            .padding(14)
            .background(isSelected
                        ? Color(hex: "#F5A623").opacity(0.08)
                        : Color.white.opacity(0.06))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected
                            ? Color(hex: "#F5A623").opacity(0.5)
                            : Color.white.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    private func sectionLabel(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
            Spacer()
        }
    }
}

// MARK: - Compact history row (used in admin view)
struct EmployeeOfMonthHistoryRow: View {
    let award: EmployeeOfMonth
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#F5A623").opacity(0.12))
                    .frame(width: 40, height: 40)
                Text(award.initials)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(hex: "#F5A623"))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(award.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text(award.month)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
            Spacer()
            Image(systemName: "trophy.fill")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#F5A623").opacity(0.5))
        }
        .padding(.vertical, 6)
    }
}
