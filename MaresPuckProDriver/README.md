# DRAFT - Mares Puck Pro Driver for macOS

A native macOS application for communicating with the Mares Puck Pro dive computer. Working progress....

## Features

- 🌊 **Native macOS App** - Built with SwiftUI for modern macOS experience
- 🔌 **USB Communication** - Connects via USB-to-serial interface
- 📊 **Dive Data Download** - Retrieve dive logs from your Puck Pro
- 📈 **Dive Analysis** - View detailed dive profiles and statistics
- 🛡️ **Safe Communication** - Careful RTS/DTR control prevents device reboots

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
- **Communication**: 9600 baud, 8N1, with careful RTS/DTR control
- **Safety**: Prevents device reboots through proper line control
- **Framework**: Built with ORSSerialPort for reliable serial communication

### Protocol Structure

Commands use the format: `[CMD, CMD^0xA5]`
Responses follow: `[0xAA, ...data..., 0xEA]`

Example:
- Version command: `[0xC2, 0x67]`
- Expected response: `[0xAA, version_data, 0xEA]`

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
