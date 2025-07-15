import CRTLSDR
import Accelerate

// More general discovery funcs not requiring a device pointer
public enum SDRProbe {
    
    /// Gets the number of RTL-SDR devices connected.
    public static func getDeviceCount() -> Int {
        return Int(CRTLSDR.rtlsdr_get_device_count())
    }

    /// Gets the name of the RTL-SDR device at the given index.
    public static func getDeviceName(index: Int) -> String? {
        guard index >= 0 && index < getDeviceCount() else {
            return nil
        }
        let deviceName: UnsafePointer<CChar> = CRTLSDR.rtlsdr_get_device_name(UInt32(int: index))
        let castedToString: String = String(cString: deviceName)
        if(castedToString.count == 0) {
            return nil
        }
        return castedToString
    }

    /// Given a device index, this function returns a tuple containing the manufacturer string, product string, and serial number string of the device.
    /// If the device is not found, it returns nil.
    public static func getDeviceUSBStrings(index: Int) -> (String, String, String)? {
        var manufact: [CChar] = Array(repeating: 0, count: 256)
        var product: [CChar] = Array(repeating: 0, count: 256)
        var serial: [CChar] = Array(repeating: 0, count: 256)
        var returnTuple: (String, String, String)?

        manufact.withUnsafeMutableBufferPointer { manufact in
            product.withUnsafeMutableBufferPointer { product in
                serial.withUnsafeMutableBufferPointer { serial in
                    let result: Int32 = CRTLSDR.rtlsdr_get_device_usb_strings(
                        UInt32(int: index),
                        manufact.baseAddress,
                        product.baseAddress,
                        serial.baseAddress
                    )
                    if result == 0 {
                        let manufactString = String(cString: manufact.baseAddress!)
                        let productString = String(cString: product.baseAddress!)
                        let serialString = String(cString: serial.baseAddress!)
                        returnTuple = (manufactString, productString, serialString)
                    }
                }
            }
        }

        if(returnTuple == nil || returnTuple!.0.count == 0 || returnTuple!.1.count == 0 || returnTuple!.2.count == 0) {
            return nil
        }
        return returnTuple
    }

    public static func getIndexFromSerial(serial: String) -> Int? {
        let serialCString: ContiguousArray<CChar> = serial.utf8CString
        let serialPointer: UnsafePointer<CChar> = serialCString.withUnsafeBufferPointer { $0.baseAddress! }
        let index: Int32 = CRTLSDR.rtlsdr_get_index_by_serial(serialPointer)
        if index < 0 {
            return nil
        }
        return Int(index)
    }

}

func openRTLSDR(index: Int) -> OpaquePointer? {
    let deviceIndex: UInt32 = UInt32(int: index)
    var device: OpaquePointer?

    let returnVal: Int32 = CRTLSDR.rtlsdr_open(&device, deviceIndex)
    if(returnVal != 0) {
        print("Error opening RTL-SDR device: \(returnVal)")
        return nil
    }

    return device
}

func closeRTLSDR(device: OpaquePointer) -> Bool {
    let returnVal: Int32 = CRTLSDR.rtlsdr_close(device)
    if(returnVal != 0) {
        print("Error closing RTL-SDR device: \(returnVal)")
        return false
    }
    return true
}

func setOscillatorFrequency(device: OpaquePointer, rtlFrequency: Int, tunerFrequency: Int) -> Bool {
    let returnVal: Int32 = CRTLSDR.rtlsdr_set_xtal_freq(
        device,
        UInt32(int: rtlFrequency),
        UInt32(int: tunerFrequency)
    )
    if(returnVal != 0) {
        print("Error setting frequency: \(returnVal)")
        return false
    }
    return true
}

func getOscillatorFrequency(device: OpaquePointer) -> (Int, Int)? {
    var rtlFrequency: UInt32 = 0
    var tunerFrequency: UInt32 = 0
    let returnVal: Int32 = CRTLSDR.rtlsdr_get_xtal_freq(device, &rtlFrequency, &tunerFrequency)
    if(returnVal != 0) {
        print("Error getting frequency: \(returnVal)")
        return nil
    }
    return (Int(rtlFrequency), Int(tunerFrequency))
}

func setCenterFrequency(device: OpaquePointer, frequency: Int) -> Bool {
    let returnVal: Int32 = CRTLSDR.rtlsdr_set_center_freq(device, UInt32(int: frequency))
    if(returnVal != 0) {
        print("Error setting center frequency: \(returnVal)")
        return false
    }
    return true
}

func getCenterFrequency(device: OpaquePointer) -> Int? {
    let frequency: UInt32 = CRTLSDR.rtlsdr_get_center_freq(device)
    if(frequency == 0) {
        print("Error getting center frequency: \(frequency)")
        return nil
    }
    return Int(frequency)
}

func setFrequencyCorrection(device: OpaquePointer, ppm: Int) -> Bool {
    let returnVal: Int32 = CRTLSDR.rtlsdr_set_freq_correction(device, Int32(int: ppm))
    if(returnVal != 0) {
        print("Error setting frequency correction: \(returnVal)")
        return false
    }
    return true
}

