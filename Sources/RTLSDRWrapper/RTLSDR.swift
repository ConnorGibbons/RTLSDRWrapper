//
//  RTLSDR.swift
//  RTLSDRWrapper
//
//  Created by Connor Gibbons  on 4/18/25.
//

import Foundation
import Accelerate

public enum RTLSDRError: LocalizedError {
    case deviceNotFound
    case failedToInitialize
    case operationFailed(operation: String)
    case cantEstablishTCPConnection
    
    public var errorDescription: String? {
        switch self {
        case .operationFailed(let operation):
            return "Failed to perform operation: \(operation)."
        case .failedToInitialize:
            return "Failed to initialize rtl-sdr"
        case .deviceNotFound:
            return "No rtl-sdr exists at this index -- try a different index or unplug the device."
        case .cantEstablishTCPConnection:
            return "Unable to establish connection to rtl_tcp server"
        }
    }
    
}

protocol RTLSDR {
    var deviceName: String { get }
    var tuner: RTLSDRTunerType { get }
    
    var centerFrequency: Int? { get }
    func setCenterFrequency(_ frequency: Int) throws -> Void
    
    var frequencyCorrection: Int { get }
    func setFrequencyCorrection(_ correction: Int) throws -> Void
    
    var tunerGain: Int? { get }
    var tunerGains: [Int]? { get }
    func setTunerGain(_ gain: Int) throws -> Void
    
    var tunerBandwidth: Int { get }
    func setTunerBandwidth(_ bandwidth: Int) throws -> Void
    
    var intermediateFrequencyGain: (Int, Int) { get }
    func setIntermediateFrequencyGain(stage: Int, gain: Int) throws -> Void
    
    var manualGainEnabled: Bool { get }
    func setManualGainEnabled(_ enabled: Bool) throws -> Void
    
    var sampleRate: Int? { get }
    func setSampleRate(_ sampleRate: Int) throws -> Void
    
    var testModeEnabled: Bool { get }
    func setTestModeEnabled(_ enabled: Bool) throws -> Void
    
    var digitalAGCEnabled: Bool { get }
    func setDigitalAGCEnabled(_ enabled: Bool) throws -> Void
    
    var directSamplingMode: DirectSamplingMode? { get }
    func setDirectSamplingMode(_ mode: DirectSamplingMode) throws -> Void
    
    var offsetTuningEnabled: Bool? { get }
    func setOffsetTuningEnabled(_ enabled: Bool) throws -> Void
    
    func syncReadSamples(count: Int) -> [DSPComplex]
    func asyncReadSamples(callback: @escaping ([DSPComplex]) -> Void)
    func stopAsyncRead() -> Void
    
}
