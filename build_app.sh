#!/bin/bash

echo "🚀 Building Mares Puck Pro.app..."

# Create app bundle structure
APP_NAME="Mares Puck Pro"
APP_DIR="$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Clean previous build
rm -rf "$APP_DIR"

# Create app bundle directories
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

echo "📁 Created app bundle structure"

# Copy Info.plist
cp "$APP_NAME/Info.plist" "$CONTENTS_DIR/"

# Copy app icons
cp -r "$APP_NAME/Assets.xcassets/AppIcon.appiconset"/*.png "$RESOURCES_DIR/" 2>/dev/null || echo "⚠️ No PNG icons found, using placeholder"

echo "📄 Copied resources"

# Build the Swift executable using the original Swift Package
cd MaresPuckProDriver
swift build -c release --product MaresPuckProDriverApp

if [ $? -eq 0 ]; then
    echo "✅ Swift build successful"
    
    # Copy the built executable to app bundle
    cp .build/release/MaresPuckProDriverApp "../$MACOS_DIR/$APP_NAME"
    
    # Make executable
    chmod +x "../$MACOS_DIR/$APP_NAME"
    
    echo "🎉 Successfully created $APP_DIR"
    echo ""
    echo "To install:"
    echo "1. Copy '$APP_DIR' to /Applications/"
    echo "2. Right-click and select 'Open' first time (bypass Gatekeeper)"
    echo "3. App will appear in Launchpad and can be launched normally"
else
    echo "❌ Build failed"
    exit 1
fi