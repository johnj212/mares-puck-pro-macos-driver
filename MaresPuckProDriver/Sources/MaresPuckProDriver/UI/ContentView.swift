import SwiftUI

/// Main application view for Mares Puck Pro Driver
public struct ContentView: View {
    @StateObject private var communicator = MaresCommunicator()
    @State private var showingDiveDetail = false
    @State private var selectedDive: DiveData?
    @State private var diveData: [DiveData] = []
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView {
            // Sidebar - Connection and Device Info
            VStack(alignment: .leading, spacing: 16) {
                connectionSection
                deviceInfoSection
                portSelectionSection
                Spacer()
            }
            .padding()
            .frame(minWidth: 300)
            
        } detail: {
            // Main content - Dive data
            if diveData.isEmpty {
                welcomeView
            } else {
                diveListView
            }
        }
        .navigationTitle("Mares Puck Pro Driver")
        .task {
            communicator.refreshAvailablePorts()
        }
    }
    
    // MARK: - Connection Section
    
    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: connectionStatusIcon)
                    .foregroundColor(connectionStatusColor)
                Text("Connection Status")
                    .font(.headline)
            }
            
            Text(communicator.connectionStatus.description)
                .foregroundColor(.secondary)
            
            if communicator.isConnected {
                Button("Disconnect") {
                    Task {
                        communicator.disconnect()
                    }
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    // MARK: - Device Info Section
    
    private var deviceInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle")
                Text("Device Information")
                    .font(.headline)
            }
            
            if let deviceInfo = communicator.deviceInfo {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Model: \(deviceInfo.model)")
                    Text("Firmware: \(deviceInfo.firmware)")
                    Text("Serial: \(deviceInfo.serial)")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            } else {
                Text("No device connected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Port Selection Section
    
    private var portSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "cable.connector")
                Text("Serial Port")
                    .font(.headline)
            }
            
            if communicator.availablePorts.isEmpty {
                Text("No USB serial devices found")
                    .font(.caption)
                    .foregroundColor(.orange)
            } else {
                Picker("Port", selection: Binding<String?>(
                    get: { communicator.selectedPort },
                    set: { _ in }
                )) {
                    Text("Select Port...").tag(nil as String?)
                    ForEach(communicator.availablePorts, id: \.self) { port in
                        Text(portDisplayName(port)).tag(port as String?)
                    }
                }
                .pickerStyle(.menu)
                
                if !communicator.isConnected {
                    Button("Connect") {
                        Task {
                            if let selectedPort = communicator.availablePorts.first {
                                await communicator.connect(to: selectedPort)
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(communicator.availablePorts.isEmpty || communicator.connectionStatus == .connecting)
                }
            }
            
            Button("Refresh Ports") {
                communicator.refreshAvailablePorts()
            }
            .buttonStyle(.bordered)
        }
    }
    
    // MARK: - Welcome View
    
    private var welcomeView: some View {
        VStack(spacing: 20) {
            Image(systemName: "water.waves")
                .font(.system(size: 64))
                .foregroundColor(.blue)
            
            Text("Mares Puck Pro Driver")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Connect your Mares Puck Pro dive computer to download and view your dive data.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            if communicator.isConnected {
                VStack(spacing: 12) {
                    Button("Download Dives") {
                        Task {
                            await downloadDives()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Text("Ready to download dive data from your Puck Pro")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(spacing: 8) {
                    Text("1. Connect your Mares Puck Pro with USB cable")
                    Text("2. Ensure device shows 'PC ready'")
                    Text("3. Select the port and click Connect")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Dive List View
    
    private var diveListView: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Downloaded Dives")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Download More") {
                    Task {
                        await downloadDives()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(!communicator.isConnected)
            }
            .padding()
            
            List(diveData) { dive in
                DiveRowView(dive: dive)
                    .onTapGesture {
                        selectedDive = dive
                        showingDiveDetail = true
                    }
            }
        }
        .sheet(isPresented: $showingDiveDetail) {
            if let dive = selectedDive {
                DiveDetailView(dive: dive)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private var connectionStatusIcon: String {
        switch communicator.connectionStatus {
        case .disconnected: return "circle"
        case .connecting: return "circle.dotted"
        case .connected: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
    
    private var connectionStatusColor: Color {
        switch communicator.connectionStatus {
        case .disconnected: return .gray
        case .connecting: return .orange
        case .connected: return .green
        case .error: return .red
        }
    }
    
    private func portDisplayName(_ port: String) -> String {
        if port.contains("usbserial") {
            return "USB Serial (\(port.split(separator: "-").last ?? ""))"
        }
        return port.split(separator: "/").last.map(String.init) ?? port
    }
    
    private func downloadDives() async {
        do {
            let _ = try await communicator.downloadDives()
            await MainActor.run {
                // For now, add sample data since full implementation would require
                // complete protocol reverse engineering
                if diveData.isEmpty {
                    diveData = createSampleDiveData()
                }
            }
        } catch {
            print("Error downloading dives: \(error)")
        }
    }
    
    private func createSampleDiveData() -> [DiveData] {
        // Sample data for demonstration
        return [
            DiveData(
                diveNumber: 1,
                date: Date().addingTimeInterval(-86400),
                duration: 2340, // 39 minutes
                maxDepth: 18.5,
                averageDepth: 12.3,
                waterType: .saltwater,
                maxTemperature: 24.5,
                minTemperature: 22.1
            ),
            DiveData(
                diveNumber: 2,
                date: Date().addingTimeInterval(-172800),
                duration: 1980, // 33 minutes
                maxDepth: 15.2,
                averageDepth: 9.8,
                waterType: .saltwater,
                maxTemperature: 25.0,
                minTemperature: 23.5
            )
        ]
    }
}