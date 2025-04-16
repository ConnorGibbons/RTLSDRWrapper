// The Swift Programming Language
// https://docs.swift.org/swift-book

import CRTLSDR

public enum SDRProbe {
    func getDeviceCount() -> UInt32 {
        return CRTLSDR.rtlsdr_get_device_count()
    }
}
