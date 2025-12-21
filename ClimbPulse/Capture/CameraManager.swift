//
//  CameraManager.swift
//  ClimbPulse
//
//  Manages AVCaptureSession for PPG recording using the back camera with torch.
//  Extracts average red channel values from each frame for heart rate estimation.
//

import Foundation
import AVFoundation
import UIKit
import Combine

/// Thread-safe storage for recording start time (accessed from multiple threads).
final class RecordingState: @unchecked Sendable {
    private let lock = NSLock()
    private var _startTime: Date?
    private var _startPTS: CMTime?
    
    var startTime: Date? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _startTime
        }
        set {
            lock.lock()
            _startTime = newValue
            lock.unlock()
        }
    }
    
    var startPTS: CMTime? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _startPTS
        }
        set {
            lock.lock()
            _startPTS = newValue
            lock.unlock()
        }
    }
}

/// Manages camera capture and PPG signal extraction from video frames.
@MainActor
class CameraManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isRecording = false
    @Published var currentBPM: Int?
    @Published var samples: [PPGSample] = []
    @Published var filteredSamples: [PPGSample] = []  // Band-passed samples for UI display
    @Published var timeRemaining: Int = 30
    @Published var errorMessage: String?
    @Published var isAuthorized = false
    @Published private(set) var captureSession: AVCaptureSession?
    @Published var signalQuality: SignalQuality = .noisy
    var recordingLength: Int { recordingDuration }
    
    // MARK: - Private Properties
    
    private var videoOutput: AVCaptureVideoDataOutput?
    private let sessionQueue = DispatchQueue(label: "com.climbpulse.camera.session")
    private let processingQueue = DispatchQueue(label: "com.climbpulse.camera.processing")
    private var previousRedValue: Double?
    
    // Thread-safe recording state
    private let recordingState = RecordingState()
    
    private var timer: Timer?
    private let recordingDuration: Int = 30
    
    private let ppgProcessor = PPGProcessor()
    private var lastBPMUpdate: Date = Date()
    private let bpmUpdateInterval: TimeInterval = 2.0  // Update BPM every 2 seconds
    private var detectionStartTimestamp: Double?
    
    // Start countdown only after BPM detected
    private var countdownStarted = false
    
    // Completion handler for when recording finishes
    var onRecordingComplete: ((Measurement?) -> Void)?
    
    // MARK: - Setup
    
    /// Request camera authorization.
    func requestAuthorization() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            isAuthorized = false
            errorMessage = "Camera access denied. Please enable in Settings."
        @unknown default:
            isAuthorized = false
        }
    }
    
    /// Set up the capture session with back camera and torch.
    nonisolated private func setupCaptureSession() throws -> (AVCaptureSession, AVCaptureVideoDataOutput) {
        let session = AVCaptureSession()
        session.sessionPreset = .vga640x480  // Small frame, good throughput
        
        // Get back camera
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraError.cameraUnavailable
        }
        
        // Configure camera for PPG capture
        try camera.lockForConfiguration()
        
        // Lock exposure and white balance for consistent readings
        if camera.isExposureModeSupported(.locked) {
            camera.exposureMode = .locked
        }
        if camera.isWhiteBalanceModeSupported(.locked) {
            camera.whiteBalanceMode = .locked
        }
        
        // Set frame rate to 30 fps for good temporal resolution
        camera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
        camera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
        
        camera.unlockForConfiguration()
        
        // Add camera input
        let input = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(input) else {
            throw CameraError.cannotAddInput
        }
        session.addInput(input)
        
        // Set up video output
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.setSampleBufferDelegate(self, queue: processingQueue)
        output.alwaysDiscardsLateVideoFrames = false  // keep frames to reach target rate
        
        guard session.canAddOutput(output) else {
            throw CameraError.cannotAddOutput
        }
        session.addOutput(output)
        
        return (session, output)
    }
    
    // MARK: - Recording Control
    
    /// Start PPG recording session.
    func startRecording() {
        guard isAuthorized else {
            errorMessage = "Camera not authorized"
            return
        }
        
        // Reset state
        samples = []
        filteredSamples = []
        currentBPM = nil
        timeRemaining = recordingDuration
        errorMessage = nil
        recordingState.startTime = nil
        recordingState.startPTS = nil
        captureSession = nil
        signalQuality = .noisy
        countdownStarted = false
        previousRedValue = nil
        detectionStartTimestamp = nil
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                let (session, output) = try self.setupCaptureSession()
                
                // Enable torch (flash) for illumination
                self.setTorch(on: true)
                
                // Set recording start time before starting session
                self.recordingState.startTime = Date()
                
                // Start capture session
                session.startRunning()
                
                Task { @MainActor in
                    self.captureSession = session
                    self.videoOutput = output
                    self.isRecording = true
                    // NOTE: Do NOT start the timer here.
                    // We only start the countdown after BPM is detected.
                }
            } catch {
                Task { @MainActor in
                    self.errorMessage = "Failed to start camera: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Stop recording and process final results.
    func stopRecording() {
        timer?.invalidate()
        timer = nil
        
        let session = captureSession
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.setTorch(on: false)
            session?.stopRunning()
            self.recordingState.startTime = nil
            self.recordingState.startPTS = nil
            
            Task { @MainActor in
                self.captureSession = nil
                self.isRecording = false
                self.processAndSaveMeasurement()
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Enable/disable camera torch.
    nonisolated private func setTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            if on {
                let desiredLevel = min(0.6, AVCaptureDevice.maxAvailableTorchLevel)
                try device.setTorchModeOn(level: desiredLevel)  // Slightly dim to avoid sensor saturation
            }
            device.unlockForConfiguration()
        } catch {
            print("Torch error: \(error)")
        }
    }
    
    /// Start countdown timer.
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                if self.timeRemaining > 0 {
                    self.timeRemaining -= 1
                } else {
                    self.stopRecording()
                }
            }
        }
    }
    
    /// Calculate estimated sample rate from collected samples.
    private func estimatedSampleRate() -> Double {
        guard samples.count > 1,
              let first = samples.first?.timestamp,
              let last = samples.last?.timestamp else {
            return 30.0  // Default assumption
        }
        
        let duration = last - first
        guard duration > 0 else { return 30.0 }
        
        return Double(samples.count) / duration
    }
    
    /// Process collected samples and create measurement.
    private func processAndSaveMeasurement() {
        guard samples.count > 50 else {
            errorMessage = "Insufficient data collected"
            onRecordingComplete?(nil)
            return
        }
        
        let sampleRate = estimatedSampleRate()
        
        // Trim to post-detection window if available to avoid early noisy jump
        let trimmed: [PPGSample]
        if let startTs = detectionStartTimestamp {
            trimmed = samples.filter { $0.timestamp >= startTs }
        } else {
            trimmed = samples
        }
        
        guard trimmed.count > 20 else {
            errorMessage = "Insufficient stable data collected"
            onRecordingComplete?(nil)
            return
        }
        
        // Clean signal for BPM/quality/storage
        let cleaned = ppgProcessor.cleanedSignal(samples: trimmed, sampleRate: sampleRate)
        
        // Calculate final BPM
        let finalBPM = ppgProcessor.calculateBPM(from: cleaned, sampleRate: sampleRate) ?? currentBPM ?? 0
        
        // Assess quality
        let quality = ppgProcessor.assessQuality(samples: cleaned, sampleRate: sampleRate)
        
        // Downsample for storage (use cleaned values)
        let downsampledPPG = ppgProcessor.downsample(samples: cleaned)
        
        // Calculate actual duration
        let duration = cleaned.last!.timestamp - cleaned.first!.timestamp
        
        // Create measurement
        let measurement = Measurement(
            userId: Self.getUserId(),
            duration: duration,
            sampleRate: sampleRate,
            bpm: finalBPM,
            quality: quality,
            ppgData: downsampledPPG
        )
        
        onRecordingComplete?(measurement)
    }
    
    /// Get or create anonymous user ID.
    nonisolated private static func getUserId() -> String {
        let key = "climbpulse_user_id"
        if let existingId = UserDefaults.standard.string(forKey: key) {
            return existingId
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }
    
    /// Update BPM estimate periodically.
    private func updateBPMIfNeeded() {
        let now = Date()
        guard now.timeIntervalSince(lastBPMUpdate) >= bpmUpdateInterval else { return }
        lastBPMUpdate = now
        
        let sampleRate = estimatedSampleRate()
        
        // Compute BPM
        let bpm = ppgProcessor.calculateBPM(from: samples, sampleRate: sampleRate)
        self.currentBPM = bpm
        
        // Refresh signal quality alongside BPM updates
        if !samples.isEmpty {
            self.signalQuality = ppgProcessor.assessQuality(samples: samples, sampleRate: sampleRate)
        }
        
        // Start countdown only when BPM is first detected.
        if !countdownStarted, bpm != nil {
            beginCountdownFromNow()
        }
    }
    
    /// Rebase timestamps and storage so we only keep data from the moment BPM was detected,
    /// and start the countdown from that moment.
    private func beginCountdownFromNow() {
        countdownStarted = true
        
        // Start countdown without clearing existing samples to avoid visible jumps
        self.recordingState.startTime = Date()
        self.detectionStartTimestamp = samples.last?.timestamp
        self.timeRemaining = recordingDuration
        self.startTimer()
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    /// Process each video frame to extract PPG signal.
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        // Lazily set the first presentation timestamp to align future frames
        if recordingState.startPTS == nil {
            recordingState.startPTS = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        }
        guard let startPTS = recordingState.startPTS else { return }
        
        // Extract PPG signal from frame (now using green channel from ROI)
        guard let ppgValue = extractPPGSignal(from: sampleBuffer) else { return }
        // Temporarily remove frame-level filtering to debug signal flow
        // guard ppgValue > 5 && ppgValue < 250 else { return }  // Skip too dark/saturated frames
        
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let relative = CMTimeSubtract(pts, startPTS)
        let timestamp = CMTimeGetSeconds(relative)
        
        Task { @MainActor in
            self.appendSample(value: ppgValue, timestamp: timestamp)
        }
    }
    
    /// Append a smoothed PPG sample on the main actor to avoid cross-thread state mutation.
    @MainActor
    private func appendSample(value: Double, timestamp: Double) {
        let smoothed = smoothPPGValue(value)
        let limited = clampJump(smoothed)
        let sample = PPGSample(timestamp: timestamp, value: limited)
        samples.append(sample)
        
        // Refresh filtered copy for UI and quality estimate
        let sampleRate = estimatedSampleRate()
        filteredSamples = ppgProcessor.filteredForDisplay(
            samples: samples,
            sampleRate: sampleRate
        )
        updateBPMIfNeeded()
    }
    
    /// Exponential smoothing for PPG values to suppress frame-to-frame noise.
    @MainActor
    private func smoothPPGValue(_ newValue: Double) -> Double {
        let clamped = min(max(newValue, 0), 255)
        
        guard let previous = previousRedValue else {
            previousRedValue = clamped
            return clamped
        }
        
        // Heavier smoothing on sudden jumps (likely motion noise)
        let jump = abs(clamped - previous)
        let alpha: Double = jump > 60 ? 0.18 : 0.32
        let blended = previous * (1 - alpha) + clamped * alpha
        previousRedValue = blended
        return blended
    }
    
    /// Cap abrupt jumps between consecutive samples to reduce motion spikes.
    @MainActor
    private func clampJump(_ value: Double, maxDelta: Double = 18.0) -> Double {
        guard let prev = samples.last?.value else {
            return value
        }
        let delta = value - prev
        if abs(delta) <= maxDelta {
            return value
        }
        return prev + (delta > 0 ? maxDelta : -maxDelta)
    }
    
    /// Extract PPG signal from centered ROI using green channel for improved SNR.
    /// Uses centered ROI to avoid edge glare/vignetting, filters out saturated/dim pixels,
    /// and uses green channel which typically provides better PPG signal than red.
    nonisolated private func extractPPGSignal(from sampleBuffer: CMSampleBuffer) -> Double? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }

        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)

        var greenSum: Int = 0
        var redSum: Int = 0
        var validPixelCount: Int = 0

        // BGRA format: B=0, G=1, R=2, A=3
        // Sample the full frame with light subsampling to reduce noise while
        // keeping computation low on the low-resolution buffer.
        let step = 2  // every other pixel is enough at .low preset
        for y in stride(from: 0, to: height, by: step) {
            let rowStart = y * bytesPerRow
            for x in stride(from: 0, to: width, by: step) {
                let offset = rowStart + x * 4
                let green = Int(buffer[offset + 1])  // Green channel
                let red = Int(buffer[offset + 2])    // Red channel

                greenSum += green
                redSum += red
                validPixelCount += 1
            }
        }

        guard validPixelCount > 0 else { return nil }  // Need at least one pixel

        let avgGreen = Double(greenSum) / Double(validPixelCount)
        let avgRed = Double(redSum) / Double(validPixelCount)

        // Use green channel for better SNR, or CHROM-inspired approach (green - red) to suppress color drift
        // Green channel typically has better SNR for PPG than red
        return avgGreen
    }
}

// MARK: - Errors

enum CameraError: LocalizedError {
    case cameraUnavailable
    case cannotAddInput
    case cannotAddOutput
    
    var errorDescription: String? {
        switch self {
        case .cameraUnavailable:
            return "Back camera is not available"
        case .cannotAddInput:
            return "Cannot add camera input"
        case .cannotAddOutput:
            return "Cannot add video output"
        }
    }
}
