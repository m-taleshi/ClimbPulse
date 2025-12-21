//
//  PPGWaveformView.swift
//  ClimbPulse
//
//  Live scrolling PPG waveform visualization using SwiftUI Canvas.
//

import SwiftUI

/// Displays a live, scrolling PPG waveform.
struct PPGWaveformView: View {
    let samples: [PPGSample]
    let displayWindowSeconds: Double = 5.0  // Show last 5 seconds
    
    // JYU-inspired colors
    private let waveColor = Color(red: 1.0, green: 0.51, blue: 0.0) // Orange #FF8200
    private let glowColor = Color(red: 1.0, green: 0.72, blue: 0.11) // Yellow #FFB81C
    private let gridColorLight = Color(red: 0.0, green: 0.34, blue: 0.65).opacity(0.18)
    private let gridColorDark = Color.white.opacity(0.12)
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                // Draw grid
                drawGrid(context: context, size: size)
                
                // Draw waveform
                drawWaveform(context: context, size: size)
            }
        }
        .background((colorScheme == .dark ? Color.black.opacity(0.35) : Color.white.opacity(0.08)))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke((colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.08)), lineWidth: 1)
        )
    }
    
    /// Get samples from the display window.
    private var displaySamples: [PPGSample] {
        guard let lastTimestamp = samples.last?.timestamp else { return [] }
        let cutoff = lastTimestamp - displayWindowSeconds
        return samples.filter { $0.timestamp >= cutoff }
    }
    
    /// Draw background grid lines.
    private func drawGrid(context: GraphicsContext, size: CGSize) {
        let gridSpacing: CGFloat = 30
        let gridColor = (colorScheme == .dark ? gridColorDark : gridColorLight)
        
        // Vertical lines
        var x: CGFloat = 0
        while x <= size.width {
            var path = Path()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(path, with: .color(gridColor), lineWidth: 0.5)
            x += gridSpacing
        }
        
        // Horizontal lines
        var y: CGFloat = 0
        while y <= size.height {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(path, with: .color(gridColor), lineWidth: 0.5)
            y += gridSpacing
        }
    }
    
    /// Draw the PPG waveform line.
    private func drawWaveform(context: GraphicsContext, size: CGSize) {
        let samples = displaySamples
        guard samples.count > 1 else { return }
        
        // Calculate normalization values
        let values = samples.map { $0.value }
        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 1
        let range = max(maxVal - minVal, 1)  // Avoid division by zero
        
        // Time range for x-axis
        guard let firstTime = samples.first?.timestamp,
              let lastTime = samples.last?.timestamp else { return }
        let timeRange = max(lastTime - firstTime, 0.1)
        
        // Build path
        var path = Path()
        
        for (index, sample) in samples.enumerated() {
            // Normalize x (time) to 0-1
            let normalizedX = (sample.timestamp - firstTime) / timeRange
            let x = normalizedX * size.width
            
            // Normalize y (value) to 0-1, then invert (higher value = lower y in screen coords)
            let normalizedY = (sample.value - minVal) / range
            let y = (1 - normalizedY) * size.height * 0.8 + size.height * 0.1  // 10% padding
            
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        // Draw with glow effect
        context.stroke(path, with: .color(glowColor.opacity(0.28)), lineWidth: 4)
        context.stroke(path, with: .color(waveColor), lineWidth: 2.2)
    }
}

#Preview {
    // Generate sample data for preview
    let samples: [PPGSample] = (0..<150).map { i in
        let t = Double(i) / 30.0
        let value = 120 + 20 * sin(t * 2 * .pi * 1.2) + Double.random(in: -2...2)
        return PPGSample(timestamp: t, value: value)
    }
    
    return PPGWaveformView(samples: samples)
        .frame(height: 200)
        .padding()
}


