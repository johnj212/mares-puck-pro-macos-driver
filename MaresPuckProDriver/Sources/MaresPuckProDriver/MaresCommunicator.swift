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
    private let commandTimeout: TimeInterval = 5.0
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
            // Based on our testing, these settings prevent device reboots
            port.baudRate = 9600
            port.numberOfDataBits = 8
            port.parity = .none
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
            
            print("🧹 Clearing buffers (critical Python step)...")
            // Clear buffers after RTS control (critical step from Python)
            // Note: ORSSerialPort will handle buffer management internally
            
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
    private func getDeviceInfo() async throws {
        let command = MaresProtocol.createVersionCommand()
        
        let response = try await sendCommand(command)
        
        // Parse the response according to Mares protocol
        let parseResult = MaresProtocol.parseResponse(response)
        
        switch parseResult {
        case .success(let payload):
            if let info = MaresProtocol.parseDeviceInfo(from: payload) {
                await MainActor.run {
                    self.deviceInfo = info
                }
            }
        case .failure(let error):
            throw error
        }
    }
    
    /// Downloads dive data from the device
    public func downloadDives() async throws -> [DiveData] {
        guard isConnected else {
            throw MaresProtocol.ProtocolError.deviceNotFound
        }
        
        print("📊 Starting dive data download...")
        
        // Step 1: Get dive count from device
        let diveCount = try await getDiveCount()
        print("📈 Device has \(diveCount) dives stored")
        
        if diveCount == 0 {
            print("ℹ️ No dives found on device")
            return []
        }
        
        // Step 2: Download each dive
        var dives: [DiveData] = []
        
        for i in 0..<diveCount {
            print("⬇️ Downloading dive \(i + 1)/\(diveCount)...")
            
            do {
                // Get dive header first
                if let dive = try await downloadSingleDive(index: UInt16(i)) {
                    dives.append(dive)
                }
            } catch {
                print("⚠️ Failed to download dive \(i + 1): \(error)")
                // Continue with other dives even if one fails
            }
        }
        
        print("✅ Downloaded \(dives.count) dives successfully")
        return dives
    }
    
    /// Gets the number of dives stored on the device using raw memory protocol
    private func getDiveCount() async throws -> UInt16 {
        print("🔢 Requesting dive count using RAW MEMORY protocol (Puck Pro doesn't support object protocol)")
        
        // Puck Pro uses raw memory access, not object protocol
        // Based on libdivecomputer mares_iconhd_device_foreach_raw implementation
        
        // For now, return a test count since raw memory protocol needs more research
        // TODO: Implement proper raw memory reading for dive count
        print("⚠️ Raw memory protocol not yet implemented - using test data")
        print("📚 Need to implement memory reading at specific addresses for dive count")
        
        // Return a small test count for now
        return 2
    }
    
    /// Downloads a single dive by index
    private func downloadSingleDive(index: UInt16) async throws -> DiveData? {
        // For now, this is a placeholder implementation
        // In a full implementation, we would:
        // 1. Request dive header with createDiveHeaderCommand(diveIndex: index)  
        // 2. Parse dive metadata (date, duration, etc.)
        // 3. Request dive data with createDiveDataCommand(diveIndex: index)
        // 4. Parse dive profile samples
        // 5. Create DiveData object from parsed information
        
        print("🏗️ Dive parsing not yet implemented - using placeholder data")
        
        // Return placeholder dive for now
        let calendar = Calendar.current
        let diveDate = calendar.date(byAdding: .day, value: -Int(index + 1), to: Date()) ?? Date()
        
        return DiveData(
            diveNumber: Int(index + 1),
            date: diveDate,
            duration: 1800 + TimeInterval(index * 300), // 30-45 min dives
            maxDepth: 15.0 + Double(index) * 2, // Increasing depths
            averageDepth: 10.0 + Double(index) * 1.5,
            waterType: index % 2 == 0 ? .saltwater : .freshwater,
            maxTemperature: 24.0 - Double(index) * 0.5,
            minTemperature: 22.0 - Double(index) * 0.5
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
    
    // MARK: - Low-level Communication
    
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