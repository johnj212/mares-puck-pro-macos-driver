import Foundation
import ORSSerial

/// Main communicator for Mares Puck Pro dive computer
/// Handles the delicate serial communication with proper RTS control
@MainActor
public class MaresCommunicator: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public private(set) var isConnected = false
    @Published public private(set) var availablePorts: [String] = []
    @Published public private(set) var selectedPort: String?
    @Published public private(set) var deviceInfo: MaresProtocol.DeviceInfo?
    @Published public private(set) var lastError: Error?
    @Published public private(set) var connectionStatus: ConnectionStatus = .disconnected
    
    // MARK: - Connection Status
    
    public enum ConnectionStatus: Equatable {
        case disconnected
        case connecting
        case connected
        case error(Error)
        
        public static func == (lhs: ConnectionStatus, rhs: ConnectionStatus) -> Bool {
            switch (lhs, rhs) {
            case (.disconnected, .disconnected): return true
            case (.connecting, .connecting): return true
            case (.connected, .connected): return true
            case (.error, .error): return true
            default: return false
            }
        }
        
        public var description: String {
            switch self {
            case .disconnected: return "Disconnected"
            case .connecting: return "Connecting..."
            case .connected: return "Connected"
            case .error(let error): return "Error: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Private Properties
    
    private var serialPort: ORSSerialPort?
    private let serialPortManager = ORSSerialPortManager.shared()
    private var responseData = Data()
    private var pendingCommand: ((Data) -> Void)?
    private let commandTimeout: TimeInterval = 3.0  // 3000ms to match Windows log
    private var commandTimer: Timer?
    
    // MARK: - Initialization
    
    public override init() {
        super.init()
        setupSerialPortManager()
        refreshAvailablePorts()
    }
    
    deinit {
        serialPort?.close()
        serialPort = nil
        commandTimer?.invalidate()
    }
    
    // MARK: - Port Management
    
    private func setupSerialPortManager() {
        // Listen for port changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(serialPortsWereConnected(_:)),
            name: .ORSSerialPortsWereConnected,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(serialPortsWereDisconnected(_:)),
            name: .ORSSerialPortsWereDisconnected,
            object: nil
        )
    }
    
    @objc private func serialPortsWereConnected(_ notification: Notification) {
        refreshAvailablePorts()
    }
    
    @objc private func serialPortsWereDisconnected(_ notification: Notification) {
        refreshAvailablePorts()
        
        // Check if our current port was disconnected
        if let currentPath = serialPort?.path,
           !serialPortManager.availablePorts.contains(where: { $0.path == currentPath }) {
            disconnect()
        }
    }
    
    public func refreshAvailablePorts() {
        // Filter for USB serial devices (like CP210x)
        let usbSerialPorts = serialPortManager.availablePorts.filter { port in
            port.path.contains("usbserial") || port.path.contains("usbmodem")
        }
        
        availablePorts = usbSerialPorts.map { $0.path }
    }
    
    // MARK: - Connection Management
    
    /// Connects to the specified serial port with careful RTS handling
    /// - Parameter portPath: Path to the serial port (e.g., "/dev/cu.usbserial-00085C7C")
    public func connect(to portPath: String) async {
        guard !isConnected else { return }
        
        await MainActor.run {
            connectionStatus = .connecting
            selectedPort = portPath
        }
        
        do {
            print("🔌 Creating serial port for: \(portPath)")
            
            // Create and configure the serial port
            guard let port = ORSSerialPort(path: portPath) else {
                print("❌ Failed to create serial port")
                throw MaresProtocol.ProtocolError.deviceNotFound
            }
            
            print("⚙️ Configuring serial parameters...")
            // CRITICAL: Configure serial parameters carefully
            // Based on libdivecomputer log analysis - EXACT settings required
            port.baudRate = 115200  // Changed from 9600 based on log analysis
            port.numberOfDataBits = 8
            port.parity = .even     // Changed from .none - CRITICAL setting from log
            port.numberOfStopBits = 1
            port.usesRTSCTSFlowControl = false  // Disable hardware flow control
            port.usesDTRDSRFlowControl = false  // Disable DTR/DSR flow control
            port.delegate = self
            
            print("📂 Opening port...")
            // Open the port
            port.open()
            
            print("⏱️ Waiting for port to stabilize (0.5s)...")
            // Wait a moment for the port to stabilize
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            print("🚫 Setting RTS=false, DTR=false (CRITICAL for Mares)...")
            // CRITICAL: Clear RTS line as discovered in testing
            // This prevents the device from rebooting
            port.rts = false
            port.dtr = false
            
            print("⏳ Waiting longer for line states (2.0s like Python)...")
            // Wait longer for line states to stabilize (like Python version)
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2.0 seconds
            
            print("🧹 Purging buffers (critical libdivecomputer step)...")
            // Purge both RX and TX buffers (direction=3 from log)
            // ORSSerialPort doesn't have purgeBuffers, but it handles buffer management internally
            // The critical part is the delay and RTS control above
            
            print("✅ Port setup complete - no immediate commands sent")
            self.serialPort = port
            
            // DON'T immediately try to get device info - this causes reboots
            // Just mark as connected and let user manually test communication
            
            await MainActor.run {
                self.isConnected = true
                self.connectionStatus = .connected
            }
            
        } catch {
            await MainActor.run {
                self.lastError = error
                self.connectionStatus = .error(error)
                self.serialPort?.close()
                self.serialPort = nil
            }
        }
    }
    
    /// Disconnects from the current serial port
    public func disconnect() {
        commandTimer?.invalidate()
        commandTimer = nil
        
        serialPort?.close()
        serialPort = nil
        
        isConnected = false
        connectionStatus = .disconnected
        deviceInfo = nil
        selectedPort = nil
        responseData.removeAll()
        pendingCommand = nil
    }
    
    // MARK: - Device Communication
    
    /// Gets device information using CMD_VERSION command
    public func getDeviceInfo() async throws {
        guard isConnected else {
            throw MaresProtocol.ProtocolError.deviceNotFound
        }
        
        print("ℹ️ Requesting device info using CMD_VERSION (C267 command)")
        let command = MaresProtocol.createVersionCommand()
        print("📤 Sending version command: \(command.map { String(format: "%02X", $0) }.joined(separator: " "))")
        
        let response = try await sendCommand(command)
        print("📥 Received response: \(response.count) bytes")
        
        // Parse the response according to Mares protocol
        let parseResult = MaresProtocol.parseResponse(response)
        
        switch parseResult {
        case .success(let payload):
            print("✅ Successfully parsed response payload: \(payload.count) bytes")
            if let info = MaresProtocol.parseDeviceInfo(from: payload) {
                await MainActor.run {
                    self.deviceInfo = info
                }
                print("🎯 Device info: \(info.description)")
            } else {
                print("⚠️ Failed to parse device info from payload")
            }
        case .failure(let error):
            print("❌ Failed to parse response: \(error)")
            throw error
        }
    }
    
    /// Downloads dive data from the device
    public func downloadDives() async throws -> [DiveData] {
        guard isConnected else {
            throw MaresProtocol.ProtocolError.deviceNotFound
        }
        
        print("📊 Starting dive data download...")
        
        // Windows pattern: Stream all memory from 0x012C8 down to 0x001F
        // Parse each 256-byte block to discover dives (no dive count needed)
        print("🌊 Streaming memory blocks to discover dives (like Windows)...")
        
        var dives: [DiveData] = []
        var currentAddress: UInt32 = 0x000112C8  // Start address from Windows log (0x000112C8)
        let endAddress: UInt32 = 0x00000000     // End when we hit bottom of memory
        var diveNumber = 1
        
        while currentAddress >= endAddress {
            print("📦 Reading memory block at 0x\(String(currentAddress, radix: 16, uppercase: true))")
            
            do {
                let response = try await sendMemoryReadCommand(address: currentAddress, length: 256)
                let parseResult = MaresProtocol.parseResponse(response)
                
                switch parseResult {
                case .success(let memoryBlock):
                    // Check if block contains dive data (not all FF)
                    if !isEmptyBlock(memoryBlock) {
                        // Try to parse dive from this memory block
                        if let dive = parseDiveFromMemoryBlock(memoryBlock: memoryBlock, diveNumber: diveNumber, address: currentAddress) {
                            dives.append(dive)
                            print("✅ Found dive \(diveNumber) at address 0x\(String(currentAddress, radix: 16))")
                            diveNumber += 1
                        }
                    }
                    
                case .failure(let error):
                    print("⚠️ Failed to parse memory block at 0x\(String(currentAddress, radix: 16)): \(error)")
                }
                
            } catch {
                print("⚠️ Error reading memory block at 0x\(String(currentAddress, radix: 16)): \(error)")
            }
            
            // Move to next memory block (addresses decrease by 0x0100 = 256)
            if currentAddress >= 0x0100 {
                currentAddress -= 0x0100  // Decrease by 256 bytes
            } else {
                break  // Reached bottom of memory
            }
        }
        
        print("✅ Downloaded \(dives.count) dives successfully")
        return dives
    }
    
    
    /// Checks if memory block is empty (all FF bytes)
    private func isEmptyBlock(_ data: Data) -> Bool {
        // Windows log shows empty blocks as all FF
        let nonFFBytes = data.filter { $0 != 0xFF }
        return nonFFBytes.count < 10  // Allow a few non-FF bytes for noise
    }
    
    /// Parses dive from a 256-byte memory block using real Mares format parsing
    private func parseDiveFromMemoryBlock(memoryBlock: Data, diveNumber: Int, address: UInt32) -> DiveData? {
        print("🔍 Parsing memory block \(memoryBlock.count) bytes at 0x\(String(address, radix: 16))")
        
        // Check if this looks like dive data (has some structure)
        guard !isEmptyBlock(memoryBlock) else {
            print("⚠️ Memory block is empty (all FF), skipping")
            return nil
        }
        
        // Use the new Mares format parsing functions
        guard let diveHeader = MaresProtocol.parseDiveHeader(from: memoryBlock, at: address) else {
            print("⚠️ Could not parse dive header from memory block")
            return nil
        }
        
        print("✅ Parsed dive header: #\(diveHeader.diveNumber), \(diveHeader.duration/60)min, \(diveHeader.maxDepth)m")
        
        // Parse dive samples for profile data
        let diveSamples = MaresProtocol.parseDiveSamples(from: memoryBlock, header: diveHeader)
        print("📊 Extracted \(diveSamples.count) samples from dive")
        
        // Convert protocol samples to DiveProfileSample format
        let profileSamples = diveSamples.map { sample in
            DiveProfileSample(
                time: sample.time,
                depth: sample.depth,
                temperature: sample.temperature
            )
        }
        
        // Calculate average depth from samples
        let averageDepth = profileSamples.isEmpty ? diveHeader.maxDepth * 0.6 : 
                          profileSamples.map(\.depth).reduce(0, +) / Double(profileSamples.count)
        
        // Convert to DiveData format
        return DiveData(
            diveNumber: Int(diveHeader.diveNumber),
            date: diveHeader.date,
            duration: diveHeader.duration,
            maxDepth: diveHeader.maxDepth,
            averageDepth: averageDepth,
            waterType: diveHeader.waterType,
            maxTemperature: diveHeader.maxTemperature,
            minTemperature: diveHeader.minTemperature,
            profileSamples: profileSamples,
            sampleInterval: TimeInterval(diveHeader.sampleInterval)
        )
    }
    
    /// Sends an object-based command and waits for response
    private func sendObjectCommand(_ command: UInt8, data: Data) async throws -> Data {
        guard let port = serialPort, port.isOpen else {
            throw MaresProtocol.ProtocolError.deviceNotFound
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            // Clear any existing response data
            responseData.removeAll()
            
            // Set up response handler
            pendingCommand = { responseData in
                continuation.resume(returning: responseData)
            }
            
            // Set up timeout
            commandTimer = Timer.scheduledTimer(withTimeInterval: commandTimeout, repeats: false) { _ in
                Task { @MainActor in
                    self.pendingCommand = nil
                }
                continuation.resume(throwing: MaresProtocol.ProtocolError.communicationTimeout)
            }
            
            // Create the command with Mares encoding (XOR)
            let mareCommand = Data([command, command ^ MaresProtocol.XOR])
            
            // Send command header first
            port.send(mareCommand)
            
            // Send data payload if provided
            if !data.isEmpty {
                port.send(data)
            }
        }
    }
    
    /// Reads multi-packet object data using even/odd commands
    private func readObjectData(objectInfo: MaresProtocol.ObjectInfo) async throws -> Data {
        print("📦 Reading multi-packet object data: \(objectInfo.size) bytes")
        
        var allData = Data()
        var isEvenPacket = true
        let maxPacketSize: UInt32 = 504  // From libdivecomputer
        
        var bytesRemaining = objectInfo.size
        
        while bytesRemaining > 0 {
            let command = isEvenPacket ? MaresProtocol.CMD_OBJ_EVEN : MaresProtocol.CMD_OBJ_ODD
            print("📤 Sending \(isEvenPacket ? "even" : "odd") packet command")
            
            let response = try await sendObjectCommand(command, data: Data())
            let parseResult = MaresProtocol.parseResponse(response)
            
            switch parseResult {
            case .success(let payload):
                print("📥 Got \(payload.count) bytes in packet")
                allData.append(payload)
                
                let payloadSize = UInt32(payload.count)
                if payloadSize <= bytesRemaining {
                    bytesRemaining -= payloadSize
                } else {
                    bytesRemaining = 0
                }
                
                // If we got less than max packet size, we're done
                if payloadSize < maxPacketSize {
                    break
                }
                
                isEvenPacket.toggle()
                
            case .failure(let error):
                print("❌ Failed to read object packet: \(error)")
                throw error
            }
        }
        
        print("✅ Completed object read: \(allData.count) bytes")
        return allData
    }
    
    
    // MARK: - Low-level Communication
    
    /// Sends memory read command using Windows log pattern: E742 + 8-byte address
    private func sendMemoryReadCommand(address: UInt32, length: UInt32) async throws -> Data {
        guard let port = serialPort, port.isOpen else {
            throw MaresProtocol.ProtocolError.deviceNotFound
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            // Clear any existing response data
            responseData.removeAll()
            
            // Set up response handler
            pendingCommand = { responseData in
                continuation.resume(returning: responseData)
            }
            
            // Set up timeout
            commandTimer = Timer.scheduledTimer(withTimeInterval: commandTimeout, repeats: false) { _ in
                Task { @MainActor in
                    self.pendingCommand = nil
                }
                continuation.resume(throwing: MaresProtocol.ProtocolError.communicationTimeout)
            }
            
            // Windows log pattern: Send E742 command first
            let command = Data([MaresProtocol.CMD_READ, MaresProtocol.CMD_READ ^ MaresProtocol.XOR])  // E742
            print("📤 Sending E742 command: \(command.map { String(format: "%02X", $0) }.joined(separator: " "))")
            port.send(command)
            
            // Windows pattern analysis:
            // 0C00000004000000 = address 0x0C (C8 12 01 00), length 4 (04 00 00 00)
            // C812010000010000 = address 0x000112C8 (C8 12 01 00), length 256 (00 01 00 00)
            var addressData = Data()
            addressData.append(UInt8(address & 0xFF))           // address byte 0 (low)
            addressData.append(UInt8((address >> 8) & 0xFF))    // address byte 1
            addressData.append(UInt8((address >> 16) & 0xFF))   // address byte 2  
            addressData.append(UInt8((address >> 24) & 0xFF))   // address byte 3 (high)
            addressData.append(UInt8(length & 0xFF))            // length byte 0 (low)
            addressData.append(UInt8((length >> 8) & 0xFF))     // length byte 1
            addressData.append(UInt8((length >> 16) & 0xFF))    // length byte 2
            addressData.append(UInt8((length >> 24) & 0xFF))    // length byte 3 (high)
            
            print("📤 Sending address data: \(addressData.map { String(format: "%02X", $0) }.joined(separator: " "))")
            port.send(addressData)
        }
    }
    
    private func sendCommand(_ command: Data) async throws -> Data {
        guard let port = serialPort, port.isOpen else {
            throw MaresProtocol.ProtocolError.deviceNotFound
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            // Clear any existing response data
            responseData.removeAll()
            
            // Set up response handler
            pendingCommand = { responseData in
                continuation.resume(returning: responseData)
            }
            
            // Set up timeout
            commandTimer = Timer.scheduledTimer(withTimeInterval: commandTimeout, repeats: false) { _ in
                Task { @MainActor in
                    self.pendingCommand = nil
                }
                continuation.resume(throwing: MaresProtocol.ProtocolError.communicationTimeout)
            }
            
            // Send the command
            port.send(command)
        }
    }
}

// MARK: - ORSSerialPortDelegate

extension MaresCommunicator: ORSSerialPortDelegate {
    
    nonisolated public func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
        Task { @MainActor in
            responseData.append(data)
            
            // Check if we have a complete Mares protocol response
            // A complete response should end with MaresProtocol.END (0xEA)
            if let lastByte = responseData.last, lastByte == MaresProtocol.END {
                // We have a complete response
                commandTimer?.invalidate()
                commandTimer = nil
                
                let response = responseData
                responseData.removeAll()
                
                pendingCommand?(response)
                pendingCommand = nil
            }
        }
    }
    
    nonisolated public func serialPortWasOpened(_ serialPort: ORSSerialPort) {
        print("Serial port opened: \(serialPort.path)")
    }
    
    nonisolated public func serialPortWasClosed(_ serialPort: ORSSerialPort) {
        print("Serial port closed: \(serialPort.path)")
    }
    
    nonisolated public func serialPort(_ serialPort: ORSSerialPort, didEncounterError error: Error) {
        print("Serial port error: \(error.localizedDescription)")
        Task { @MainActor in
            self.lastError = error
            self.connectionStatus = .error(error)
        }
    }
    
    nonisolated public func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort) {
        print("Serial port removed: \(serialPort.path)")
        Task { @MainActor in
            self.disconnect()
        }
    }
}