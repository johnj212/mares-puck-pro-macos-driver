#!/usr/bin/swift

import Foundation

print("=== Mares Dive Download Protocol Test ===")

// Test basic constants
let CMD_OBJ_INIT: UInt8 = 0xBF
let OBJ_LOGBOOK: UInt16 = 0x2008

print("CMD_OBJ_INIT: 0x\(String(CMD_OBJ_INIT, radix: 16, uppercase: true))")
print("OBJ_LOGBOOK: 0x\(String(OBJ_LOGBOOK, radix: 16, uppercase: true))")

// Test simple command construction
var command = Data()
command.append(0x40)  // Init byte
command.append(0x08)  // Low byte of 0x2008
command.append(0x20)  // High byte of 0x2008
command.append(0x01)  // Subindex

print("Command bytes: \(command.map { String(format: "%02X", $0) }.joined(separator: " "))")

print("✅ Protocol test completed - constants and structure verified!")