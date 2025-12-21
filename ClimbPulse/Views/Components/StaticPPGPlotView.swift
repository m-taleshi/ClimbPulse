//
//  StaticPPGPlotView.swift
//  ClimbPulse
//
//  Static PPG plot for displaying recorded measurement data in results.
//

import SwiftUI

/// Displays a static plot of recorded PPG data (downsampled).
struct StaticPPGPlotView: View {
    let data: [Double]
    
    @Environment(\.colorScheme) private var colorScheme
    // JYU-inspired colors
    private let waveColor = Color(red: 1.0, green: 0.51, blue: 0.0) // Orange #FF8200
    private let glowColor = Color(red: 1.0, green: 0.72, blue: 0.11) // Yellow #FFB81C
    private let gridColorLight = Color(red: 0.0, green: 0.34, blue: 0.65).opacity(0.18)
    private let gridColorDark = Color.white.opacity(0.12)
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                // Draw background grid
                drawGrid(context: context, size: size)
                
                // Draw waveform
                drawWaveform(context: context, size: size)
                
                // Draw axes labels
                drawLabels(context: context, size: size)
            }
        }
        .background(colorScheme == .dark ? Color.black.opacity(0.35) : Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.08), lineWidth: 1)
        )
    }
    
    private func drawGrid(context: GraphicsContext, size: CGSize) {
        let verticalLines = 6
        let horizontalLines = 4
        let gridColor = colorScheme == .dark ? gridColorDark : gridColorLight
        
        // Vertical lines
        for i in 0...verticalLines {
            let x = size.width * CGFloat(i) / CGFloat(verticalLines)
            var path = Path()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(path, with: .color(gridColor), lineWidth: 0.5)
        }
        
        // Horizontal lines
        for i in 0...horizontalLines {
            let y = size.height * CGFloat(i) / CGFloat(horizontalLines)
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(path, with: .color(gridColor), lineWidth: 0.5)
        }
    }
    
    private func drawWaveform(context: GraphicsContext, size: CGSize) {
        guard data.count > 1 else { return }
        
        // Calculate normalization
        let minVal = data.min() ?? 0
        let maxVal = data.max() ?? 1
        let range = max(maxVal - minVal, 1)
        
        // Build path
        var path = Path()
        let padding: CGFloat = 0.1  // 10% vertical padding
        
        for (index, value) in data.enumerated() {
            let x = CGFloat(index) / CGFloat(data.count - 1) * size.width
            let normalizedY = (value - minVal) / range
            let y = (1 - normalizedY) * size.height * (1 - 2 * padding) + size.height * padding
            
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        // Draw with gradient effect
        context.stroke(path, with: .color(glowColor.opacity(0.28)), lineWidth: 3.5)
        context.stroke(path, with: .color(waveColor), lineWidth: 1.8)
    }
    
    private func drawLabels(context: GraphicsContext, size: CGSize) {
        let textColor = colorScheme == .dark ? Color.white.opacity(0.65) : Color(red: 0.0, green: 0.34, blue: 0.65)
        
        // Start label
        let startText = Text("0s").font(.caption2).foregroundColor(textColor)
        context.draw(startText, at: CGPoint(x: 15, y: size.height - 10))
        
        // End label (assuming 30s recording)
        let endText = Text("30s").font(.caption2).foregroundColor(textColor)
        context.draw(endText, at: CGPoint(x: size.width - 15, y: size.height - 10))
    }
}

#Preview {
    // Generate sample data
    let data: [Double] = (0..<100).map { i in
        let t = Double(i) / 100.0 * 30.0
        return 120 + 15 * sin(t * 2 * .pi * 1.2) + Double.random(in: -3...3)
    }
    
    return StaticPPGPlotView(data: data)
        .frame(height: 150)
        .padding()
}


