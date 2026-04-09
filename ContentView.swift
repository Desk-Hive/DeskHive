//
//  ContentView.swift
//  DeskHive
//

import SwiftUI

// ContentView is no longer used — DeskHiveApp.swift drives navigation via RootView.
struct ContentView: View {
    var body: some View {
        RootView()
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
