//
//  PPGProcessor.swift
//  ClimbPulse
//
//  Signal processing for PPG data: band-pass filtering and peak detection for BPM estimation.
//

import Foundation
import Accelerate

/// Processes raw PPG samples to extract heart rate (BPM) and assess signal quality.
class PPGProcessor {
    
    // MARK: - Configuration
    
    /// Expected heart rate range (40-200 BPM → 0.67-3.33 Hz)
    private let minHeartRateHz: Double = 0.67
    private let maxHeartRateHz: Double = 3.33
    
    /// Window size for BPM calculation (in seconds)
    private let windowSeconds: Double = 10.0
    
    /// Minimum samples needed for reliable BPM estimation
    private let minSamplesForBPM: Int = 100
    
    // MARK: - Public Methods
    
    /// Calculate BPM from recent PPG samples using peak detection.
    /// - Parameters:
    ///   - samples: Array of PPG samples with timestamps
    ///   - sampleRate: Estimated sample rate in Hz
    /// - Returns: Estimated BPM or nil if insufficient data
    func calculateBPM(from samples: [PPGSample], sampleRate: Double) -> Int? {
        guard samples.count >= minSamplesForBPM else { return nil }
        
        // Extract values from recent window
        let windowSamples = getRecentWindow(samples: samples, windowSeconds: windowSeconds)
        guard windowSamples.count >= minSamplesForBPM else { return nil }
        
        // Preprocess to remove spikes and normalize amplitude
        let values = preprocess(signal: windowSamples.map { $0.value })
        
        // Apply band-pass filter to isolate heart rate frequencies
        let filtered = bandPassFilter(signal: values, sampleRate: sampleRate)
        
        // Detect peaks in filtered signal
        let peaks = detectPeaks(in: filtered)
        
        // Calculate BPM from inter-peak intervals
        guard peaks.count >= 2 else { return nil }
        
        let intervals = calculateIntervals(peaks: peaks, sampleRate: sampleRate)
        guard !intervals.isEmpty else { return nil }
        
        // Use median interval for robustness against outliers
        let medianInterval = median(intervals)
        let bpm = Int(60.0 / medianInterval)
        
        // Sanity check: HR should be in reasonable range (40-200 BPM)
        guard bpm >= 40 && bpm <= 200 else { return nil }
        
        return bpm
    }
    
    /// Assess signal quality based on variance and peak regularity.
    /// - Parameters:
    ///   - samples: Array of PPG samples
    ///   - sampleRate: Sample rate in Hz
    /// - Returns: Quality assessment (good or noisy)
    func assessQuality(samples: [PPGSample], sampleRate: Double) -> SignalQuality {
        guard samples.count >= minSamplesForBPM else { return .noisy }
        
        let values = preprocess(signal: samples.map { $0.value })
        let filtered = bandPassFilter(signal: values, sampleRate: sampleRate)
        let peaks = detectPeaks(in: filtered)
        
        // Check peak count (expect ~0.5-3 peaks per second for HR 40-180)
        let duration = samples.last!.timestamp - samples.first!.timestamp
        let expectedMinPeaks = Int(duration * 0.5)
        let expectedMaxPeaks = Int(duration * 3.5)
        
        guard peaks.count >= expectedMinPeaks && peaks.count <= expectedMaxPeaks else {
            return .noisy
        }
        
        // Check interval consistency (coefficient of variation)
        let intervals = calculateIntervals(peaks: peaks, sampleRate: sampleRate)
        guard intervals.count >= 3 else { return .noisy }
        
        let meanInterval = intervals.reduce(0, +) / Double(intervals.count)
        let variance = intervals.map { pow($0 - meanInterval, 2) }.reduce(0, +) / Double(intervals.count)
        let stdDev = sqrt(variance)
        let cv = stdDev / meanInterval  // Coefficient of variation
        
        // CV < 0.2 indicates relatively consistent heart rhythm
        return cv < 0.25 ? .good : .noisy
    }
    
    /// Downsample PPG data for storage (reduce to ~100 points).
    func downsample(samples: [PPGSample], targetCount: Int = 100) -> [Double] {
        guard samples.count > targetCount else {
            return samples.map { $0.value }
        }
        
        let step = Double(samples.count) / Double(targetCount)
        var result: [Double] = []
        
        for i in 0..<targetCount {
            let index = Int(Double(i) * step)
            result.append(samples[index].value)
        }
        
        return result
    }
    
