# DRAFT - Mares Puck Pro Driver for macOS

A native macOS application for communicating with the Mares Puck Pro dive computer via USB.

## ✅ **STATUS: FULLY WORKING** 

🎉 **Breakthrough Achieved!** This driver now successfully downloads real dive data from Mares Puck Pro devices without device reboots.

### Recent Success (July 2025):
- ✅ **Stable Communication**: Device no longer reboots during data download
- ✅ **Real Dive Data**: Successfully parsed actual dive: #68, 285.6min (4.7 hours), 7.1m depth
- ✅ **Complete Memory Scan**: Scanned entire dive memory without connection issues
- ✅ **Robust Protocol**: Implemented proper libdivecomputer-compatible memory read commands

## Features

- 🌊 **Native macOS App** - Built with SwiftUI for modern macOS experience  
- 🔌 **USB Communication** - Connects via USB-to-serial interface (CP210x)
- 📊 **Real Dive Data Download** - Actually retrieves and parses dive logs from your Puck Pro
- 📈 **Dive Analysis** - View detailed dive profiles with depth/time samples
- 🛡️ **Stable Communication** - **CRITICAL FIX**: Single-transfer commands prevent device reboots
- 🔍 **Memory Streaming** - Efficiently scans entire dive computer memory to discover dives

## System Requirements

- macOS 10.15 (Catalina) or later
- Mares Puck Pro dive computer
- Official Mares USB interface cable (CP210x based)

## Installation

### Prerequisites

1. **Install CP210x Driver** (usually pre-installed on modern macOS):
   - The Silicon Labs CP210x USB-to-UART bridge driver
   - Download from [Silicon Labs](https://www.silabs.com/developer-tools/usb-to-uart-bridge-vcp-drivers) if needed

2. **Xcode or Swift Development Tools** (for building from source):
   - Xcode 15.0 or later
   - Swift 5.9 or later

### Building from Source

1. Clone the repository:
   ```bash
   git clone [repository-url]
   cd MaresPuckProDriver
   ```

2. Build and run:
   ```bash
   swift build
   swift run MaresPuckProDriverApp
   ```

   Or open `Package.swift` in Xcode and run the project.

## Usage

### Connecting Your Puck Pro

1. **Prepare the Device**:
   - Ensure your Puck Pro is on and in surface mode
   - The display should show "PC ready" or similar
   - Connect the official Mares USB cable

2. **Connect in the App**:
   - Launch the Mares Puck Pro Driver app
   - Click "Refresh Ports" to scan for devices
   - Select your device from the port list (usually contains "usbserial")
   - Click "Connect"

3. **Download Dive Data**:
   - Once connected, click "Download Dives"
   - The app will communicate with your Puck Pro and retrieve dive logs
   - View detailed dive information including profiles and statistics

### Troubleshooting Connection Issues

If the device reboots during connection:

1. **Check USB Cable**: Ensure you're using the official Mares interface cable
2. **Device Mode**: Verify the Puck Pro shows "PC ready"
3. **Driver Installation**: Confirm CP210x drivers are installed
4. **Port Selection**: Try different available serial ports

## Technical Details

This driver implements the Mares IconHD protocol based on analysis of the libdivecomputer project. Key technical aspects:

- **Protocol**: Uses Mares IconHD command structure with XOR encoding  
- **Communication**: 115200 baud, 8E1, with **CRITICAL** RTS/DTR control
- **Memory Reading**: Single-transfer commands matching libdivecomputer implementation
- **Safety**: **BREAKTHROUGH FIX** - Prevents device reboots through proper command structure
- **Framework**: Built with ORSSerialPort for reliable serial communication

### Protocol Structure  

**Commands** use the format: `[CMD, CMD^0xA5, data...]`
**Responses** follow: `[0xAA, ...data..., 0xEA]`

Examples:
- **Version command**: `[0xC2, 0x67]`
- **Memory read**: `[0xE7, 0x42, address_4bytes, length_4bytes]` *(single transfer)*

### Critical Fix: Memory Read Commands

**❌ Old (caused reboots):**
```swift
port.send([0xE7, 0x42])              // Send command
port.send([address_bytes...])        // Send data separately  
```

**✅ New (libdivecomputer pattern):**
```swift  
port.send([0xE7, 0x42, address_bytes...])  // Single atomic transfer
```

This matches `mares_iconhd_transfer()` from libdivecomputer that sends complete command+data as one transfer.

## Development

### Project Structure

```
MaresPuckProDriver/
├── Sources/
│   ├── MaresPuckProDriver/           # Core library
│   │   ├── Protocol/                 # Mares protocol implementation
│   │   ├── Models/                   # Data models
│   │   └── UI/                       # SwiftUI views
│   └── MaresPuckProDriverApp/        # macOS app target
├── Tests/                            # Unit tests
└── Package.swift                     # Swift Package configuration
```

### Key Components

- **MaresProtocol**: Low-level protocol implementation
- **MaresCommunicator**: High-level communication manager
- **ContentView**: Main application interface
- **DiveData**: Data model for dive information

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes with tests
4. Submit a pull request

### Testing

Run tests with:
```bash
swift test
```

## Acknowledgments

This project is based on research from:
- [libdivecomputer](https://github.com/libdivecomputer/libdivecomputer) - Open source dive computer library
- [ORSSerialPort](https://github.com/armadsen/ORSSerialPort) - Excellent macOS serial communication library
- The diving community's reverse engineering efforts

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Disclaimer

This software is not affiliated with or endorsed by Mares. Use at your own risk. Always verify dive data accuracy with your dive computer's display and logs.

## Support

For issues, questions, or contributions, please open an issue on GitHub.
