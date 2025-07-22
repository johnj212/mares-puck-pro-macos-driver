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

### ✅ **BREAKTHROUGH: DIVE DATA DOWNLOAD WORKING**

#### Data Download (NOW IMPLEMENTED!)
- ✅ **WORKING**: `downloadDives()` successfully downloads real dive data from device
- ✅ **IMPLEMENTED**: Complete Mares dive format parsing with libdivecomputer compatibility  
- ✅ **WORKING**: Memory streaming protocol reads entire dive computer memory
- ✅ **SUCCESS**: Real dive parsed: #68, 285.6min (4.7 hours), 7.1m depth, 31 samples

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

### HIGH PRIORITY (Enhancement & Polish)
1. ✅ **Real Dive Data Download** - **COMPLETED** ✅ 
2. ✅ **Memory Map Analysis** - **COMPLETED** - Successful memory streaming ✅
3. ✅ **Logbook Commands** - **COMPLETED** - Memory read protocol working ✅
4. **Data Export** - Export to UDDF, CSV, or other standard formats

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
- **Issue**: Device rebooted on any communication attempt, especially during memory reads
- **Root Cause**: Split memory read commands instead of single atomic transfer
- **Solution**: **CRITICAL FIX** - Single transfer commands matching libdivecomputer pattern

### **BREAKTHROUGH**: Memory Read Commands - ✅ FIXED  
- **Issue**: Memory read commands (0xE7) caused immediate device reboot
- **Root Cause**: Splitting command into two separate `port.send()` calls:
  ```swift
  port.send([0xE7, 0x42])           // Command first
  port.send([address_bytes...])     // Data separately - CAUSED REBOOT
  ```
- **Solution**: Single atomic transfer like libdivecomputer `mares_iconhd_transfer()`:
  ```swift
  port.send([0xE7, 0x42, address_bytes...])  // Complete command as one transfer
  ```

### Communication Reliability
- **Status**: ✅ **FULLY STABLE** - Device stays connected through complete memory scan
- **Verification**: Tested with actual Puck Pro device - scanned 0x112C8 → 0xC8 without issues
- **Protocol**: All commands working including memory reads and dive parsing

### **SUCCESS**: Real Dive Data - ✅ IMPLEMENTED  
- **Status**: ✅ **WORKING** - Successfully downloading and parsing real dives
- **Achievement**: Parsed actual dive #68: 285.6min (4.7 hours), 7.1m depth, 31 profile samples
- **Implementation**: Complete Mares format parsing with DiveHeader and DiveSample structures

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