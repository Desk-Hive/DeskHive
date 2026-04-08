//
//  EmployeeProfileView.swift
//  DeskHive
//

import SwiftUI

struct EmployeeProfileView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm     = ProfileViewModel()
    @StateObject private var authVM = AuthViewModel()
    @StateObject private var checkInVM = CheckInViewModel()

    @State private var editMode        = false
    @State private var showChangePw    = false
    @State private var showSalary      = false
    @State private var showStatements  = false

    var user: DeskHiveUser? { appState.currentUser }

    private let accent   = Color(hex: "#4ECDC4")
    private let accent2  = Color(hex: "#A78BFA")
    private let red      = Color(hex: "#E94560")
    private let gold     = Color(hex: "#F5A623")

    var body: some View {
        guard user != nil else { return AnyView(EmptyView()) }
        return AnyView(profileContent)
    }

    private var profileContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                Spacer().frame(height: 4)

                // ── Avatar + name card ────────────────────────────────────
                avatarCard

                // ── Info grid ────────────────────────────────────────────
                infoGrid

                // ── Bio ──────────────────────────────────────────────────
                if !vm.bio.isEmpty || editMode {
                    bioCard
                }

                // ── Salary overview ───────────────────────────────────────
                salaryCard

                // ── Activity stats ────────────────────────────────────────
                statsRow

                // ── Actions ───────────────────────────────────────────────
                actionsCard

                Spacer().frame(height: 30)
            }
            .padding(.horizontal, 20)
        }
        .onAppear {
            if let u = user { vm.load(user: u) }
            Task {
                if let uid = appState.currentUser?.id {
                    await checkInVM.loadTodayStatus(uid: uid)
                    await checkInVM.loadRecentCheckIns(uid: uid)
                }
            }
        }
        .sheet(isPresented: $showChangePw) { changePwSheet }
        .sheet(isPresented: $showStatements) { statementsSheet }
    }

    // ====================================================================
    // MARK: - Avatar Card
    // ====================================================================
    private var avatarCard: some View {
        DeskHiveCard {
            VStack(spacing: 14) {
                // Avatar circle with initials
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [accent, Color(hex: "#44A8B3")],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 80, height: 80)
                    Text(initials)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(spacing: 4) {
                    if editMode {
                        TextField("Full Name", text: $vm.fullName)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .tint(accent)
                    } else {
                        Text(displayName)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }

                    HStack(spacing: 6) {
                        Text(user?.role.displayName ?? "")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(accent.opacity(0.12))
                            .cornerRadius(8)

                        if !vm.department.isEmpty {
                            Text(vm.department)
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }

                // Joined date
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.35))
                    Text("Joined \(formattedJoinDate)")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.35))
                }

                // Edit / Save buttons
                HStack(spacing: 10) {
                    if editMode {
                        Button(action: {
                            withAnimation { editMode = false }
                            vm.successMessage = nil
                            vm.errorMessage = nil
                        }) {
                            Text("Cancel")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                                .frame(maxWidth: .infinity).frame(height: 36)
                                .background(Color.white.opacity(0.07))
                                .cornerRadius(10)
                        }

                        Button(action: {
                            Task {
                                guard let uid = user?.id else { return }
                                await vm.saveProfile(uid: uid, appState: appState)
                                if vm.successMessage != nil { withAnimation { editMode = false } }
                            }
                        }) {
                            ZStack {
                                if vm.isSaving {
                                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.8)
                                } else {
                                    Text("Save Changes")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity).frame(height: 36)
                            .background(accent)
                            .cornerRadius(10)
                        }
                        .disabled(vm.isSaving)
                    } else {
                        Button(action: { withAnimation { editMode = true } }) {
                            Label("Edit Profile", systemImage: "pencil")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(accent)
                                .frame(maxWidth: .infinity).frame(height: 36)
                                .background(accent.opacity(0.1))
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(accent.opacity(0.3), lineWidth: 1))
                        }
                    }
                }

                if let msg = vm.successMessage {
                    Label(msg, systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(accent)
                }
                if let err = vm.errorMessage {
                    ErrorBanner(message: err)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
    }

    // ====================================================================
    // MARK: - Info Grid
    // ====================================================================
    private var infoGrid: some View {
        DeskHiveCard {
            VStack(alignment: .leading, spacing: 14) {
                Label("Personal Info", systemImage: "person.text.rectangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))

                Divider().background(Color.white.opacity(0.08))

                profileRow(icon: "envelope.fill",  label: "Email",      value: user?.email ?? "", editable: false, binding: .constant(""))
                profileRow(icon: "phone.fill",      label: "Phone",      value: vm.phone,   editable: editMode, binding: $vm.phone)
                profileRow(icon: "briefcase.fill",  label: "Job Title",  value: vm.jobTitle, editable: editMode, binding: $vm.jobTitle)
                profileRow(icon: "building.2.fill", label: "Department", value: vm.department, editable: editMode, binding: $vm.department)
            }
        }
    }

    // ====================================================================
    // MARK: - Bio Card
    // ====================================================================
    private var bioCard: some View {
        DeskHiveCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("About Me", systemImage: "quote.bubble.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))
                if editMode {
                    TextField("Write a short bio…", text: $vm.bio, axis: .vertical)
                        .lineLimit(3...6)
                        .foregroundColor(.white)
                        .tint(accent)
                        .font(.system(size: 13))
                } else {
                    Text(vm.bio.isEmpty ? "No bio yet." : vm.bio)
                        .font(.system(size: 13))
                        .foregroundColor(vm.bio.isEmpty ? .white.opacity(0.3) : .white.opacity(0.75))
                }
            }
        }
    }

    // ====================================================================
    // MARK: - Salary Overview Card
    // ====================================================================
    private var salaryCard: some View {
        DeskHiveCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Salary", systemImage: "banknote.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.55))
                    Spacer()
                    Button(action: { showStatements = true }) {
                        HStack(spacing: 4) {
                            Text("Statements")
                                .font(.system(size: 12, weight: .medium))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(gold)
                    }
                }

                Divider().background(Color.white.opacity(0.08))

                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Monthly Salary")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.4))
                        if showSalary {
                            Text(formattedSalary)
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(gold)
                        } else {
                            Text("••••••")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white.opacity(0.3))
                        }
                    }
                    Spacer()
                    Button(action: { withAnimation { showSalary.toggle() } }) {
                        Image(systemName: showSalary ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }

                // Latest statement status
                if let latest = vm.statements.first {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(latest.status == "Paid" ? accent : gold)
                            .frame(width: 7, height: 7)
                        Text("Last payment (\(latest.month)): \(latest.status)")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.55))
                    }
                } else {
                    Text("No salary statements yet.")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
        }
    }

    // ====================================================================
    // MARK: - Stats Row
    // ====================================================================
    private var statsRow: some View {
        HStack(spacing: 12) {
            miniStat(title: "Check-ins", value: "\(checkInVM.recentCheckIns.count)", icon: "checkmark.circle.fill", color: accent)
            miniStat(title: "Streak", value: streakCount(), icon: "flame.fill", color: gold)
            miniStat(title: "Salary Slips", value: "\(vm.statements.count)", icon: "doc.text.fill", color: accent2)
        }
    }

    // ====================================================================
    // MARK: - Actions Card
    // ====================================================================
    private var actionsCard: some View {
        DeskHiveCard {
            VStack(spacing: 0) {
                actionRow(icon: "lock.rotation",
                          title: "Change Password",
                          subtitle: "Update your account password",
                          color: accent2) {
                    showChangePw = true
                }

                Divider().background(Color.white.opacity(0.08))

                actionRow(icon: "doc.plaintext.fill",
                          title: "Salary Statements",
                          subtitle: "View your monthly pay history",
                          color: gold) {
                    showStatements = true
                }

                Divider().background(Color.white.opacity(0.08))

                actionRow(icon: "rectangle.portrait.and.arrow.right",
                          title: "Sign Out",
                          subtitle: "You will be logged out",
                          color: red) {
                    authVM.signOut(appState: appState)
                }
            }
        }
    }

    // ====================================================================
    // MARK: - Change Password Sheet
    // ====================================================================
    private var changePwSheet: some View {
        ZStack {
            AppBackground().ignoresSafeArea()
            ScrollView {
                VStack(spacing: 22) {
                    Text("Change Password")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.top, 40)

                    DeskHiveCard {
                        VStack(spacing: 16) {
                            pwField("Current Password", text: $vm.currentPassword)
                            Divider().background(Color.white.opacity(0.08))
                            pwField("New Password", text: $vm.newPassword)
                            Divider().background(Color.white.opacity(0.08))
                            pwField("Confirm New Password", text: $vm.confirmPassword)
                        }
                    }

                    if let err = vm.errorMessage   { ErrorBanner(message: err) }
                    if let msg = vm.successMessage {
                        Label(msg, systemImage: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(accent)
                    }

                    Button(action: {
                        Task { await vm.changePassword() }
                    }) {
                        ZStack {
                            if vm.isChangingPw {
                                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Update Password")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(accent2)
                        .cornerRadius(14)
                    }
                    .disabled(vm.isChangingPw)
                    .padding(.horizontal, 20)

                    Spacer()
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // ====================================================================
    // MARK: - Salary Statements Sheet
    // ====================================================================
    private var statementsSheet: some View {
        ZStack {
            AppBackground().ignoresSafeArea()
            VStack(spacing: 0) {
                Text("Salary Statements")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 40)
                    .padding(.bottom, 20)

                if vm.statements.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text").font(.system(size: 44)).foregroundColor(.white.opacity(0.18))
                        Text("No statements yet").font(.system(size: 15, weight: .semibold)).foregroundColor(.white.opacity(0.4))
                        Text("Your admin will upload salary slips here.").font(.system(size: 12)).foregroundColor(.white.opacity(0.3)).multilineTextAlignment(.center)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(vm.statements) { s in
                                statementRow(s)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
    }

    private func statementRow(_ s: SalaryStatement) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(gold.opacity(0.12)).frame(width: 42, height: 42)
                Image(systemName: "doc.text.fill").foregroundColor(gold).font(.system(size: 17))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(s.month).font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                if let paidOn = s.paidOn {
                    Text("Paid on \(shortDate(paidOn))").font(.system(size: 11)).foregroundColor(.white.opacity(0.4))
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(formatted(s.amount)).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(gold)
                Text(s.status)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(s.status == "Paid" ? accent : gold)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background((s.status == "Paid" ? accent : gold).opacity(0.12))
                    .cornerRadius(5)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    // ====================================================================
    // MARK: - Helpers / Sub-views
    // ====================================================================

    private func profileRow(icon: String, label: String, value: String, editable: Bool, binding: Binding<String>) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(accent.opacity(0.1)).frame(width: 32, height: 32)
                Image(systemName: icon).foregroundColor(accent).font(.system(size: 13))
            }
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 80, alignment: .leading)
            if editable {
                TextField(label, text: binding)
                    .foregroundColor(.white)
                    .tint(accent)
                    .font(.system(size: 13))
            } else {
                Text(value.isEmpty ? "—" : value)
                    .font(.system(size: 13))
                    .foregroundColor(value.isEmpty ? .white.opacity(0.2) : .white)
                    .lineLimit(1)
            }
            Spacer()
        }
    }

    private func actionRow(icon: String, title: String, subtitle: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(color.opacity(0.15)).frame(width: 38, height: 38)
                    Image(systemName: icon).foregroundColor(color).font(.system(size: 15))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                    Text(subtitle).font(.system(size: 11)).foregroundColor(.white.opacity(0.4))
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.white.opacity(0.2)).font(.system(size: 12))
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private func miniStat(title: String, value: String, icon: String, color: Color) -> some View {
        DeskHiveCard {
            VStack(spacing: 6) {
                Image(systemName: icon).foregroundColor(color).font(.system(size: 18))
                Text(value).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundColor(.white)
                Text(title).font(.system(size: 10)).foregroundColor(.white.opacity(0.4))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
    }

    private func pwField(_ placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill").foregroundColor(.white.opacity(0.3)).font(.system(size: 14))
            SecureField("", text: text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.3)))
                .foregroundColor(.white)
                .tint(accent)
        }
    }

    // MARK: - Computed helpers
    private var initials: String {
        let name = vm.fullName.isEmpty ? (user?.email ?? "") : vm.fullName
        return name.components(separatedBy: " ")
            .prefix(2).compactMap { $0.first.map(String.init) }
            .joined().uppercased()
    }

    private var displayName: String {
        vm.fullName.isEmpty ? user?.email.components(separatedBy: "@").first?.capitalized ?? "Employee" : vm.fullName
    }

    private var formattedJoinDate: String {
        guard let createdAt = user?.createdAt else { return "" }
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        return f.string(from: createdAt)
    }

    private var formattedSalary: String { formatted(vm.salary) }

    private func formatted(_ amount: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "BDT"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: amount)) ?? "৳\(Int(amount))"
    }

    private func shortDate(_ d: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium
        return f.string(from: d)
    }

    private func streakCount() -> String {
        let keys = checkInVM.recentCheckIns.map { $0.dateKey }.sorted(by: >)
        guard !keys.isEmpty else { return "0" }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        var streak = 0; var check = Date()
        for key in keys {
            if key == f.string(from: check) {
                streak += 1
                check = Calendar.current.date(byAdding: .day, value: -1, to: check)!
            } else { break }
        }
        return "\(streak)"
    }
}

#Preview {
    EmployeeProfileView().environmentObject(AppState())
}