func getFrequencyCorrection(device: OpaquePointer) -> Int {
    let ppm: Int32 = CRTLSDR.rtlsdr_get_freq_correction(device)
    return Int(ppm)
}

enum RTLSDRTunerType: Int {
    case unknown = 0
    case E4000 = 1
    case FC0012 = 2
    case FC0013 = 3
    case FC2580 = 4
    case R820T = 5
    case R828D = 6
}

func getTunerType(device: OpaquePointer) -> RTLSDRTunerType {
    let tunerType: rtlsdr_tuner = CRTLSDR.rtlsdr_get_tuner_type(device)
    let typeAsInt: UInt32 = tunerType.rawValue
    return RTLSDRTunerType(rawValue: Int(typeAsInt)) ?? .unknown
}

func getTunerGains(device: OpaquePointer) -> [Int]? {
    var gains: [Int32] = Array(repeating: 0, count: 100)
    let returnValue = CRTLSDR.rtlsdr_get_tuner_gains(device, &gains)
    if(returnValue <= 0) {
        return nil
    }
    return gains.map { Int($0) }
}

func setTunerGain(device: OpaquePointer, gain: Int) -> Bool {
    return 0 == CRTLSDR.rtlsdr_set_tuner_gain(device, Int32(int: gain))
}

func setTunerBandwidth(device: OpaquePointer, bandwidth: Int) -> Bool {
    return 0 == CRTLSDR.rtlsdr_set_tuner_bandwidth(device, UInt32(int: bandwidth))
}

func getTunerGain(device: OpaquePointer) -> Int? {
    let gain = rtlsdr_get_tuner_gain(device)
    if(gain == 0) { return nil }
    else { return Int(gain) }
}

func setTunerIntermediateFrequencyGain(device: OpaquePointer, stage: Int, gain: Int) -> Bool {
    return 0 == rtlsdr_set_tuner_if_gain(device, Int32(int: stage), Int32(int: gain))
}

func setManualGainMode(device: OpaquePointer, enable: Bool) -> Bool {
    return 0 == CRTLSDR.rtlsdr_set_tuner_gain_mode(device, Int32(enable ? 1 : 0))
}

func setSampleRate(device: OpaquePointer, rate: Int) -> Bool {
    if(rate < 225001 || rate > 32000000) {
        print("!! Error: tried to set sample rate outside of acceptable range.")
        return false
    }
    else {
        if(rate > 300000 && rate < 900001) {
            print("!! Error: tried to set sample rate outside of acceptable range.")
            return false
        }
        if(rate > 2400000) {
            print("!! Warning: Sample rate higher than 2.4Mhz will cause loss.")
        }
        return 0 == CRTLSDR.rtlsdr_set_sample_rate(device, UInt32(int: rate))
    }
}

func getSampleRate(device: OpaquePointer) -> Int? {
    let rate = CRTLSDR.rtlsdr_get_sample_rate(device)
    if(rate == 0) { return nil }
    else { return Int(rate) }
}

func setTestMode(device: OpaquePointer, enable: Bool) -> Bool {
    return 0 == CRTLSDR.rtlsdr_set_testmode(device, Int32(bool: enable))
}


func setAGCMode(device: OpaquePointer, enable: Bool) -> Bool {
    return 0 == CRTLSDR.rtlsdr_set_agc_mode(device, Int32(bool: enable))
}

public enum DirectSamplingMode: Int32, Sendable {
    case disabled = 0
    case iADC = 1
    case qADC = 2
}

func setDirectSamplingMode(device: OpaquePointer, enable: DirectSamplingMode) -> Bool {
    return 0 == CRTLSDR.rtlsdr_set_direct_sampling(device, enable.rawValue)
}

func getDirectSamplingMode(device: OpaquePointer) -> DirectSamplingMode? {
    let mode = CRTLSDR.rtlsdr_get_direct_sampling(device)
    if(mode < 0 || mode > 2) { return nil }
    else { return DirectSamplingMode(rawValue: mode)! }
}

func setOffsetTuning(device: OpaquePointer, enable: Bool) -> Bool {
    return 0 == CRTLSDR.rtlsdr_set_offset_tuning(device, Int32(bool: enable))
}

func getOffsetTuning(device: OpaquePointer) -> Bool {
    return 0 != CRTLSDR.rtlsdr_get_offset_tuning(device)
}

func resetBuffer(device: OpaquePointer) -> Bool {
    return 0 == CRTLSDR.rtlsdr_reset_buffer(device)
}

func readSamples(device: OpaquePointer, sampleCount: Int) -> [DSPComplex] {
    // two UInt8's per sample, so 2 bytes/sample
    let allocate = 2 * sampleCount
    var amountRead: Int32 = 0
    var buffer: [UInt8] = Array(repeating: 0, count: allocate)
    let returnVal = CRTLSDR.rtlsdr_read_sync(device, &buffer, Int32(int:buffer.count), &amountRead)
    if(returnVal != 0) {
        print("!! Warning: Sync read failed with error: \(returnVal)")
        return []
    }
    return IQSamplesFromBuffer(buffer)
}


