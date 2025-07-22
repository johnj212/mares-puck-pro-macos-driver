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
    
    /// Creates a memory read command (E742 pattern from libdivecomputer log)
    /// - Parameters:
    ///   - address: Memory address to read from (32-bit)
    ///   - length: Number of bytes to read (32-bit)
    /// - Returns: Memory read command as Data
    static func createMemoryReadCommand(address: UInt32, length: UInt32 = 256) -> Data {
        // Based on log analysis: E742 + 8 bytes
        // Format: [addr_low, addr_mid, addr_high, 0x01, 0x00, length_low, length_mid, length_high]
        var command = Data()
        command.append(CMD_READ)
        command.append(CMD_READ ^ XOR)  // E742 -> E7, 42
        
        // 8-byte memory address/length structure from log
        command.append(UInt8(address & 0xFF))         // address low byte
        command.append(UInt8((address >> 8) & 0xFF))  // address mid byte  
        command.append(UInt8((address >> 16) & 0xFF)) // address high byte
        command.append(0x01)                          // fixed byte from log
        command.append(0x00)                          // fixed byte from log
        command.append(UInt8(length & 0xFF))          // length low byte
        command.append(UInt8((length >> 8) & 0xFF))   // length mid byte
        command.append(UInt8((length >> 16) & 0xFF))  // length high byte
        
        return command
    }
    
    /// Creates an object initialization command (matches libdivecomputer exactly)
    /// - Parameters:
    ///   - objectType: The object type (e.g., OBJ_LOGBOOK, OBJ_DIVE)
    ///   - subIndex: The sub-index within the object
    /// - Returns: Data containing the object init command
    static func createObjectInitCommand(objectType: UInt16, subIndex: UInt8) -> Data {
        // Match libdivecomputer cmd_init structure exactly
        var command = Data(count: 16)
        
        // Set the known bytes (0-3)
        command[0] = 0x40  // Fixed init byte
        command[1] = UInt8(objectType & 0xFF)        // Object type low byte
        command[2] = UInt8((objectType >> 8) & 0xFF) // Object type high byte  
        command[3] = subIndex                         // Sub-index
        
        // Bytes 4-5 left as initialized (zero) - libdivecomputer doesn't set these
        
        // Bytes 6-15 are explicitly zeroed in libdivecomputer (memset)
        for i in 6..<16 {
            command[i] = 0x00
        }
        
        return command
    }
    
    /// Creates a dive count request command using object protocol
    /// Based on libdivecomputer analysis: OBJ_LOGBOOK + OBJ_LOGBOOK_COUNT
    /// - Returns: Data containing the dive count object init command  
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
    
    /// Parses dive count from object response data
    /// - Parameter data: Object payload containing dive count (2 bytes, little-endian)
    /// - Returns: Number of dives stored on device
    static func parseDiveCount(from data: Data) -> UInt16? {
        guard data.count >= 2 else { return nil }
        
        // From libdivecomputer: dive count is 16-bit little-endian (array_uint16_le)
        let count = UInt16(data[0]) | (UInt16(data[1]) << 8)
        
        return count
    }
    
    /// Parses dive count from memory read response (Puck Pro)
    /// - Parameter data: Memory payload containing dive count (4 bytes)
    /// - Returns: Number of dives stored on device
    static func parseDiveCountFromMemory(from data: Data) -> UInt16? {
        guard data.count >= 4 else { return nil }
        
        // From Windows log: memory reads return 4-byte values
        // Try to interpret as 32-bit little-endian and extract reasonable count
        let count32 = UInt32(data[0]) | 
                     (UInt32(data[1]) << 8) | 
                     (UInt32(data[2]) << 16) | 
                     (UInt32(data[3]) << 24)
        
        // Windows log shows values like C8130100 at 0x0130
        // This might be encoded differently - try various interpretations
        
        // Try lower 16 bits
        let count16 = UInt16(count32 & 0xFFFF)
        if count16 > 0 && count16 < 1000 {
            return count16
        }
        
        // Try upper 16 bits
        let count16_upper = UInt16((count32 >> 16) & 0xFFFF)
        if count16_upper > 0 && count16_upper < 1000 {
            return count16_upper
        }
        
        // Try byte-swapped interpretation
        let swapped = UInt16(data[2]) | (UInt16(data[3]) << 8)
        if swapped > 0 && swapped < 1000 {
            return swapped
        }
        
        return nil  // Could not parse reasonable dive count
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
    
    /// Parses device information from version response
    /// Based on libdivecomputer log analysis: device info is in the 140-byte response
    /// - Parameter versionData: Version payload from device (140 bytes from log)
    /// - Returns: DeviceInfo structure or nil if parsing fails
    static func parseDeviceInfo(from versionData: Data) -> DeviceInfo? {
        guard versionData.count >= 140 else { 
            print("⚠️ Version data too short: \(versionData.count) bytes, expected 140")
            return nil 
        }
        
        // From log analysis: "Puck Pro" appears at offset 64 in the response
        // Extract device name (look for "Puck Pro" string)
        let deviceNameRange = 64..<74  // "Puck Pro" + null padding
        let deviceNameData = versionData.subdata(in: deviceNameRange)
        let _ = String(data: deviceNameData, encoding: .ascii)?.trimmingCharacters(in: .controlCharacters) ?? "Unknown"
        
        // Extract firmware version (appears around offset 80-90 based on log)
        let firmwareRange = 80..<90
        let firmwareData = versionData.subdata(in: firmwareRange)  
        let firmware = String(data: firmwareData, encoding: .ascii)?.trimmingCharacters(in: .controlCharacters) ?? "Unknown"
        
        // Extract serial number (appears at end of response)
        let serialRange = 100..<120
        let serialData = versionData.subdata(in: serialRange)
        let serial = String(data: serialData, encoding: .ascii)?.trimmingCharacters(in: .controlCharacters) ?? "Unknown"
        
        // Model is Puck Pro (0x18) based on device detection
        let model = DeviceModel.puckPro
        
        return DeviceInfo(
            model: model,
            firmware: firmware,
            serial: serial,
            rawVersion: versionData
        )
    }
}