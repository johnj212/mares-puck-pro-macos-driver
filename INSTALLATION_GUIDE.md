# 📱 Mares Puck Pro App Installation Guide

## 🎯 **What You Have Now**

You now have a native macOS application: **"Mares Puck Pro.app"**

- ✅ **Native macOS app** - No more terminal commands needed
- ✅ **Custom diver icon** - Blue background with white diver silhouette  
- ✅ **Real dive data parsing** - Downloads actual dive data from your device
- ✅ **Complete SwiftUI interface** - Modern macOS design with navigation

## 📲 **Installation Steps**

### **1. Install the App**
```bash
# Copy to Applications folder (recommended)
cp -R "Mares Puck Pro.app" /Applications/

# OR: Just run from current location
open "Mares Puck Pro.app"
```

### **2. First Launch (Bypass Gatekeeper)**
Since the app is unsigned, macOS will show a security warning:

1. **Right-click** on "Mares Puck Pro.app"
2. Select **"Open"** from context menu
3. Click **"Open"** on the security dialog
4. App will launch and be trusted for future launches

### **3. Connect Your Device**
1. Connect Mares Puck Pro to Mac via USB
2. Device should appear as `/dev/cu.usbserial-*`
3. Launch "Mares Puck Pro" app
4. Select your device from the port list
5. Click "Connect"

## 🖥️ **App Features**

### **Main Interface**
- **Connection Panel**: Select and connect to your Puck Pro
- **Device Info**: Shows firmware version, serial number, model
- **Dive List**: Browse all downloaded dives
- **Dive Details**: View individual dive profiles with depth/temperature data

### **Real Data Extraction**
- **Dive Headers**: Date, time, duration, max depth
- **Profile Samples**: Complete depth and temperature timeline
- **Water Type**: Automatically detected (saltwater/freshwater)
- **Sample Intervals**: Variable based on device settings

## 🔧 **Troubleshooting**

### **App Won't Launch**
- Ensure macOS 13.0+ (Ventura or newer)
- Try the right-click "Open" method
- Check Console.app for error messages

### **Device Not Found**
- Install CP210x USB driver if needed (from Silicon Labs)
- Check USB connection is secure
- Look for `/dev/cu.usbserial-*` in Terminal: `ls /dev/cu.usb*`

### **Connection Fails**
- Device may be in sleep mode - press button to wake
- Try disconnecting/reconnecting USB cable
- Ensure no other dive software is using the device

### **No Dive Data**
- Make sure device has recorded dives
- Connection must be stable during download
- Try the "Download Dives" button multiple times if needed

## 📁 **Project Structure**

The complete project includes:

```
Mares Puck Pro.app/          # Ready-to-use macOS application
├── Contents/
│   ├── Info.plist          # App metadata
│   ├── MacOS/              
│   │   └── Mares Puck Pro  # Executable binary
│   └── Resources/          
│       └── *.png           # App icons (multiple sizes)
└── [App bundle structure]

MaresPuckProDriver/          # Original Swift Package (for development)
├── Sources/                # Source code
├── Tests/                  # Unit tests  
└── Package.swift          # Dependencies

build_app.sh                # Build script to regenerate .app
create_icon.py             # Icon generator script
```

## 🚀 **Usage**

1. **Launch** "Mares Puck Pro" from Applications or Launchpad
2. **Connect** your Puck Pro device via USB
3. **Select** the correct serial port (usually `/dev/cu.usbserial-*`)
4. **Click Connect** - device info will appear
5. **Download Dives** - real dive data will populate the list
6. **Browse** individual dives with full profile data

## 🎉 **You're Done!**

Your Mares Puck Pro is now a fully functional native macOS application that you can:
- Launch from Dock/Launchpad like any other app
- Use without terminal or command-line knowledge
- Share with other Mac users (they'll need the same Gatekeeper bypass)

The app extracts real dive data from your device using the exact same protocol as Windows dive software! 🤿