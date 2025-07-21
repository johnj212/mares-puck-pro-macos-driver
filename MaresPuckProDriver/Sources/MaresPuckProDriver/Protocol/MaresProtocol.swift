import Foundation

/// Mares IconHD Protocol Implementation
/// Based on libdivecomputer analysis and testing
public struct MaresProtocol {
    
    // MARK: - Protocol Constants
    
    /// Acknowledgment byte - device confirms command receipt
    static let ACK: UInt8 = 0xAA
    
    /// End/trailer byte - marks end of packet
    static let END: UInt8 = 0xEA
    
    /// XOR mask for command bytes
    static let XOR: UInt8 = 0xA5
    
    /// Version command - requests device version info
    static let CMD_VERSION: UInt8 = 0xC2
    
    /// Flash size command - requests memory size info  
    static let CMD_FLASHSIZE: UInt8 = 0xB3
    
    /// Read command - requests memory data
    static let CMD_READ: UInt8 = 0xE7
    
    // MARK: - Device Models
    
    public enum DeviceModel: UInt8 {
        case matrix = 0x0F
        case smart = 0x10
        case smartApnea = 0x11 // Different from smart
        case iconHD = 0x14
        case iconHDNet = 0x15
        case puckPro = 0x18      // Our target device
        case nemoWide2 = 0x19
        case genius = 0x1C
        case puck2 = 0x1F
        case quadAir = 0x23
        case smartAir = 0x24
        case quad = 0x29
        case horizon = 0x2C
    }
    
    // MARK: - Protocol Errors
    
    public enum ProtocolError: Error, LocalizedError {
        case invalidResponse
        case unexpectedHeader(UInt8)
        case unexpectedTrailer(UInt8)
        case communicationTimeout
        case deviceNotFound
        case unsupportedDevice
        
        public var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Invalid response from device"
            case .unexpectedHeader(let byte):
                return "Unexpected header byte: 0x\(String(byte, radix: 16, uppercase: true))"
            case .unexpectedTrailer(let byte):
                return "Unexpected trailer byte: 0x\(String(byte, radix: 16, uppercase: true))"
            case .communicationTimeout:
                return "Communication timeout"
            case .deviceNotFound:
                return "Device not found or not responding"
            case .unsupportedDevice:
                return "Unsupported device model"
            }
        }
    }
    
    // MARK: - Command Creation
    
    /// Creates a Mares command packet with proper XOR encoding
    /// - Parameter command: The command byte
    /// - Returns: Command packet as Data (command + XORed command)
    static func createCommand(_ command: UInt8) -> Data {
        let xoredCommand = command ^ XOR
        return Data([command, xoredCommand])
    }
    
    /// Creates the CMD_VERSION command packet
    /// - Returns: Version command as Data
    static func createVersionCommand() -> Data {
        return createCommand(CMD_VERSION)
    }
    
    // MARK: - Response Parsing
    
    /// Parses a Mares protocol response
    /// - Parameter data: Raw response data
    /// - Returns: Payload data (without ACK and END bytes)
    /// - Throws: ProtocolError if response format is invalid
    static func parseResponse(_ data: Data) -> Result<Data, ProtocolError> {
        guard data.count >= 2 else {
            return .failure(.invalidResponse)
        }
        
        // Check for ACK header
        guard data.first == ACK else {
            return .failure(.unexpectedHeader(data.first ?? 0))
        }
        
        // Check for END trailer
        guard data.last == END else {
            return .failure(.unexpectedTrailer(data.last ?? 0))
        }
        
        // Extract payload (remove ACK and END)
        let payload = data.dropFirst().dropLast()
        return .success(Data(payload))
    }
    
    // MARK: - Version Info Parsing
    
    /// Device version information
    public struct DeviceInfo {
        public let model: DeviceModel
        public let firmware: String
        public let serial: String
        public let rawVersion: Data
        
        public var description: String {
            return "Mares Device - Model: \(model), Firmware: \(firmware), Serial: \(serial)"
        }
    }
    
    /// Parses version response data into DeviceInfo
    /// - Parameter versionData: Version payload from device
    /// - Returns: DeviceInfo structure
    static func parseDeviceInfo(from versionData: Data) -> DeviceInfo? {
        guard versionData.count >= 8 else { return nil }
        
        // Extract model (this might need adjustment based on actual response format)
        let modelByte = versionData[0]
        let model = DeviceModel(rawValue: modelByte) ?? .puckPro
        
        // Extract firmware version (format may need adjustment)
        let firmware = String(format: "%d.%d", versionData[1], versionData[2])
        
        // Extract serial number (format may need adjustment)
        let serialBytes = versionData.suffix(4)
        let serialNumber = serialBytes.reduce(0) { ($0 << 8) + UInt32($1) }
        let serial = String(serialNumber)
        
        return DeviceInfo(
            model: model,
            firmware: firmware,
            serial: serial,
            rawVersion: versionData
        )
    }
}