//
//  Measurement.swift
//  ClimbPulse
//
//  Data model for a complete heart rate measurement session.
//

import Foundation
import UIKit

/// Quality assessment of the PPG signal
enum SignalQuality: String, Codable {
    case good = "Good"
    case noisy = "Noisy"
}

/// A complete measurement record ready for local storage and future API upload.
struct Measurement: Codable, Identifiable {
    let id: UUID
    let userId: String           // Anonymous user ID (persisted per device)
    let deviceModel: String      // e.g., "iPhone 14 Pro"
    let timestamp: Date          // When measurement was taken
    let duration: TimeInterval   // Recording duration in seconds
    let sampleRate: Double       // Approximate samples per second
    let bpm: Int                 // Final estimated heart rate
    let quality: SignalQuality   // Signal quality assessment
    let ppgData: [Double]        // Downsampled PPG values for storage
    
    init(
        userId: String,
        timestamp: Date = Date(),
        duration: TimeInterval,
        sampleRate: Double,
        bpm: Int,
        quality: SignalQuality,
        ppgData: [Double]
    ) {
        self.id = UUID()
        self.userId = userId
        self.deviceModel = Measurement.getDeviceModel()
        self.timestamp = timestamp
        self.duration = duration
        self.sampleRate = sampleRate
        self.bpm = bpm
        self.quality = quality
        self.ppgData = ppgData
    }
    
    /// Get device model name
    private static func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return marketingName(for: identifier)
    }
    
    /// Map hardware identifier to marketing name (partial list, extend as needed).
    private static func marketingName(for identifier: String) -> String {
        let map: [String: String] = [
            // iPhone 14 family
            "iPhone14,7": "iPhone 14",
            "iPhone14,8": "iPhone 14 Plus",
            "iPhone15,2": "iPhone 14 Pro",
            "iPhone15,3": "iPhone 14 Pro Max",
            // iPhone 13 family
            "iPhone14,5": "iPhone 13",
            "iPhone14,2": "iPhone 13 Pro",
            "iPhone14,3": "iPhone 13 Pro Max",
            "iPhone14,4": "iPhone 13 mini",
            // iPhone 12 family
            "iPhone13,4": "iPhone 12 Pro Max",
            "iPhone13,3": "iPhone 12 Pro",
            "iPhone13,2": "iPhone 12",
            "iPhone13,1": "iPhone 12 mini"
        ]
        return map[identifier] ?? identifier
    }
    
    /// Formatted date string for display
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    /// Convert to JSON Data for API upload
    func toJSON() -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(self)
    }
}


