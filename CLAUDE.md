# Mares Puck Pro macOS Driver Development

## Project Overview
Development of a macOS application to communicate with the Mares Puck Pro dive computer via USB. This is NOT a kernel driver project - the Puck Pro uses a USB-to-serial converter that appears as a virtual COM port on macOS.

## Hardware Specifications
- **Device**: Mares Puck Pro dive computer
- **Connection**: Proprietary USB cable with USB-to-TTL serial converter
- **Communication**: Serial protocol at 9600 baud, 8N1 (8 data bits, no parity, 1 stop bit)
- **Device Detection**: Appears as `/dev/tty.usbserial-*` or similar on macOS
- **Protocol**: Proprietary Mares protocol (reverse-engineered by community)

## Technical Architecture

### Driver Type Decision
- **NO kernel extension (kext) needed** - device uses standard USB-to-serial
- **NO system extension needed** - standard serial communication
- **User-space application** - communicates through existing serial port interface

### Communication Protocol
- Simple ASCII/binary command-response protocol
- Device must be in surface mode for communication
- Protocol details available in `libdivecomputer` project
- Handshake typically starts with specific byte sequence

## Development Plan

### Phase 1: Research & Setup
- [x] Research hardware specifications and USB protocol
- [x] Analyze existing protocol implementations (libdivecomputer, Subsurface)
- [x] Determine macOS driver architecture requirements
- [x] Create development environment setup

### Phase 2: Core Implementation
- [ ] Set up Xcode project structure
- [ ] Implement serial port detection and enumeration
- [ ] Port Mares Puck Pro protocol from libdivecomputer
- [ ] Create basic communication layer
- [ ] Implement data parsing for dive logs

### Phase 3: macOS Integration
- [ ] Design native macOS user interface
- [ ] Implement file export functionality
- [ ] Add error handling and user feedback
- [ ] Implement proper macOS app lifecycle management

### Phase 4: Testing & Distribution
- [ ] Test with actual Mares Puck Pro device
- [ ] Code signing for macOS distribution
- [ ] Create installer/distribution package
- [ ] Documentation and user guide

## Development Tools & Frameworks

### Primary Development Environment
- **IDE**: Xcode
- **Language**: Swift (recommended) or Objective-C
- **Frameworks**: 
  - IOKit (if low-level USB access needed)
  - POSIX serial APIs for standard serial communication
  - Foundation/Cocoa for macOS app development

### Alternative Development Options
- **Python**: Using `pyserial` library (good for prototyping)
- **C/C++**: Direct port of `libdivecomputer` code

### Key Resources

### Primary Resources
- **libdivecomputer**: Open-source library with Mares protocol implementation
  - GitHub: https://github.com/libdivecomputer/libdivecomputer
  - Supports Mares Puck Pro since v0.3.0 (2013), Puck Pro+ since v0.8.0 (2023)
- **Subsurface**: Dive logging software with Mares support
  - Uses libdivecomputer for device communication
- **USB/Serial monitoring tools**: For protocol analysis and debugging

### Relevant GitHub Projects for macOS USB Development
- **ORSSerialPort**: Serial port library for Objective-C and Swift macOS apps
  - GitHub: https://github.com/armadsen/ORSSerialPort
  - **Recommended** for Mares Puck Pro (uses USB-to-serial)
- **deft-simple-usb**: Usermode USB device drivers in Swift on macOS
  - GitHub: https://github.com/didactek/deft-simple-usb
  - Uses IOUSBHost framework
- **USBDeviceSwift**: Pure Swift wrapper for IOKit.usb and IOKit.hid
  - GitHub: https://github.com/Arti3DPlayer/USBDeviceSwift
- **DriverKitUserClientSample**: Working DriverKit example with SwiftUI
  - GitHub: https://github.com/DanBurkhardt/DriverKitUserClientSample

### Driver Requirements
- **Silicon Labs CP210x USB Driver** required for macOS
  - Download from Silicon Labs website as Mac_OSX_VCP_Driver.zip
  - Enables USB-to-serial communication for Mares devices

### Known Issues
- Linux-specific communication bug with missing bytes (GitHub issue #22)
- macOS users report connection issues requiring correct driver installation
- Device must be in surface mode for communication

## Commands to Run

### Build Commands
```bash
# For Xcode projects
xcodebuild -project MaresDriver.xcodeproj -scheme MaresDriver build

# For testing
xcodebuild -project MaresDriver.xcodeproj -scheme MaresDriver test
```

### Development Setup
```bash
# Clone libdivecomputer for protocol reference
git clone https://github.com/libdivecomputer/libdivecomputer.git

# List available serial ports (for testing)
ls /dev/tty.*
```

## Important Notes

1. **No Kernel Development**: This is a user-space application, not a kernel driver
2. **Protocol Source**: Use reverse-engineered protocol from libdivecomputer
3. **Device Requirements**: Mares Puck Pro must be in surface mode for communication
4. **macOS Compatibility**: Target modern macOS versions (10.15+)
5. **Code Signing**: Required for distribution outside App Store

## Project Structure Recommendation
```
MaresDriver/
├── Sources/
│   ├── Communication/          # Serial port communication
│   ├── Protocol/              # Mares protocol implementation
│   ├── DataModel/             # Dive data structures
│   └── UI/                    # macOS user interface
├── Tests/
├── Resources/
└── Documentation/
```