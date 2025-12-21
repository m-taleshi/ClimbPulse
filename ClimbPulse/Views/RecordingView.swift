//
//  RecordingView.swift
//  ClimbPulse
//
//  Live recording screen showing PPG waveform, BPM, and countdown timer.
//

import SwiftUI
import AVFoundation

struct RecordingView: View {
    @ObservedObject var cameraManager: CameraManager
    let onComplete: (Measurement?) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // Theme colors
    // JYU-inspired palette: deep blue + vivid orange
    private let primaryBlue = Color(red: 0.0, green: 0.34, blue: 0.65)      // #0056A5
    private let darkBlue = Color(red: 0.02, green: 0.16, blue: 0.32)       // #042948
    private let accentOrange = Color(red: 1.0, green: 0.51, blue: 0.0)     // #FF8200
    private let accentYellow = Color(red: 1.0, green: 0.72, blue: 0.11)    // #FFB81C
    
    private var recordingProgress: Double {
        guard cameraManager.recordingLength > 0 else { return 0 }
        let elapsed = Double(cameraManager.recordingLength - cameraManager.timeRemaining)
        return max(0, min(1, elapsed / Double(cameraManager.recordingLength)))
    }
    
    private var backgroundGradient: LinearGradient {
        let colors: [Color]
        if colorScheme == .dark {
            colors = [darkBlue, primaryBlue.opacity(0.75)]
        } else {
            colors = [primaryBlue, primaryBlue.opacity(0.65), accentOrange.opacity(0.6)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: 26) {
                Spacer().frame(height: 36) // push content below dynamic island/status bar
                
                VStack(spacing: 8) {
                    Text("Please keep still")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Gently cover the rear camera and flash with your fingertip.")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }
                
                // Live camera preview shown inside the BPM ring so users see the correct camera to cover
                BPMPreviewRing(
                    session: cameraManager.captureSession,
                    bpm: cameraManager.currentBPM,
                    progress: recordingProgress,
                    quality: cameraManager.signalQuality,
                    accent: accentOrange,
                    glow: accentYellow
                )
                
                // Countdown timer
                VStack(spacing: 10) {
                    HStack(alignment: .center) {
                        // Cancel (left)
                        Button(action: cancelRecording) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 42, height: 42)
                                .background(Color.red.opacity(0.28))
                                .clipShape(Circle())
                                .overlay(
                                    Circle().stroke(Color.white.opacity(0.35), lineWidth: 1)
                                )
                        }
                        .accessibilityLabel("Cancel and discard")
                        
                        Spacer()
                        
                        // Time center
                        Text("\(cameraManager.timeRemaining)")
                            .font(.system(size: 60, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .monospacedDigit()
                            .frame(minWidth: 120)
                        
                        Spacer()
                        
                        // Stop/save early (right)
                        Button(action: finishEarly) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 42, height: 42)
                                .background(Color.green.opacity(0.35))
                                .clipShape(Circle())
                                .overlay(
                                    Circle().stroke(Color.white.opacity(0.35), lineWidth: 1)
                                )
                        }
                        .accessibilityLabel("Stop now and save")
                    }
                    .padding(.horizontal, 20)
                    
                    Text("seconds remaining")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // PPG Waveform
                VStack(alignment: .leading, spacing: 8) {
                    Text("PPG Signal")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                    
                    PPGWaveformView(samples: cameraManager.filteredSamples)
                        .frame(height: 180)
                }
                .padding(.horizontal, 20)
                
                // Instructions
                VStack(spacing: 12) {
                    FingerPlacementIndicator(
                        sampleCount: cameraManager.samples.count,
                        signalQuality: cameraManager.signalQuality
                    )
                    
                    Text("Keep your finger steady on the rear camera + flash")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.vertical, 12)
            }
            .padding(.vertical, 20)
        }
        .onAppear {
            startRecording()
        }
        .onChange(of: cameraManager.isRecording) { _, isRecording in
            if !isRecording {
                // recording stopped early or naturally; UI will dismiss via onComplete callback
            }
        }
    }
    
    private func startRecording() {
        cameraManager.onRecordingComplete = { measurement in
            onComplete(measurement)
        }
        cameraManager.startRecording()
    }
    
    private func finishEarly() {
        // Stop and let the normal completion flow show results
        cameraManager.stopRecording()
    }
    
    private func cancelRecording() {
        // Stop and discard this attempt
        cameraManager.stopRecording()
        dismiss()
        onComplete(nil)
    }
}

// MARK: - Supporting Views

struct FingerPlacementIndicator: View {
    let sampleCount: Int
    let signalQuality: SignalQuality
    
    private var signalStrength: SignalStrength {
        if sampleCount < 10 {
            return .none
        } else if signalQuality == .good {
            return .good
        } else {
            return .weak
        }
    }
    
    enum SignalStrength {
        case none, weak, good
        
        var color: Color {
            switch self {
            case .none: return .gray
            case .weak: return .yellow
            case .good: return Color(red: 1.0, green: 0.51, blue: 0.0)
            }
        }
        
        var text: String {
            switch self {
            case .none: return "No signal"
            case .weak: return "Adjust finger for a clearer signal"
            case .good: return "Signal looks good"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(signalStrength.color)
                .frame(width: 8, height: 8)
            
            Text(signalStrength.text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.1))
        .clipShape(Capsule())
    }
}

struct BPMPreviewRing: View {
    let session: AVCaptureSession?
    let bpm: Int?
    let progress: Double
    let quality: SignalQuality
    let accent: Color
    let glow: Color
    
    private var clampedProgress: Double {
        max(0, min(1, progress))
    }
    
    private var qualityText: String {
        switch quality {
        case .good:
            return "Signal looks good"
        case .noisy:
            return "Adjust finger for clearer signal"
        }
    }
    
    private var bpmText: String {
        if let bpm {
            return "\(bpm)"
        } else {
            return "--"
        }
    }
    
    var body: some View {
        ZStack {
            // Live preview with a soft tint so users see exactly which camera/flash to cover
            CameraPreviewView(session: session)
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.45),
                            Color.red.opacity(0.2)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(Circle())
            
            // Base ring
            Circle()
                .stroke(Color.white.opacity(0.22), lineWidth: 12)
            
            // Progress ring (starts when countdown begins)
            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    AngularGradient(
                        colors: [
                            accent,
                            glow,
                            accent
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.25), value: clampedProgress)
            
            // BPM readout
            VStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
                    .symbolEffect(.pulse, options: .repeating, value: bpm != nil)
                
                Text(bpmText)
                    .font(.system(size: 58, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                
                Text("bpm")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .frame(width: 280, height: 280)
        .shadow(color: glow.opacity(0.35), radius: 18, y: 10)
    }
}

#Preview {
    RecordingView(cameraManager: CameraManager()) { _ in }
}
