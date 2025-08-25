
# ESP_VScode_Demo

Demo project for ESP32-C3 development using VS Code and ESP-IDF.

## Table of Contents
- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Setup Instructions](#setup-instructions)
- [Project Structure](#project-structure)
- [References](#references)

## Overview
This guide walks you through setting up your development environment for ESP32-C3 using VS Code, ESP-IDF, and related tools on macOS and Linux. Windows users can skip steps marked "(macOS only)".

## Prerequisites
- macOS or Linux (for Windows, see ESP-IDF docs)
- [Homebrew](https://brew.sh/) (macOS only)
- [Visual Studio Code](https://code.visualstudio.com/download)
- [Python 3.x](https://www.python.org/downloads/)
- USB-to-UART bridge drivers ([Silicon Labs VCP](https://www.silabs.com/software-and-tools/usb-to-uart-bridge-vcp-drivers?tab=downloads))

## Setup Instructions

### 1. (macOS only) Install Homebrew
```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew --version # Should output Homebrew x.x.x
```

### 2. (macOS only) Install Toolchain Dependencies
```sh
brew install cmake ninja dfu-util
/usr/sbin/softwareupdate --install-rosetta --agree-to-license # For Apple Silicon
```
See [Linux/macOS setup guide](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/get-started/linux-macos-setup.html) for details.

### 3. Install VS Code & Python
- Download and install [Visual Studio Code](https://code.visualstudio.com/download)
- Download and install [Python 3.x](https://www.python.org/downloads/)

### 4. Install ESP-IDF Extension for VS Code
- Install from [VS Code Marketplace](https://marketplace.visualstudio.com/items?itemName=espressif.esp-idf-extension)

### 5. Install USB-to-UART Driver
- Download and install [Silicon Labs VCP drivers](https://www.silabs.com/software-and-tools/usb-to-uart-bridge-vcp-drivers?tab=downloads)

### 6. Configure Project in VS Code
- Select **UART** as Flash Method
- Select **ESP32-C3 (QFN32)** as the target chip/port


## References
- [ESP-IDF VS Code Setup Guide](https://docs.espressif.com/projects/esp-idf/en/v4.2.1/esp32/get-started/vscode-setup.html)
- [Linux/macOS Toolchain Setup](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/get-started/linux-macos-setup.html)

---
For troubleshooting, consult the official ESP-IDF documentation or open an issue in this repository.