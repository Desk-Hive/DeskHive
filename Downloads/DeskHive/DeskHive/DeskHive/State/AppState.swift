//
//  AppState.swift
//  DeskHive
//

import Foundation
import Combine

enum AppScreen: Equatable {
    case splash
    case login
    case adminSignUp
    case adminDashboard
    case memberDashboard
    case projectLeadDashboard
}

class AppState: ObservableObject {
    @Published var currentScreen: AppScreen = .splash
    @Published var currentUser: DeskHiveUser?

    func navigateAfterLogin(user: DeskHiveUser) {
        currentUser = user
        switch user.role {
        case .admin:       currentScreen = .adminDashboard
        case .member:      currentScreen = .memberDashboard
        case .projectLead: currentScreen = .projectLeadDashboard
        }
    }

    func signOut() {
        currentUser = nil
        currentScreen = .login
    }
}
