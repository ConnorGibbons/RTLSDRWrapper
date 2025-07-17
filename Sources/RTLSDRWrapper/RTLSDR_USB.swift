//
//  RTLSDR_USB.swift
//  RTLSDRWrapper
//
//  Created by Connor Gibbons  on 7/11/25.
//

import Foundation
import Accelerate

@available(macOS 14.0, *)
@Observable
public class RTLSDR_USB: RTLSDR {
    public var directSamplingMode: DirectSamplingMode?
    let devicePointer: OpaquePointer
    public let deviceName: String
    public let tuner: RTLSDRTunerType
    let USBStrings: (String, String, String)
    let index: Int
    let asyncHandler: RTLSDRHandler

    public var centerFrequency: Int? {
        get {
            return getCenterFrequency(device: devicePointer)
        }
    }
    public func setCenterFrequency(_ newValue: Int) throws {
        guard RTLSDRWrapper.setCenterFrequency(device: devicePointer, frequency: newValue) else {
            throw RTLSDRError.operationFailed(operation: "setCenterFrequency(\(newValue))")
        }
    }

    public var frequencyCorrection: Int {
        get {
            return getFrequencyCorrection(device: devicePointer)
        }
    }
    public func setFrequencyCorrection(_ newValue: Int) throws {
        guard RTLSDRWrapper.setFrequencyCorrection(device: devicePointer, ppm: newValue) else {
            throw RTLSDRError.operationFailed(operation: "setFrequencyCorrection(\(newValue))")
        }
    }

    public var tunerGains: [Int]? {
        return getTunerGains(device: devicePointer)
    }

    public var tunerGain: Int? {
        get {
            return getTunerGain(device: devicePointer)
        }
    }
    public func setTunerGain(_ newValue: Int) throws {
        guard RTLSDRWrapper.setTunerGain(device: devicePointer, gain: newValue) else {
            throw RTLSDRError.operationFailed(operation: "setTunerGain(\(newValue))")
        }
    }

    public var tunerBandwidth: Int = 0 // 0 means automatic
    public func setTunerBandwidth(_ newValue: Int) throws {
        guard RTLSDRWrapper.setTunerBandwidth(device: devicePointer, bandwidth: newValue) else {
            throw RTLSDRError.operationFailed(operation: "setTunerBandwidth(\(newValue))")
        }
        tunerBandwidth = newValue
    }

    public var intermediateFrequencyGain: (Int, Int) = (0, 0)
    public func setIntermediateFrequencyGain(stage: Int, gain: Int) throws {
        guard RTLSDRWrapper.setTunerIntermediateFrequencyGain(device: devicePointer, stage: stage, gain: gain) else {
            throw RTLSDRError.operationFailed(operation: "setIntermediateFrequencyGain(\(stage), \(gain))")
        }
        intermediateFrequencyGain = (stage, gain)
    }

    public var manualGainEnabled: Bool = false
    public func setManualGainEnabled(_ newValue: Bool) throws {
        guard RTLSDRWrapper.setManualGainMode(device: devicePointer, enable: newValue) else {
            throw RTLSDRError.operationFailed(operation: "setManualGainEnabled(\(newValue))")
        }
        manualGainEnabled = newValue
    }

    public var sampleRate: Int? {
        get {
            return getSampleRate(device: devicePointer)
        }
    }
    public func setSampleRate(_ newValue: Int) throws {
        guard RTLSDRWrapper.setSampleRate(device: devicePointer, rate: newValue) else {
            throw RTLSDRError.operationFailed(operation: "setSampleRate(\(newValue))")
        }
    }

    public var testModeEnabled: Bool = false
    public func setTestModeEnabled(_ newValue: Bool) throws {
        guard RTLSDRWrapper.setTestMode(device: devicePointer, enable: newValue) else {
            throw RTLSDRError.operationFailed(operation: "setTestMode(\(newValue))")
        }
        testModeEnabled = newValue
    }

    public var digitalAGCEnabled: Bool = false
    public func setDigitalAGCEnabled(_ newValue: Bool) throws {
        guard setAGCMode(device: devicePointer, enable: newValue) else {
            throw RTLSDRError.operationFailed(operation: "setAGCMode(\(newValue))")
        }
        digitalAGCEnabled = newValue
    }

    public var directSamplingModeEnabled: DirectSamplingMode? {
        get {
            return getDirectSamplingMode(device: devicePointer)
        }
    }
    public func setDirectSamplingMode(_ newValue: DirectSamplingMode) throws {
        guard RTLSDRWrapper.setDirectSamplingMode(device: devicePointer, enable: newValue) else {
            throw RTLSDRError.operationFailed(operation: "setDirectSamplingMode(\(newValue))")
        }
    }

    public var offsetTuningEnabled: Bool? {
        get {
            return getOffsetTuning(device: devicePointer)
        }
    }
    public func setOffsetTuningEnabled(_ newValue: Bool) throws {
        guard RTLSDRWrapper.setOffsetTuning(device: devicePointer, enable: newValue) else {
            throw RTLSDRError.operationFailed(operation: "setOffsetTuning(\(newValue))")
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
        self.initOperations()
        self.primeUSB()
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
        Mixer → IF Gain (\(intermediateFrequencyGain)dB) →
        Tuner Gain (\(tunerGain ?? 0)dB) →
        Sample Rate: \(sampleRate ?? 0) Hz
        """
    }

    public func syncReadSamples(count: Int) -> [DSPComplex] {
        _ = resetBuffer(device: devicePointer)
        return readSamples(device: devicePointer, sampleCount: count)
    }

    public func asyncReadSamples(callback: @escaping ([DSPComplex]) -> Void) {
        self.asyncHandler.startAsyncRead(callback: callback)
    }

    public func stopAsyncRead() {
        self.asyncHandler.stopAsyncRead()
    }
    
    // I don't know why this needs to be done but it does, or else USB read error happens
    private func primeUSB() {
        var storedSamples: [DSPComplex] = []
        storedSamples.append(contentsOf: syncReadSamples(count: 16384))
        storedSamples.removeAll(keepingCapacity: true)
    }
    
    private func initOperations() {
        let initResults = [
            RTLSDRWrapper.setAGCMode(device: devicePointer, enable: false),
            RTLSDRWrapper.setTestMode(device: devicePointer, enable: false),
            RTLSDRWrapper.setOffsetTuning(device: devicePointer, enable: false),
            RTLSDRWrapper.setManualGainMode(device: devicePointer, enable: false),
            RTLSDRWrapper.setTunerBandwidth(device: devicePointer, bandwidth: 0),
            RTLSDRWrapper.setSampleRate(device: devicePointer, rate: Int(2.4e6)),
            RTLSDRWrapper.setCenterFrequency(device: devicePointer, frequency: 24*MHZ)
        ]
        let initOps = ["AGC", "disableTestMode", "disableOffsetTuning", "disableManualGain", "setAutomaticBandwidth", "setSampleRate", "setDefaultFreq"]
        for (i, result) in initResults.enumerated() {
            if (!result) {
                print("!! Warning: Init operation failed: \(initOps[i])")
            }
        }
    }
    
}
