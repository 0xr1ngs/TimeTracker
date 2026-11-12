#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

APP_NAME="TimeTracker"
APP_DIR="$APP_NAME.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"

if [ ! -f "Resources/AppIconReference.icns" ]; then
    echo "Missing required application icon: Resources/AppIconReference.icns" >&2
    exit 1
fi

if [ ! -f "Resources/CompiledIcons/Assets.car" ]; then
    echo "Missing native icon catalog. Regenerate with Resources/compile_app_icon.sh." >&2
    exit 1
fi
python3 Resources/install_compiled_icon.py --validate

echo "Cleaning up previous build directories..."
rm -rf "$APP_DIR"

echo "Creating application bundle directory structure..."
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

echo "Copying Info.plist and patching bundle identifiers..."
cp Info.plist "$APP_DIR/Contents/Info.plist"
sed -i '' 's/$(EXECUTABLE_NAME)/TimeTracker/g' "$APP_DIR/Contents/Info.plist"
sed -i '' 's/$(PRODUCT_BUNDLE_IDENTIFIER)/com.antigravity.TimeTracker.macOS/g' "$APP_DIR/Contents/Info.plist"
sed -i '' 's/$(PRODUCT_NAME)/TimeTracker/g' "$APP_DIR/Contents/Info.plist"
sed -i '' 's/$(DEVELOPMENT_LANGUAGE)/en/g' "$APP_DIR/Contents/Info.plist"

cp Resources/AppIconReference.icns "$RESOURCES_DIR/AppIconReference.icns"
python3 Resources/install_compiled_icon.py "$APP_DIR"

echo "Compiling Swift source files..."
SWIFT_FILES=$(find Sources -name "*.swift")
swiftc \
    -parse-as-library \
    -target "$(uname -m)-apple-macosx${MACOSX_DEPLOYMENT_TARGET:-13.0}" \
    -framework SwiftUI \
    -framework AppKit \
    -framework Foundation \
    $SWIFT_FILES \
    -o "$MACOS_DIR/$APP_NAME"

echo "Signing the application bundle locally..."
codesign -f -s - "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

# A local Finder override reproduces the installed reference app exactly.
# Release builds keep their bundled icon and omit Finder metadata.
if [ "${MATCH_REFERENCE_FINDER_ICON:-0}" = "1" ]; then
    swift Resources/apply_finder_icon.swift Resources/AppIconReference.icns "$APP_DIR"
fi

echo "Build successful! Application generated at: $(pwd)/$APP_DIR"
