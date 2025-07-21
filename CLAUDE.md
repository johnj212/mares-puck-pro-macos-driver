# Mares Puck Pro macOS Driver Development

## Project Overview
✅ **COMPLETED**: Native macOS application to communicate with the Mares Puck Pro dive computer via USB. This is NOT a kernel driver project - the Puck Pro uses a USB-to-serial converter that appears as a virtual COM port on macOS.

## Implementation Status

### ✅ COMPLETED FEATURES

#### Core Architecture
- ✅ Native Swift Package with SwiftUI interface (macOS 13.0+)
- ✅ ORSSerialPort integration for reliable serial communication
- ✅ User-space application architecture (no kernel extensions)
- ✅ Proper project structure with separate modules

#### Communication Protocol
- ✅ Mares IconHD protocol implementation
- ✅ Protocol constants and command structures
- ✅ XOR command encoding: `[CMD, CMD^0xA5]`
- ✅ Response parsing: `[0xAA, data..., 0xEA]`
- ✅ Version command (CMD_VERSION: 0xC2) implemented
- ✅ **CRITICAL**: Fixed device reboot issues with proper RTS/DTR control

#### Device Connection
- ✅ Serial port enumeration and detection
- ✅ USB-to-serial device filtering (CP210x support)
- ✅ Connection state management (disconnected/connecting/connected/error)
- ✅ **FIXED**: Proper RTS=false, DTR=false line control prevents reboots
- ✅ Longer stabilization delays (2+ seconds) matching Python success
- ✅ Error handling and connection status feedback
- ✅ Delegate pattern for serial events

#### User Interface
- ✅ Native SwiftUI macOS application
- ✅ Connection panel with port selection
- ✅ Device information display
- ✅ Dive list interface with detailed dive rows
- ✅ Individual dive detail views
- ✅ Connection status indicators
- ✅ NavigationSplitView for modern macOS design

#### Data Models
- ✅ Complete DiveData structure
- ✅ Water type enumeration (saltwater/freshwater)
- ✅ Temperature, depth, duration formatting
- ✅ Dive profile samples structure
- ✅ Decompression stop tracking
- ✅ Identifiable for SwiftUI lists

#### Testing & Validation
- ✅ Unit tests for protocol and data models
- ✅ Simple protocol test script confirms functionality  
- ✅ Device communication tested (connection without reboots)
- ✅ Build system working correctly

#### Documentation & Distribution
- ✅ Comprehensive README with installation instructions
- ✅ GitHub repository with proper .gitignore
- ✅ Protocol documentation and technical details
- ✅ User guide for device setup

### 🔄 PLACEHOLDER IMPLEMENTATIONS

#### Data Download (Major Gap)
- ⚠️ `downloadDives()` returns empty array - **NEEDS IMPLEMENTATION**
- ⚠️ Dive data parsing from raw Mares protocol - **NOT IMPLEMENTED**
- ⚠️ Memory/logbook reading commands - **NOT IMPLEMENTED**
- ⚠️ Sample dive data used for UI testing only

#### Advanced Protocol Commands
- ⚠️ Device memory structure parsing - **NEEDS RESEARCH**
- ⚠️ Dive log download commands beyond CMD_VERSION
- ⚠️ Device configuration/settings access
- ⚠️ Real-time data monitoring

#### Export/Import Features
- ⚠️ Export to standard dive formats (UDDF, etc.) - **NOT IMPLEMENTED**
- ⚠️ Import from other dive software
- ⚠️ Data persistence/local storage

## Hardware Specifications
- **Device**: Mares Puck Pro dive computer  
- **Connection**: USB cable with CP210x USB-to-serial converter
- **Communication**: 9600 baud, 8N1, **RTS=false critical for stability**
- **Device Detection**: `/dev/cu.usbserial-*` on macOS
- **Protocol**: Mares IconHD family (model 0x18 for Puck Pro)

## Development Environment
- **Language**: Swift 5.9+
- **Platform**: macOS 13.0+ (Ventura)
- **Framework**: SwiftUI, ORSSerialPort
- **Build System**: Swift Package Manager
- **IDE**: Xcode 15.0+

## Key Technical Discoveries

### RTS Control Solution
**CRITICAL FINDING**: Device reboots were caused by:
1. Immediate command sending after connection
2. Insufficient stabilization delays
3. Missing RTS/DTR line control

**SOLUTION**:
```swift
port.rts = false  // CRITICAL - prevents device reboot
port.dtr = false  // Also clear DTR
Task.sleep(nanoseconds: 2_000_000_000) // 2+ second delay
// DON'T send immediate commands after connection
```

