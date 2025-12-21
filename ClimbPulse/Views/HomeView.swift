//
//  HomeView.swift
//  ClimbPulse
//
//  Main home screen with start measurement button and navigation to history.
//

import SwiftUI

struct HomeView: View {
    @StateObject private var cameraManager = CameraManager()
    @EnvironmentObject var measurementStore: MeasurementStore
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var showRecording = false
    @State private var showResults = false
    @State private var completedMeasurement: Measurement?
    
    // JYU-inspired palette
    private let primaryBlue = Color(red: 0.0, green: 0.34, blue: 0.65)      // #0056A5
    private let darkBlue = Color(red: 0.02, green: 0.16, blue: 0.32)       // #042948
    private let accentOrange = Color(red: 1.0, green: 0.51, blue: 0.0)     // #FF8200
    private let accentYellow = Color(red: 1.0, green: 0.72, blue: 0.11)    // #FFB81C
    
    private var backgroundGradient: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [Color.black, darkBlue.opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            return LinearGradient(
                colors: [primaryBlue.opacity(0.08), primaryBlue.opacity(0.16)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
    
    private var primaryText: Color {
        colorScheme == .dark ? Color.white : darkBlue
    }
    
    private var secondaryText: Color {
        colorScheme == .dark ? Color.white.opacity(0.7) : darkBlue.opacity(0.6)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white
    }
    
    private var cardBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : primaryBlue.opacity(0.08)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 40) {
                    Spacer()
                    
                    // Logo and title
                    VStack(spacing: 16) {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .shadow(color: Color.black.opacity(0.35), radius: 20, y: 10)
                        
                        Text("ClimbPulse")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(primaryText)
                        
                        Text("Heart Rate Monitor")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(secondaryText)
                    }
                    
                    Spacer()
                    
                    // Instructions
                    VStack(spacing: 12) {
                        InstructionRow(icon: "hand.raised.fill", text: "Cover the rear camera and flash with your finger")
                        InstructionRow(icon: "flashlight.on.fill", text: "Flash will turn on automatically")
                        InstructionRow(icon: "timer", text: "Hold still for 30 seconds")
                    }
                    .padding(.horizontal, 32)
                    
                    Spacer()
                    
                    // Start button
                    Button(action: startMeasurement) {
                        HStack(spacing: 12) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 24))
                            Text("Start Measurement")
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [
                                    accentOrange,
                                    colorScheme == .dark ? accentOrange.opacity(0.85) : accentYellow.opacity(0.9)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color.black.opacity(0.35), radius: 12, y: 6)
                    }
                    .padding(.horizontal, 32)
                    
                    // Last measurement preview
                    if let lastMeasurement = measurementStore.measurements.first {
                        LastMeasurementCard(measurement: lastMeasurement)
                            .padding(.horizontal, 32)
                    }
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: HistoryView()) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(primaryText)
                    }
                }
            }
            .fullScreenCover(isPresented: $showRecording) {
                RecordingView(cameraManager: cameraManager) { measurement in
                    completedMeasurement = measurement
                    showRecording = false
                    if measurement != nil {
                        showResults = true
                    }
                }
            }
            .sheet(isPresented: $showResults) {
                if let measurement = completedMeasurement {
                    ResultsView(measurement: measurement) {
                        showResults = false
                    }
                }
            }
            .task {
                await cameraManager.requestAuthorization()
            }
            .alert("Camera Access Required", isPresented: .constant(cameraManager.errorMessage != nil)) {
                Button("OK") {
                    cameraManager.errorMessage = nil
                }
            } message: {
                Text(cameraManager.errorMessage ?? "")
            }
        }
    }
    
    private func startMeasurement() {
        guard cameraManager.isAuthorized else {
            Task {
                await cameraManager.requestAuthorization()
            }
            return
        }
        showRecording = true
    }
}

// MARK: - Supporting Views

struct InstructionRow: View {
    let icon: String
    let text: String
    
    @Environment(\.colorScheme) private var colorScheme
    private let primaryBlue = Color(red: 0.0, green: 0.34, blue: 0.65)
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.8) : primaryBlue.opacity(0.7))
                .frame(width: 32)
            
            Text(text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.85) : primaryBlue.opacity(0.85))
            
            Spacer()
        }
    }
}

struct LastMeasurementCard: View {
    let measurement: Measurement
    
    @Environment(\.colorScheme) private var colorScheme
    private let primaryBlue = Color(red: 0.0, green: 0.34, blue: 0.65)
    private let accentOrange = Color(red: 1.0, green: 0.51, blue: 0.0)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Last Measurement")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.6) : primaryBlue.opacity(0.5))
            
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(accentOrange)
                    Text("\(measurement.bpm)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? Color.white : primaryBlue)
                    Text("BPM")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.7) : primaryBlue.opacity(0.6))
                }
                
                Spacer()
                
                Text(measurement.formattedDate)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.6) : primaryBlue.opacity(0.5))
            }
        }
        .padding(16)
        .background(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : primaryBlue.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 8, y: 4)
    }
}

#Preview {
    HomeView()
        .environmentObject(MeasurementStore())
}

