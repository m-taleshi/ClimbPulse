//
//  APIClient.swift
//  ClimbPulse
//
//  Stub API client for future backend integration (FastAPI POST /v1/measurements).
//

import Foundation

/// API client for uploading measurements to the backend.
/// Currently a stub - implement actual network calls when backend is ready.
class APIClient {
    
    static let shared = APIClient()
    
    // TODO: Configure with actual backend URL
    private let baseURL = "https://api.climbpulse.example.com"
    
    private init() {}
    
    /// Upload a measurement to the backend.
    /// - Parameter measurement: The measurement to upload
    /// - Returns: True if upload successful, false otherwise
    func uploadMeasurement(_ measurement: Measurement) async throws -> Bool {
        // Prepare the endpoint
        guard let url = URL(string: "\(baseURL)/v1/measurements") else {
            throw APIError.invalidURL
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Encode measurement to JSON
        guard let jsonData = measurement.toJSON() else {
            throw APIError.encodingFailed
        }
        request.httpBody = jsonData
        
        // TODO: Uncomment when backend is ready
        /*
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            throw APIError.serverError(statusCode: httpResponse.statusCode)
        }
        
        return true
        */
        
        // Stub: Simulate successful upload after delay
        print("📤 [API Stub] Would upload measurement: \(measurement.id)")
        print("   BPM: \(measurement.bpm), Quality: \(measurement.quality.rawValue)")
        print("   JSON size: \(jsonData.count) bytes")
        
        try await Task.sleep(nanoseconds: 500_000_000)  // 0.5s simulated delay
        return true
    }
    
    /// Batch upload multiple measurements.
    func uploadMeasurements(_ measurements: [Measurement]) async throws -> Int {
        var successCount = 0
        
        for measurement in measurements {
            if try await uploadMeasurement(measurement) {
                successCount += 1
            }
        }
        
        return successCount
    }
}

// MARK: - API Errors

enum APIError: LocalizedError {
    case invalidURL
    case encodingFailed
    case invalidResponse
    case serverError(statusCode: Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .encodingFailed:
            return "Failed to encode measurement data"
        case .invalidResponse:
            return "Invalid server response"
        case .serverError(let code):
            return "Server error (status: \(code))"
        }
    }
}


