//
//  CheckInView.swift
//  DeskHive
//

import SwiftUI

struct CheckInView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: CheckInViewModel
    @Environment(\.dismiss) var dismiss

    @State private var selectedMood: CheckInMood? = nil
    @State private var note: String = ""
    @State private var submitted: Bool = false

    var uid: String { appState.currentUser?.id ?? "" }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    Spacer().frame(height: 20)

                    // Header
                    VStack(spacing: 10) {
                        Text("Daily Check-in")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text(formattedToday())
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.white.opacity(0.5))
                    }

                    if submitted || viewModel.hasCheckedInToday {
                        checkedInView
                    } else {
                        checkInForm
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
    }

    // MARK: - Check-in Form
    private var checkInForm: some View {
        VStack(spacing: 24) {

            // Mood selector
            DeskHiveCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("How are you feeling today?")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    // 5 mood buttons in a grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                        ForEach(CheckInMood.allCases, id: \.self) { mood in
                            MoodButton(
                                mood: mood,
                                isSelected: selectedMood == mood
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    selectedMood = mood
                                }
                            }
                        }
                    }
                }
            }

            // Selected mood label
            if let mood = selectedMood {
                HStack(spacing: 8) {
                    Text(mood.emoji)
                        .font(.system(size: 20))
                    Text("Feeling \(mood.label)")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(hex: mood.color))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color(hex: mood.color).opacity(0.1))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: mood.color).opacity(0.3), lineWidth: 1))
                .transition(.scale.combined(with: .opacity))
            }

            // Optional note
            DeskHiveCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "note.text")
                            .foregroundColor(.white.opacity(0.5))
                            .font(.system(size: 14))
                        Text("Add a note (optional & anonymous)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    TextField("", text: $note, prompt: Text("Share anything on your mind…").foregroundColor(.white.opacity(0.3)))
                        .foregroundColor(.white)
                        .tint(Color(hex: "#4ECDC4"))
                        .frame(minHeight: 60, alignment: .topLeading)
                        .multilineTextAlignment(.leading)
                }
            }

            // Error / success
            if let err = viewModel.errorMessage {
                ErrorBanner(message: err)
            }

            // Submit button
            Button(action: {
                guard let mood = selectedMood else { return }
                Task {
                    await viewModel.submitCheckIn(uid: uid, mood: mood, note: note)
                    if viewModel.successMessage != nil {
                        withAnimation { submitted = true }
                    }
                }
            }) {
                ZStack {
                    LinearGradient(
                        gradient: Gradient(colors: [Color(hex: "#4ECDC4"), Color(hex: "#44A8B3")]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .cornerRadius(14)
                    .shadow(color: Color(hex: "#4ECDC4").opacity(0.4), radius: 10, x: 0, y: 5)

                    if viewModel.isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Submit Check-in")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
            }
            .disabled(selectedMood == nil || viewModel.isSubmitting)
            .opacity(selectedMood == nil ? 0.5 : 1.0)
        }
    }

    // MARK: - Already Checked In View
    private var checkedInView: some View {
        VStack(spacing: 24) {
            // Success ring
            ZStack {
                Circle()
                    .stroke(Color(hex: "#4ECDC4").opacity(0.2), lineWidth: 12)
                    .frame(width: 120, height: 120)
                Circle()
                    .trim(from: 0, to: 1)
                    .stroke(
                        LinearGradient(colors: [Color(hex: "#4ECDC4"), Color(hex: "#44A8B3")],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                if let mood = viewModel.todayMood {
                    Text(mood.emoji)
                        .font(.system(size: 48))
                }
            }
            .padding(.top, 20)

            VStack(spacing: 8) {
                Text("You've checked in today!")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                if let mood = viewModel.todayMood {
                    Text("Feeling \(mood.label) — \(mood.emoji)")
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: mood.color))
                }

                Text("Come back tomorrow for your next check-in.")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }

            // Recent history
            if !viewModel.recentCheckIns.isEmpty {
                DeskHiveCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Last 7 Days")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))

                        ForEach(viewModel.recentCheckIns) { checkIn in
                            HStack {
                                Text(checkIn.mood.emoji)
                                    .font(.system(size: 20))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(checkIn.mood.label)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white)
                                    Text(checkIn.dateKey)
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.4))
                                }
                                Spacer()
                                if !checkIn.note.isEmpty {
                                    Image(systemName: "note.text")
                                        .foregroundColor(.white.opacity(0.3))
                                        .font(.system(size: 12))
                                }
                            }
                            if checkIn.id != viewModel.recentCheckIns.last?.id {
                                Divider().background(Color.white.opacity(0.08))
                            }
                        }
                    }
                }
            }

            Button(action: { dismiss() }) {
                Text("Close")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(hex: "#4ECDC4"))
                    .padding(.vertical, 10)
            }
        }
    }

    // MARK: - Helper
    private func formattedToday() -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d, yyyy"
        return f.string(from: Date())
    }
}

// MARK: - Mood Button
struct MoodButton: View {
    let mood: CheckInMood
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(mood.emoji)
                    .font(.system(size: 28))
                    .scaleEffect(isSelected ? 1.2 : 1.0)

                Text(mood.label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(isSelected ? Color(hex: mood.color) : .white.opacity(0.4))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Color(hex: mood.color).opacity(0.15) : Color.clear)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color(hex: mood.color).opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        }
    }
}

#Preview {
    CheckInView(viewModel: CheckInViewModel())
        .environmentObject(AppState())
}
