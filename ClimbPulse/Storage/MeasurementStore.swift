//
//  MeasurementStore.swift
//  ClimbPulse
//
//  Local storage for measurements using JSON files in the app's documents directory.
//

import Foundation
import SwiftUI
import Combine

/// Manages local persistence of measurements.
@MainActor
class MeasurementStore: ObservableObject {
    
    @Published var measurements: [Measurement] = []
    
    private let fileName = "measurements.json"
    
    init() {
        loadMeasurements()
    }
    
    // MARK: - Public Methods
    
    /// Save a new measurement.
    func save(_ measurement: Measurement) {
        measurements.insert(measurement, at: 0)  // Most recent first
        persistMeasurements()
    }
    
    /// Delete a measurement by ID.
    func delete(_ measurement: Measurement) {
        measurements.removeAll { $0.id == measurement.id }
        persistMeasurements()
    }
    
    /// Delete measurement at index.
    func delete(at offsets: IndexSet) {
        measurements.remove(atOffsets: offsets)
        persistMeasurements()
    }
    
    /// Clear all measurements.
    func clearAll() {
        measurements = []
        persistMeasurements()
    }
    
    // MARK: - Private Methods
    
    /// Get URL for storage file.
    private func fileURL() -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent(fileName)
    }
    
    /// Load measurements from disk.
    private func loadMeasurements() {
        let url = fileURL()
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            measurements = []
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            measurements = try decoder.decode([Measurement].self, from: data)
        } catch {
            print("Failed to load measurements: \(error)")
            measurements = []
        }
    }
    
    /// Save measurements to disk.
    private func persistMeasurements() {
        let url = fileURL()
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(measurements)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Failed to save measurements: \(error)")
        }
    }
}