### Protocol Structure
- Commands: `[0xC2, 0xC2^0xA5]` = `[0xC2, 0x67]`
- Responses: `[0xAA, payload..., 0xEA]`
- Error responses: `[0x8F, error_code]`
- Based on libdivecomputer mares_iconhd.c implementation

## Repository Information
- **GitHub**: https://github.com/johnj212/mares-puck-pro-macos-driver
- **Status**: Public repository, actively developed
- **License**: MIT (recommended for dive community)

## Build Commands

### Swift Package Manager
```bash
cd MaresPuckProDriver
swift build                    # Build the package
swift test                     # Run unit tests
swift run MaresPuckProDriverApp  # Launch the app
./simple_test.swift           # Test protocol implementation
```

### Requirements
```bash
# Install CP210x driver (if not already present)
# Download from Silicon Labs website

# Check for device connection
ls /dev/cu.usbserial*
```

## Next Development Priorities

### HIGH PRIORITY (Core Functionality)
1. **Real Dive Data Download** - Implement actual dive parsing
2. **Memory Map Analysis** - Understand Puck Pro memory structure  
3. **Logbook Commands** - Commands beyond CMD_VERSION
4. **Data Export** - Export to UDDF or other standard formats

### MEDIUM PRIORITY (Features)
5. **Device Configuration** - Read/write settings
6. **Real-time Monitoring** - Live depth/temperature display
7. **Data Persistence** - Local dive log storage
8. **Error Recovery** - Better handling of communication failures

### LOW PRIORITY (Polish)
9. **App Store Distribution** - Code signing and notarization
10. **Advanced UI** - Charts, maps, dive computer comparison
11. **Sync Integration** - Cloud backup, other dive software
12. **Multi-device Support** - Other Mares models

## Technical Resources

### Primary References
- **libdivecomputer**: https://github.com/libdivecomputer/libdivecomputer
  - `src/mares_iconhd.c` - Direct implementation reference
  - Model 0x18 = Puck Pro, uses IconHD protocol family
- **ORSSerialPort**: https://github.com/armadsen/ORSSerialPort
  - macOS serial communication library used in implementation

### Protocol Analysis Files (in repo)
- `mares_with_rts.py` - Working Python implementation with RTS control
- `libdivecomputer/src/mares_iconhd.c` - C reference implementation
- Various test scripts showing protocol development process

## Known Issues & Solutions

### Device Reboot Problem - ✅ SOLVED
- **Issue**: Device rebooted on any communication attempt
- **Root Cause**: Immediate commands + insufficient RTS control
- **Solution**: Proper RTS=false + 2+ second delays + no immediate commands

### Communication Reliability
- **Status**: ✅ Connection stable, device stays on
- **Verification**: Tested with actual Puck Pro device
- **Protocol**: Basic version command working

### Missing Dive Data
- **Status**: ⚠️ Major gap - only sample data shown
- **Next Step**: Implement dive log memory reading protocol
- **Reference**: libdivecomputer memory parsing code

## Code Architecture

### Project Structure
```
MaresPuckProDriver/
├── Package.swift                 # Swift Package configuration
├── Sources/
│   ├── MaresPuckProDriver/      # Core library
│   │   ├── Protocol/            # ✅ Mares protocol implementation  
│   │   ├── Models/              # ✅ Data structures
│   │   ├── UI/                  # ✅ SwiftUI views
│   │   └── MaresCommunicator.swift # ✅ Main communication class
│   └── MaresPuckProDriverApp/   # ✅ macOS app target
├── Tests/                       # ✅ Unit tests
└── README.md                    # ✅ User documentation
```

### Key Classes
- `MaresCommunicator`: ✅ Serial port management and device communication
- `MaresProtocol`: ✅ Protocol constants and command/response parsing  
- `DiveData`: ✅ Complete dive information model
- `ContentView`: ✅ Main application interface

## Commands for Next Development

### Analyze libdivecomputer Protocol
```bash
# Study the memory reading implementation
cd libdivecomputer/src
grep -A 20 -B 5 "memory" mares_iconhd.c
grep -A 10 "dive.*download" mares_iconhd.c
```

### Protocol Development
```bash
# Test current version command
cd MaresPuckProDriver
swift simple_test.swift

# Run full application
swift run MaresPuckProDriverApp
```

### Next Implementation Steps
```bash
# 1. Add dive count command to MaresProtocol.swift
# 2. Add memory reading commands  
# 3. Implement dive log parsing in MaresCommunicator.swift
# 4. Replace sample data with real parsed data
```