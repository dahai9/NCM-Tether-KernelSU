#!/usr/bin/env bash

# NCM Tether Build & Package Script
set -e

PROJECT_ROOT=$(pwd)
MODULE_DIR="$PROJECT_ROOT/NCM-Tether-KernelSU"
RUST_DIR="$PROJECT_ROOT/uevent-listener"
BIN_DIR="$MODULE_DIR/bin"
TARGET="aarch64-linux-android"

echo "--- 1. Building Rust Binary (Optimized) ---"
cd "$RUST_DIR"

# Check for cargo-ndk
if ! command -v cargo-ndk &> /dev/null; then
    echo "Error: cargo-ndk not found. Please install it with 'cargo install cargo-ndk'."
    exit 1
fi

# Build for Android
cargo ndk -t "$TARGET" build --release

# Copy binary to module bin folder
echo "--- 2. Updating Module Binaries ---"
mkdir -p "$BIN_DIR"
cp "target/$TARGET/release/uevent-listener" "$BIN_DIR/"
chmod +x "$BIN_DIR/uevent-listener"

echo "Binary size: $(du -h "$BIN_DIR/uevent-listener" | cut -f1)"

echo "--- 3. Packaging Module ---"
cd "$MODULE_DIR"

# Get module info for filename
ID=$(grep '^id=' module.prop | cut -d= -f2)
VERSION=$(grep '^version=' module.prop | cut -d= -f2)
ZIP_NAME="${ID}-${VERSION}.zip"

# Create ZIP
zip -r "$PROJECT_ROOT/$ZIP_NAME" . -x "*.md"

echo "--- Build Complete! ---"
echo "Package created: $PROJECT_ROOT/$ZIP_NAME"
