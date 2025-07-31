# RTLSDRWrapper

A Swift package that provides a clean, modern interface to RTL-SDR devices on macOS. This library wraps the popular librtlsdr C library, allowing Swift developers to easily interact with RTL2832-based USB dongles for Software Defined Radio (SDR) applications.

## Features

- **Dual Connection Support**: Works with both direct USB connections and remote TCP connections (rtl_tcp)
- **Protocol Abstraction**: Common `RTLSDR` protocol for unified interface across connection types
- **Modern Swift API**: Error handling with Swift's `throw`/`try` system
- **Comprehensive Control**: Full access to frequency, gain, sample rate, and other SDR parameters
- **Asynchronous & Synchronous Reads**: Support for both blocking and non-blocking sample acquisition
- **Built-in libusb**: Includes pre-compiled libusb binaries for seamless macOS integration
- **Legacy Compatibility**: Supports macOS 10.13 (High Sierra) and later

## Requirements

- macOS 10.13 (High Sierra) or later
- Swift 5.3 or later
- RTL-SDR compatible USB dongle (for USB mode)
- rtl_tcp server (for TCP mode)

## Installation

### Swift Package Manager

Add RTLSDRWrapper to your project using Xcode or by adding it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ConnorGibbons/RTLSDRWrapper", from: "1.0.0")
]
```

## Quick Start

### USB Connection

```swift
import RTLSDRWrapper

// Initialize USB RTL-SDR device
let sdr = try RTLSDR_USB(deviceIndex: 0)

// Configure the device
try sdr.setCenterFrequency(94_000_000) // 94 MHz
try sdr.setSampleRate(2_400_000)       // 2.4 MHz

// Read samples synchronously
let samples = sdr.syncReadSamples(count: 16384)
print("Received \(samples.count) samples")
```

### TCP Connection

```swift
import RTLSDRWrapper

// Connect to rtl_tcp server
let sdr = try RTLSDR_TCP(host: "127.0.0.1", port: 1234)

// Same API as USB version
try sdr.setCenterFrequency(94_000_000)
try sdr.setSampleRate(2_400_000)

let samples = sdr.syncReadSamples(count: 16384)
```

## Device Discovery

```swift
// Check how many RTL-SDR devices are connected
let deviceCount = SDRProbe.getDeviceCount()
print("Found \(deviceCount) RTL-SDR devices")

// Get device information
for i in 0..<deviceCount {
    if let name = SDRProbe.getDeviceName(index: i) {
        print("Device \(i): \(name)")
    }
    
    if let (manufacturer, product, serial) = SDRProbe.getDeviceUSBStrings(index: i) {
        print("  Manufacturer: \(manufacturer)")
        print("  Product: \(product)")
        print("  Serial: \(serial)")
    }
}
```

## Advanced Configuration

### Direct Sampling

```swift
// Enable direct sampling (bypasses tuner for HF reception)
try sdr.setDirectSamplingMode(.iADC) // I-ADC input
// or
try sdr.setDirectSamplingMode(.qADC) // Q-ADC input
```

## Error Handling

RTLSDRWrapper uses Swift's native error handling:

```swift
do {
    let sdr = try RTLSDR_USB(deviceIndex: 0)
    try sdr.setCenterFrequency(94_000_000)
} catch RTLSDRError.deviceNotFound {
    print("No RTL-SDR device found at index 0")
} catch RTLSDRError.operationFailed(let operation) {
    print("Failed to perform: \(operation)")
} catch {
    print("Other error: \(error)")
}
```

## Architecture

The library consists of several key components:

- **RTLSDR Protocol**: Common interface for all SDR implementations
- **RTLSDR_USB**: Direct USB device access using librtlsdr
- **RTLSDR_TCP**: Network access via rtl_tcp protocol
- **SDRProbe**: Device discovery utilities
- **C Bindings**: Wrapped rtl-sdr and libusb libraries

## Building

The package includes:
- Pre-compiled libusb for both x86_64 and ARM64 macOS
- rtl-sdr source code compiled as a Swift target
- Universal XCFramework for maximum compatibility

## Testing

```swift test```
Note: Some tests require:
- Physical RTL-SDR device connected
- rtl_tcp server running on localhost:1234

## Acknowledgments

- [librtlsdr](https://osmocom.org/projects/rtl-sdr/wiki) - The underlying C library
- [libusb](https://libusb.info/) - USB device access