    /// Provide a filtered copy of the most recent window for on-screen display.
    func filteredForDisplay(
        samples: [PPGSample],
        sampleRate: Double,
        windowSeconds: Double = 6.0
    ) -> [PPGSample] {
        let window = getRecentWindow(samples: samples, windowSeconds: windowSeconds)
        guard !window.isEmpty else { return [] }
        
        let preprocessed = preprocess(signal: window.map { $0.value })
        let filtered = bandPassFilter(signal: preprocessed, sampleRate: sampleRate)
        
        return zip(window, filtered).map { sample, filteredValue in
            PPGSample(timestamp: sample.timestamp, value: filteredValue)
        }
    }
    
    /// Clean the full-length signal for storage/plotting (detrend + band-pass).
    func cleanedSignal(samples: [PPGSample], sampleRate: Double) -> [PPGSample] {
        guard !samples.isEmpty else { return [] }
        let preprocessed = preprocess(signal: samples.map { $0.value })
        let filtered = bandPassFilter(signal: preprocessed, sampleRate: sampleRate)
        return zip(samples, filtered).map { PPGSample(timestamp: $0.timestamp, value: $1) }
    }
    
    // MARK: - Private Signal Processing Methods
    
    /// Get samples from the most recent window.
    private func getRecentWindow(samples: [PPGSample], windowSeconds: Double) -> [PPGSample] {
        guard let lastTimestamp = samples.last?.timestamp else { return [] }
        let cutoff = lastTimestamp - windowSeconds
        return samples.filter { $0.timestamp >= cutoff }
    }
    
    /// Remove spikes and normalize amplitude ahead of filtering.
    private func preprocess(signal: [Double]) -> [Double] {
        let detrended = removeLinearTrend(signal)
        let medianSmoothed = medianFilter(signal: detrended, windowSize: 5)
        let clipped = softClip(signal: medianSmoothed, limitStd: 3.5)
        return normalize(signal: clipped)
    }
    
    /// Remove slow linear drift to keep baseline stable.
    private func removeLinearTrend(_ signal: [Double]) -> [Double] {
        guard signal.count > 2 else { return signal }
        let n = Double(signal.count)
        let meanX = (n - 1) / 2.0
        let meanY = signal.reduce(0, +) / n
        
        var numerator = 0.0
        var denominator = 0.0
        for (i, y) in signal.enumerated() {
            let x = Double(i)
            numerator += (x - meanX) * (y - meanY)
            denominator += (x - meanX) * (x - meanX)
        }
        guard denominator > 0 else { return signal }
        let slope = numerator / denominator
        let intercept = meanY - slope * meanX
        
        return signal.enumerated().map { index, y in
            let x = Double(index)
            return y - (slope * x + intercept)
        }
    }
    
    /// Simple band-pass filter using moving average subtraction (high-pass) and smoothing (low-pass).
    /// This is a computationally efficient approximation suitable for real-time use.
    private func bandPassFilter(signal: [Double], sampleRate: Double) -> [Double] {
        guard signal.count > 4 else { return signal }
        
        // Lightweight single-pole IIR band-pass tuned for heart-rate band (~0.6-4 Hz).
        // This suppresses slow drift and high-frequency noise better than the old moving average chain.
        let lowCutHz = max(0.6, minHeartRateHz * 0.9)
        let highCutHz = min(4.0, maxHeartRateHz * 1.2)
        let dt = 1.0 / max(sampleRate, 1.0)
        
        // High-pass
        let rcHigh = 1.0 / (2 * .pi * lowCutHz)
        let alphaHigh = rcHigh / (rcHigh + dt)
        var highPassed = Array(repeating: 0.0, count: signal.count)
        for i in 1..<signal.count {
            highPassed[i] = alphaHigh * (highPassed[i-1] + signal[i] - signal[i-1])
        }
        
        // Low-pass
        let rcLow = 1.0 / (2 * .pi * highCutHz)
        let alphaLow = dt / (rcLow + dt)
        var bandPassed = Array(repeating: highPassed.first ?? 0.0, count: signal.count)
        for i in 1..<signal.count {
            bandPassed[i] = bandPassed[i-1] + alphaLow * (highPassed[i] - bandPassed[i-1])
        }
        
        // Light smoothing to tame stair-stepping in the display without flattening beats
        let smoothWindow = max(3, Int(sampleRate / 12.0))
        return movingAverage(signal: bandPassed, windowSize: smoothWindow)
    }
    
    /// High-pass filter: subtract moving average to remove baseline wander.
    private func highPassFilter(signal: [Double], windowSize: Int) -> [Double] {
        let movingAvg = movingAverage(signal: signal, windowSize: windowSize)
        return zip(signal, movingAvg).map { $0 - $1 }
    }
    
