//
//  PPGSample.swift
//  ClimbPulse
//
//  A single PPG sample with timestamp and red channel intensity value.
//

import Foundation

/// Represents a single PPG (photoplethysmography) sample from camera frames.
struct PPGSample: Codable, Identifiable {
    let id: UUID
    let timestamp: TimeInterval  // Seconds since recording started
    let value: Double            // Average red channel intensity (0-255 normalized)
    
    init(timestamp: TimeInterval, value: Double) {
        self.id = UUID()
        self.timestamp = timestamp
        self.value = value
    }
}


