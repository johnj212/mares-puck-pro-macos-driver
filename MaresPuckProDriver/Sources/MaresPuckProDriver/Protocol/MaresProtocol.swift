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
    
    // MARK: - Object-based Protocol Commands (for newer devices like Puck Pro)
    
    /// Object initialization command
    static let CMD_OBJ_INIT: UInt8 = 0xBF
    
    /// Object data reading commands (even/odd packets)
    static let CMD_OBJ_EVEN: UInt8 = 0xAC
    static let CMD_OBJ_ODD: UInt8 = 0xFE
    
    // MARK: - Object Types and Subindices
    
    /// Device object type
    static let OBJ_DEVICE: UInt16 = 0x2000
    static let OBJ_DEVICE_MODEL: UInt8 = 0x02
    static let OBJ_DEVICE_SERIAL: UInt8 = 0x04
    
    /// Logbook object type
    static let OBJ_LOGBOOK: UInt16 = 0x2008
    static let OBJ_LOGBOOK_COUNT: UInt8 = 0x01
    
    /// Dive object type
    static let OBJ_DIVE: UInt16 = 0x3000
    static let OBJ_DIVE_HEADER: UInt8 = 0x02
    static let OBJ_DIVE_DATA: UInt8 = 0x03
    
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
    
    /// Creates an object initialization command
    /// - Parameters:
    ///   - objectType: The object type (e.g., OBJ_LOGBOOK, OBJ_DIVE)
    ///   - subIndex: The sub-index within the object
    /// - Returns: Data containing the object init command
    static func createObjectInitCommand(objectType: UInt16, subIndex: UInt8) -> Data {
        var command = Data(capacity: 16)
        command.append(0x40)  // Fixed init byte
        command.append(UInt8(objectType & 0xFF))        // Object type low byte
        command.append(UInt8((objectType >> 8) & 0xFF)) // Object type high byte  
        command.append(subIndex)                         // Sub-index
        
        // Pad to 16 bytes with zeros (as per libdivecomputer)
        while command.count < 16 {
            command.append(0x00)
        }
        
        return command
    }
    
    /// Creates a dive count request command
    /// - Returns: Data containing the dive count command
    static func createDiveCountCommand() -> Data {
        return createObjectInitCommand(objectType: OBJ_LOGBOOK, subIndex: OBJ_LOGBOOK_COUNT)
    }
    
    /// Creates a dive header request command
    /// - Parameter diveIndex: Index of the dive (0-based)
    /// - Returns: Data containing the dive header command
    static func createDiveHeaderCommand(diveIndex: UInt16) -> Data {
        return createObjectInitCommand(objectType: OBJ_DIVE + diveIndex, subIndex: OBJ_DIVE_HEADER)
    }
    
    /// Creates a dive data request command
    /// - Parameter diveIndex: Index of the dive (0-based)
    /// - Returns: Data containing the dive data command
    static func createDiveDataCommand(diveIndex: UInt16) -> Data {
        return createObjectInitCommand(objectType: OBJ_DIVE + diveIndex, subIndex: OBJ_DIVE_DATA)
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
    
    /// Parses object initialization response
    /// - Parameter data: Raw response data from object init command
    /// - Returns: Object info (size, type, etc.) or error
    static func parseObjectInitResponse(_ data: Data) -> Result<ObjectInfo, ProtocolError> {
        guard data.count >= 16 else {
            return .failure(.invalidResponse)
        }
        
        let responseType = data[0]
        let objectType = UInt16(data[1]) | (UInt16(data[2]) << 8)
        let subIndex = data[3]
        
        if responseType == 0x41 {
            // Large payload split into multiple packets
            // Size is in bytes 4-7
            let size = UInt32(data[4]) | 
                      (UInt32(data[5]) << 8) | 
                      (UInt32(data[6]) << 16) | 
                      (UInt32(data[7]) << 24)
            return .success(ObjectInfo(type: objectType, subIndex: subIndex, size: size, isMultiPacket: true))
        } else if responseType == 0x42 {
            // Small payload embedded in response
            let payloadSize = data.count - 4  // Skip header bytes
            let payload = data.dropFirst(4)
            return .success(ObjectInfo(type: objectType, subIndex: subIndex, size: UInt32(payloadSize), isMultiPacket: false, payload: payload))
        } else {
            return .failure(.unexpectedHeader(responseType))
        }
    }
    
    /// Object information from init response
    public struct ObjectInfo {
        public let type: UInt16
        public let subIndex: UInt8
        public let size: UInt32
        public let isMultiPacket: Bool
        public let payload: Data?
        
        public init(type: UInt16, subIndex: UInt8, size: UInt32, isMultiPacket: Bool, payload: Data? = nil) {
            self.type = type
            self.subIndex = subIndex
            self.size = size
            self.isMultiPacket = isMultiPacket
            self.payload = payload
        }
    }
    
    /// Parses dive count from logbook response
    /// - Parameter data: Logbook count payload
    /// - Returns: Number of dives stored on device
    static func parseDiveCount(from data: Data) -> UInt16? {
        guard data.count >= 2 else { return nil }
        
        // Dive count is stored as little-endian 16-bit value
        return UInt16(data[0]) | (UInt16(data[1]) << 8)
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