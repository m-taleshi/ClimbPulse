//
//  ContentView.swift
//  ClimbPulse
//
//  Main content view - entry point for the app UI.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var measurementStore = MeasurementStore()
    @State private var selectedTab = 1
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label("History", systemImage: "clock.arrow.circlepath")
            }
            .tag(0)
            .environmentObject(measurementStore)
            
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Image(systemName: "plus.circle.fill")
                Text("Record")
            }
            .tag(1)
            .environmentObject(measurementStore)
            
            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle")
            }
            .tag(2)
        }
    }
}

#Preview {
    ContentView()
}
