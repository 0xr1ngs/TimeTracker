#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

APP_NAME="TimeTracker"
APP_DIR="$APP_NAME.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"

echo "Cleaning up previous build directories..."
rm -rf "$APP_DIR"

echo "Creating application bundle directory structure..."
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

echo "Copying Info.plist and patching bundle identifiers..."
cp Info.plist "$APP_DIR/Contents/Info.plist"
sed -i '' 's/$(EXECUTABLE_NAME)/TimeTracker/g' "$APP_DIR/Contents/Info.plist"
sed -i '' 's/$(PRODUCT_BUNDLE_IDENTIFIER)/com.antigravity.TimeTracker/g' "$APP_DIR/Contents/Info.plist"
sed -i '' 's/$(PRODUCT_NAME)/TimeTracker/g' "$APP_DIR/Contents/Info.plist"
sed -i '' 's/$(DEVELOPMENT_LANGUAGE)/en/g' "$APP_DIR/Contents/Info.plist"

if [ -f "Resources/AppIcon.icns" ]; then
    cp Resources/AppIcon.icns "$RESOURCES_DIR/AppIcon.icns"
fi

echo "Compiling Swift source files..."
SWIFT_FILES=$(find Sources -name "*.swift")
swiftc \
    -parse-as-library \
    -framework SwiftUI \
    -framework AppKit \
    -framework Foundation \
    $SWIFT_FILES \
    -o "$MACOS_DIR/$APP_NAME"

echo "Signing the application bundle locally..."
codesign -f -s - "$APP_DIR"

echo "Build successful! Application generated at: $(pwd)/$APP_DIR"
