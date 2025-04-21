//
//  RTLSDR.swift
//  RTLSDRWrapper
//
//  Created by Connor Gibbons  on 4/18/25.
//

import Foundation

public enum RTLSDRError: Error {
    case deviceNotFound
    case failedToInitialize
}

@available(macOS 14.0, *)
@Observable
public class RTLSDR {
    let devicePointer: OpaquePointer
    let deviceName: String
    let tuner: RTLSDRTunerType
    let USBStrings: (String, String, String)
    let index: Int
    let asyncHandler: RTLSDRHandler

    public var centerFrequency: Int? {
        get {
            return getCenterFrequency(device: devicePointer)
        }
        set {
            guard let newValue = newValue else { return }
            if !setCenterFrequency(device: devicePointer, frequency: newValue) {
                print("Failed to set center frequency.")
            }
            print("Center frequency set to \(newValue) Hz")
        }
    }

    public var frequencyCorrection: Int? {
        get {
            return getFrequencyCorrection(device: devicePointer)
        }
        set {
            guard let newValue = newValue else { return }
            if !setFrequencyCorrection(device: devicePointer, ppm: newValue) {
                print("Failed to set frequency correction.")
            }
        }
    }

    public var tunerGains: [Int]? {
        return getTunerGains(device: devicePointer)
    }

    public var tunerGain: Int? {
        get {
            return getTunerGain(device: devicePointer)
        }
        set {
            guard let newValue = newValue else { return }
            if !setTunerGain(device: devicePointer, gain: newValue) {
                print("Failed to set tuner gain.")
            }
        }
    }

    public var tunerBandwidth: Int? = 0 // 0 means automatic
    public func setTunerBandwidth(_ newValue: Int) {
        if !RTLSDRWrapper.setTunerBandwidth(device: devicePointer, bandwidth: newValue) {
            print("Failed to set tuner bandwidth.")
            return
        }
        tunerBandwidth = newValue
    }

    public var intermediateFrequencyGain: (Int, Int)? = (0, 0)
    public func setIntermediateFrequencyGain(stage: Int, gain: Int) {
        if !RTLSDRWrapper.setTunerIntermediateFrequencyGain(device: devicePointer, stage: stage, gain: gain) {
            print("Failed to set intermediate frequency gain.")
            return
        }
        intermediateFrequencyGain = (stage, gain)
    }

    public var manualGainEnabled: Bool = false
    public func toggleManualGain() {
        if (!RTLSDRWrapper.setManualGainMode(device: devicePointer, enable: !manualGainEnabled)) {
            print("Failed to \(manualGainEnabled ? "disable" : "enable") manual gain mode.")
            return
        }
        manualGainEnabled.toggle()
    }

    public var sampleRate: Int? {
        get {
            return getSampleRate(device: devicePointer)
        }
        set {
            guard let newValue = newValue else { return }
            if !setSampleRate(device: devicePointer, rate: newValue) {
                print("Failed to set sample rate.")
            }
        }
    }

    public var testModeEnabled: Bool = false
    public func toggleTestMode() {
        if (!RTLSDRWrapper.setTestMode(device: devicePointer, enable: !testModeEnabled)) {
            print("Failed to \(testModeEnabled ? "disable" : "enable") test mode.")
            return
        }
        testModeEnabled.toggle()
    }

    public var digitalAGCEnabled: Bool = false
    public func toggleDigitalAGC() {
        if (!RTLSDRWrapper.setAGCMode(device: devicePointer, enable: !digitalAGCEnabled)) {
            print("Failed to \(digitalAGCEnabled ? "disable" : "enable") digital AGC.")
            return
        }
        digitalAGCEnabled.toggle()
    }

    public var directSamplingMode: DirectSamplingMode? {
        get {
            return getDirectSamplingMode(device: devicePointer)
        }
        set {
            guard let newValue = newValue else { return }
            if !setDirectSamplingMode(device: devicePointer, enable: newValue) {
                print("Failed to set direct sampling mode.")
            }
        }
    }

    public var offsetTuningEnabled: Bool? {
        get {
            return getOffsetTuning(device: devicePointer)
        }
        set {
            guard let newValue = newValue else { return }
            if !setOffsetTuning(device: devicePointer, enable: newValue) {
                print("Failed to set offset tuning.")
            }
        }
    }

    public init(deviceIndex: Int?) throws {
        self.index = deviceIndex ?? 0
        guard let tdevicePointer = openRTLSDR(index: index) else {
            throw RTLSDRError.deviceNotFound
        }
        self.devicePointer = tdevicePointer
        self.deviceName = SDRProbe.getDeviceName(index: index) ?? "Unknown Device"
        self.tuner = getTunerType(device: devicePointer)
        self.USBStrings = SDRProbe.getDeviceUSBStrings(index: index) ?? ("??", "??", "??")
        self.asyncHandler = RTLSDRHandler(device: devicePointer)

        let initResults = [
            RTLSDRWrapper.setAGCMode(device: devicePointer, enable: false),
            RTLSDRWrapper.setTestMode(device: devicePointer, enable: false),
            RTLSDRWrapper.setOffsetTuning(device: devicePointer, enable: false),
            RTLSDRWrapper.setManualGainMode(device: devicePointer, enable: false),
            RTLSDRWrapper.setTunerBandwidth(device: devicePointer, bandwidth: 0),
            RTLSDRWrapper.setSampleRate(device: devicePointer, rate: Int(2.048e6)),
            RTLSDRWrapper.setCenterFrequency(device: devicePointer, frequency: 94*MHZ)
        ]
        let initOps = ["AGC", "disableTestMode", "disableOffsetTuning", "disableManualGain", "setAutomaticBandwidth", "setSampleRate", "setDefaultFreq"]
        for (i, result) in initResults.enumerated() {
            if (!result) {
                print("!! Warning: Init operation failed: \(initOps[i])")
            }
        }
    }

    deinit {
        let result = closeRTLSDR(device: devicePointer)
        if (!result) {
            print("!! Warning: Failed to close device.")
        } else {
            print("Successfully closed device.")
        }
    }

    public var signalChainSummary: String {
        return """
        Input → Bandpass → LNA →
        Mixer → IF Gain (\(intermediateFrequencyGain?.1 ?? 0)dB) →
        Tuner Gain (\(tunerGain ?? 0)dB) →
        Sample Rate: \(sampleRate ?? 0) Hz
        """
    }

    public func syncReadSamples(count: Int) -> [IQSample] {
        _ = resetBuffer(device: devicePointer)
        return readSamples(device: devicePointer, sampleCount: count)
    }

    public func asyncReadSamples(callback: @escaping ([IQSample]) -> Void) {
        self.asyncHandler.startAsyncRead(callback: callback)
    }

    public func stopAsyncRead() {
        self.asyncHandler.stopAsyncRead()
    }
}