    /// Low-pass filter: simple moving average for smoothing.
    private func lowPassFilter(signal: [Double], windowSize: Int) -> [Double] {
        return movingAverage(signal: signal, windowSize: windowSize)
    }
    
    /// Calculate moving average of signal.
    private func movingAverage(signal: [Double], windowSize: Int) -> [Double] {
        guard signal.count >= windowSize else { return signal }
        
        var result: [Double] = []
        let halfWindow = windowSize / 2
        
        for i in 0..<signal.count {
            let start = max(0, i - halfWindow)
            let end = min(signal.count - 1, i + halfWindow)
            let window = Array(signal[start...end])
            let avg = window.reduce(0, +) / Double(window.count)
            result.append(avg)
        }
        
        return result
    }
    
    /// Median filter to suppress impulsive noise.
    private func medianFilter(signal: [Double], windowSize: Int) -> [Double] {
        guard signal.count > windowSize && windowSize >= 3 else { return signal }
        let half = windowSize / 2
        var output: [Double] = []
        
        for i in 0..<signal.count {
            let start = max(0, i - half)
            let end = min(signal.count - 1, i + half)
            let window = Array(signal[start...end]).sorted()
            output.append(window[window.count / 2])
        }
        
        return output
    }
    
    /// Normalize signal to zero-mean unit-variance to stabilize peak detection.
    private func normalize(signal: [Double]) -> [Double] {
        guard !signal.isEmpty else { return signal }
        let mean = signal.reduce(0, +) / Double(signal.count)
        let variance = signal.map { pow($0 - mean, 2) }.reduce(0, +) / Double(signal.count)
        let std = sqrt(variance)
        guard std > 0.0001 else { return signal.map { _ in 0 } }
        return signal.map { ($0 - mean) / std }
    }
    
    /// Soft clip extreme values using a smooth tanh limiter to reduce motion spikes.
    private func softClip(signal: [Double], limitStd: Double) -> [Double] {
        guard !signal.isEmpty else { return signal }
        let mean = signal.reduce(0, +) / Double(signal.count)
        let variance = signal.map { pow($0 - mean, 2) }.reduce(0, +) / Double(signal.count)
        let std = max(sqrt(variance), 1e-6)
        let cap = limitStd * std
        return signal.map { sample in
            let centered = sample - mean
            let limited = cap * tanh(centered / cap)
            return mean + limited
        }
    }
    
    /// Detect peaks in signal using local maxima detection with adaptive threshold.
    private func detectPeaks(in signal: [Double]) -> [Int] {
        guard signal.count > 4 else { return [] }
        
        var peaks: [Int] = []
        
        // Calculate adaptive threshold (mean + 0.5 * std)
        let mean = signal.reduce(0, +) / Double(signal.count)
        let variance = signal.map { pow($0 - mean, 2) }.reduce(0, +) / Double(signal.count)
        let threshold = mean + 0.3 * sqrt(variance)
        
        // Find local maxima above threshold
        for i in 2..<(signal.count - 2) {
            let current = signal[i]
            
            // Check if local maximum
            if current > signal[i-1] && current > signal[i-2] &&
               current > signal[i+1] && current > signal[i+2] &&
               current > threshold {
                
                // Ensure minimum distance from previous peak (avoid detecting same beat twice)
                // Minimum ~200ms between beats (300 BPM max)
                if let lastPeak = peaks.last {
                    if i - lastPeak > 5 {  // At least 5 samples apart
                        peaks.append(i)
                    }
                } else {
                    peaks.append(i)
                }
            }
        }
        
        return peaks
    }
    
    /// Calculate time intervals between consecutive peaks.
    private func calculateIntervals(peaks: [Int], sampleRate: Double) -> [Double] {
        guard peaks.count >= 2 else { return [] }
        
        var intervals: [Double] = []
        for i in 1..<peaks.count {
            let sampleDiff = peaks[i] - peaks[i-1]
            let timeDiff = Double(sampleDiff) / sampleRate
            
            // Only include reasonable intervals (0.3-1.5 seconds → 40-200 BPM)
            if timeDiff >= 0.3 && timeDiff <= 1.5 {
                intervals.append(timeDiff)
            }
        }
        
        return intervals
    }
    
    /// Calculate median of an array.
    private func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let count = sorted.count
        
        if count % 2 == 0 {
            return (sorted[count/2 - 1] + sorted[count/2]) / 2.0
        } else {
            return sorted[count/2]
        }
    }
}

