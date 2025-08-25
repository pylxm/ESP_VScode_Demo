# ESP_VScode_Demo

Getting Started with VS Code IDE: 

For reference: https://docs.espressif.com/projects/esp-idf/en/v4.2.1/esp32/get-started/vscode-setup.html

## (Skip for Win) STEP 1: Install brew for mac

For reference: https://brew.sh/

run in terminal: 

`/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`

restart terminal, run

`brew --version`

it should output: Homebrew x.x.x

## (Skip for Win) STEP 2: Standard Toolchain Setup for Linux and macOS

For reference: https://docs.espressif.com/projects/esp-idf/en/latest/esp32/get-started/linux-macos-setup.html

run in terminal: 

`brew install cmake ninja dfu-util`

run in terminal: 

`/usr/sbin/softwareupdate --install-rosetta --agree-to-license`

## STEP 3: Install VS Code & Python

Download and install Visual Studio Code

https://code.visualstudio.com/download

Download and install Python

https://www.python.org/downloads/

## STEP 4: Install ESP 

Recommended way to install ESP-IDF Visual Studio Code Extension is by downloading it from VS Code Marketplace: 

https://marketplace.visualstudio.com/items?itemName=espressif.esp-idf-extension

## STEP 5: Install USB driver

Download universal drivers from: 

https://www.silabs.com/software-and-tools/usb-to-uart-bridge-vcp-drivers?tab=downloads


## Step 6: Set up in VScode
Select UART as Flash Method

Select ESP32-C3 (QFN32) as Port to Use