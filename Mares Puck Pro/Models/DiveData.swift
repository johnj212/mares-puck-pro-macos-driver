import Foundation

/// Represents dive data downloaded from Mares Puck Pro
public struct DiveData: Codable, Identifiable {
    public let id = UUID()
    
    // MARK: - Basic Dive Info
    
    public let diveNumber: Int
    public let date: Date
    public let duration: TimeInterval  // in seconds
    public let maxDepth: Double       // in meters
    public let averageDepth: Double   // in meters
    public let waterType: WaterType
    
    // MARK: - Temperature
    
    public let maxTemperature: Double?  // in Celsius
    public let minTemperature: Double?  // in Celsius
    
    // MARK: - Dive Profile
    
    public let profileSamples: [DiveProfileSample]
    public let sampleInterval: TimeInterval  // seconds between samples
    
    // MARK: - Decompression Info
    
    public let decompressionStops: [DecompressionStop]
    public let surfaceInterval: TimeInterval?  // time since last dive
    
    // MARK: - Equipment
    
    public let gasType: GasType
    public let oxygenPercentage: Double?  // for Nitrox
    
    public init(
        diveNumber: Int,
        date: Date,
        duration: TimeInterval,
        maxDepth: Double,
        averageDepth: Double,
        waterType: WaterType,
        maxTemperature: Double? = nil,
        minTemperature: Double? = nil,
        profileSamples: [DiveProfileSample] = [],
        sampleInterval: TimeInterval = 20,
        decompressionStops: [DecompressionStop] = [],
        surfaceInterval: TimeInterval? = nil,
        gasType: GasType = .air,
        oxygenPercentage: Double? = nil
    ) {
        self.diveNumber = diveNumber
        self.date = date
        self.duration = duration
        self.maxDepth = maxDepth
        self.averageDepth = averageDepth
        self.waterType = waterType
        self.maxTemperature = maxTemperature
        self.minTemperature = minTemperature
        self.profileSamples = profileSamples
        self.sampleInterval = sampleInterval
        self.decompressionStops = decompressionStops
        self.surfaceInterval = surfaceInterval
        self.gasType = gasType
        self.oxygenPercentage = oxygenPercentage
    }
}

// MARK: - Supporting Types

public enum WaterType: String, Codable, CaseIterable {
    case saltwater = "Saltwater"
    case freshwater = "Freshwater"
    case unknown = "Unknown"
}

public enum GasType: String, Codable, CaseIterable {
    case air = "Air"
    case nitrox = "Nitrox"
    case unknown = "Unknown"
}

/// Individual depth/time sample from dive profile
public struct DiveProfileSample: Codable {
    public let time: TimeInterval        // seconds from dive start
    public let depth: Double            // meters
    public let temperature: Double?     // Celsius
    public let pressure: Double?        // bar (if available)
    
    public init(time: TimeInterval, depth: Double, temperature: Double? = nil, pressure: Double? = nil) {
        self.time = time
        self.depth = depth
        self.temperature = temperature
        self.pressure = pressure
    }
}

/// Decompression stop information
public struct DecompressionStop: Codable {
    public let depth: Double           // meters
    public let duration: TimeInterval  // seconds
    
    public init(depth: Double, duration: TimeInterval) {
        self.depth = depth
        self.duration = duration
    }
}

// MARK: - Extensions

extension DiveData {
    /// Formatted dive duration (MM:SS)
    public var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// Maximum depth formatted with units
    public var formattedMaxDepth: String {
        return String(format: "%.1f m", maxDepth)
    }
    
    /// Average depth formatted with units
    public var formattedAverageDepth: String {
        return String(format: "%.1f m", averageDepth)
    }
    
    /// Temperature range formatted
    public var formattedTemperatureRange: String? {
        guard let min = minTemperature, let max = maxTemperature else {
            return nil
        }
        if abs(min - max) < 0.1 {
            return String(format: "%.1f°C", min)
        } else {
            return String(format: "%.1f°C - %.1f°C", min, max)
        }
    }
    
    /// Check if dive has decompression stops
    public var hasDecompressionStops: Bool {
        return !decompressionStops.isEmpty
    }
}