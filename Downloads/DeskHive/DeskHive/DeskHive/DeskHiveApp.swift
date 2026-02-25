//
//  DeskHiveApp.swift
//  DeskHive
//
//  Created by sum on 24/2/26.
//

import SwiftUI
import FirebaseCore

@main
struct DeskHiveApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var authVM = AuthViewModel()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .task {
                    // Wait for splash animation to complete
                    try? await Task.sleep(nanoseconds: 3_200_000_000)
                    // Then decide where to navigate based on session state
                    await authVM.restoreSession(appState: appState)
                }
        }
    }
}

// MARK: - Root navigation switch
struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            switch appState.currentScreen {
            case .splash:
                SplashView()
                    .transition(.opacity)
            case .login:
                LoginView()
                    .transition(.opacity)
            case .adminSignUp:
                AdminSignUpView()
                    .transition(.opacity)
            case .adminDashboard:
                AdminDashboardView()
                    .transition(.opacity)
            case .memberDashboard:
                MemberDashboardView()
                    .transition(.opacity)
            case .projectLeadDashboard:
                ProjectLeadDashboardView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: appState.currentScreen)
    }
}
