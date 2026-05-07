# NCM Tether Project

A KernelSU/Magisk module designed to replace the default RNDIS USB tethering protocol with the more efficient NCM (Network Control Model) protocol.

## Project Overview

Modern Android devices often default to RNDIS for USB tethering, which can be less efficient than NCM on many host operating systems. This module monitors USB connection events and automatically swaps the gadget configuration from RNDIS to NCM when tethering is initiated.

### Core Components

- **`NCM-Tether-KernelSU/`**: The flashable module source.
    - `service.sh`: Main logic for protocol swapping and interface management.
    - `module.prop`: Module metadata.
- **`uevent-listener/`**: A Rust-based daemon that monitors Netlink uevents and triggers the protocol swap.
- **`build.sh`**: Automation script for building the Rust binary and packaging the module.
- **`workflows/`**: GitHub Actions for automated releases.

## Building and Running

### Build and Package
The easiest way to build is using the provided `build.sh` script.

**Prerequisites:**
- Rust and `cargo-ndk`.
- Android NDK.
- `zip` utility.

**Run Build:**
```bash
./build.sh
```
This will:
1. Cross-compile the Rust binary for `aarch64-linux-android`.
2. Copy the binary to `NCM-Tether-KernelSU/bin/`.
3. Package the module into a `.zip` file in the root directory.

### Installation
Flash the generated `.zip` file via KernelSU Manager or Magisk Manager and reboot.

## Development Conventions

- **Shell Scripting**: Use `/system/bin/sh` (Toybox compatible).
- **Rust**:
    - Edition: 2024.
    - Dependencies: Minimal (`libc` preferred over `nix`).
    - **Size Optimization**: Release profile is configured for minimum binary size (`opt-level = "z"`, `lto = true`, `panic = "abort"`, `strip = true`).
- **Logging**: Service logs are at `/data/local/tmp/ncm-tether.log`.
- **Interface Naming**: The module renames the `ncm` interface to `rndis0` for system compatibility.

## Key Files

| File | Description |
| :--- | :--- |
| `NCM-Tether-KernelSU/service.sh` | Main swap logic. |
| `uevent-listener/src/main.rs` | Rust uevent monitor. |
| `build.sh` | Build automation. |
| `workflows/release.yml` | CI/CD configuration. |
