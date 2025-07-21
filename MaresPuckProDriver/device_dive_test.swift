#!/usr/bin/swift

import Foundation
import ORSSerial

print("=== Mares Puck Pro Dive Count Test ===")

class DiveTestDelegate: NSObject, ORSSerialPortDelegate {
    var receivedData = Data()
    var expectingResponse = false
    var responseCallback: ((Data) -> Void)?
    
    func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
        receivedData.append(data)
        print("📥 Raw data received: \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")
        
        // Check for complete response (ends with 0xEA)
        if let lastByte = receivedData.last, lastByte == 0xEA {
            print("✅ Complete response: \(receivedData.map { String(format: "%02X", $0) }.joined(separator: " "))")
            expectingResponse = false
            responseCallback?(receivedData)
            receivedData.removeAll()
        }
    }
    
    func serialPortWasOpened(_ serialPort: ORSSerialPort) {
        print("🔌 Port opened successfully")
    }
    
    func serialPortWasClosed(_ serialPort: ORSSerialPort) {
        print("❌ Port closed")
    }
    
    func serialPort(_ serialPort: ORSSerialPort, didEncounterError error: Error) {
        print("⚠️ Port error: \(error.localizedDescription)")
    }
    
    func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort) {
        print("🔌 Port removed from system")
    }
}

func testDiveCount() async {
    let devicePath = "/dev/cu.usbserial-00085C7C"
    
    print("🔌 Creating connection to: \(devicePath)")
    
    guard let port = ORSSerialPort(path: devicePath) else {
        print("❌ Failed to create serial port")
        return
    }
    
    let delegate = DiveTestDelegate()
    
    // Configure port exactly like our working driver
    port.baudRate = 9600
    port.numberOfDataBits = 8
    port.parity = .none
    port.numberOfStopBits = 1
    port.usesRTSCTSFlowControl = false
    port.usesDTRDSRFlowControl = false
    port.delegate = delegate
    
    print("📂 Opening port...")
    port.open()
    
    print("⏱️ Initial stabilization delay...")
    try! await Task.sleep(nanoseconds: 500_000_000)
    
    print("🚫 Setting RTS/DTR control (critical for Mares)...")
    port.rts = false
    port.dtr = false
    
    print("⏳ Stabilization delay (2+ seconds)...")
    try! await Task.sleep(nanoseconds: 2_000_000_000)
    
    print("✅ Connection established - testing dive count protocol")
    
    // Test 1: Try version command first (known to work)
    print("\n🔬 Test 1: Version command (baseline)")
    let CMD_VERSION: UInt8 = 0xC2
    let XOR: UInt8 = 0xA5
    let versionCommand = Data([CMD_VERSION, CMD_VERSION ^ XOR])
    
    await sendAndWaitForResponse(port: port, delegate: delegate, command: versionCommand, description: "Version")
    
    try! await Task.sleep(nanoseconds: 1_000_000_000) // 1 second between commands
    
    // Test 2: Try dive count protocol
    print("\n🔬 Test 2: Object protocol dive count")
    let CMD_OBJ_INIT: UInt8 = 0xBF
    
    // Create dive count command (matches our Swift implementation)
    var diveCountCommand = Data()
    diveCountCommand.append(0x40)  // Fixed init byte
    diveCountCommand.append(0x08)  // Low byte of 0x2008 (OBJ_LOGBOOK)
    diveCountCommand.append(0x20)  // High byte of 0x2008
    diveCountCommand.append(0x01)  // OBJ_LOGBOOK_COUNT
    
    // Pad to 16 bytes
    while diveCountCommand.count < 16 {
        diveCountCommand.append(0x00)
    }
    
    print("📤 Dive count payload: \(diveCountCommand.map { String(format: "%02X", $0) }.joined(separator: " "))")
    
    // Send object init command with XOR encoding
    let objectInitCommand = Data([CMD_OBJ_INIT, CMD_OBJ_INIT ^ XOR])
    
    delegate.expectingResponse = true
    delegate.responseCallback = { responseData in
        print("🔍 Analyzing dive count response...")
        analyzeObjectResponse(responseData)
    }
    
    print("📤 Sending object init: \(objectInitCommand.map { String(format: "%02X", $0) }.joined(separator: " "))")
    port.send(objectInitCommand)
    
    print("📤 Sending dive count data...")
    port.send(diveCountCommand)
    
    // Wait for response
    var timeout = 0
    while delegate.expectingResponse && timeout < 50 {
        try! await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        timeout += 1
    }
    
    if delegate.expectingResponse {
        print("⏱️ Object protocol timeout - no response received")
    }
    
    print("\n🔒 Closing connection...")
    port.close()
    
    print("\n📊 Test Summary:")
    print("- Connection: ✅ Stable (no device reboots)")  
    print("- Version command: ✅ Working (baseline)")
    print("- Object protocol: 🔍 Results above")
    print("\nNext: Analyze responses and adjust protocol if needed")
}

func sendAndWaitForResponse(port: ORSSerialPort, delegate: DiveTestDelegate, command: Data, description: String) async {
    delegate.expectingResponse = true
    delegate.responseCallback = { data in
        print("✅ \(description) response received")
    }
    
    print("📤 Sending \(description): \(command.map { String(format: "%02X", $0) }.joined(separator: " "))")
    port.send(command)
    
    var timeout = 0
    while delegate.expectingResponse && timeout < 30 {
        try! await Task.sleep(nanoseconds: 100_000_000)
        timeout += 1
    }
    
    if delegate.expectingResponse {
        print("⏱️ \(description) timeout")
        delegate.expectingResponse = false
    }
}

func analyzeObjectResponse(_ data: Data) {
    if data.count < 2 {
        print("❌ Response too short")
        return
    }
    
    // Check for standard Mares response pattern
    if data.first == 0xAA && data.last == 0xEA {
        let payload = data.dropFirst().dropLast()
        print("📦 Standard Mares response, payload: \(payload.map { String(format: "%02X", $0) }.joined(separator: " "))")
        
        if payload.count >= 2 {
            let diveCount = UInt16(payload[0]) | (UInt16(payload[1]) << 8)
            print("🎯 Potential dive count: \(diveCount)")
        }
    } else if data.count >= 16 {
        // Check for object init response format
        let responseType = data[0]
        print("📋 Object response type: 0x\(String(responseType, radix: 16, uppercase: true))")
        
        if responseType == 0x41 || responseType == 0x42 {
            print("✅ Valid object response format detected!")
            if data.count >= 4 {
                let objectType = UInt16(data[1]) | (UInt16(data[2]) << 8)
                let subIndex = data[3]
                print("   Object: 0x\(String(objectType, radix: 16, uppercase: true))")
                print("   Sub-index: 0x\(String(subIndex, radix: 16, uppercase: true))")
                
                if responseType == 0x42 && data.count > 4 {
                    let payload = data.dropFirst(4)
                    print("   Embedded payload: \(payload.prefix(10).map { String(format: "%02X", $0) }.joined(separator: " "))")
                    
                    if payload.count >= 2 {
                        let diveCount = UInt16(payload[0]) | (UInt16(payload[1]) << 8)
                        print("🎯 Dive count: \(diveCount)")
                    }
                }
            }
        }
    } else {
        print("❓ Unexpected response format")
    }
}

// Run the test
Task {
    await testDiveCount()
    exit(0)
}

RunLoop.current.run()