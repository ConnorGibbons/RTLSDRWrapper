//
//  RTLSDR_TCP.swift
//  RTLSDRWrapper
//
//  Created by Connor Gibbons  on 7/11/25.
//
import Accelerate
import Foundation
import Network

@available(macOS 10.14, *)
public class RTLSDR_TCP: RTLSDR, @unchecked Sendable {
    var deviceName: String
    var tuner: RTLSDRTunerType
    var dedicatedQueue: DispatchQueue
    
    
    var connection: NWConnection
    var activeConnection: Bool {
        return connection.state == .ready
    }
    func startConnection() throws {
        guard !activeConnection else { return }
        let oldStateUpdateHandler = connection.stateUpdateHandler
        let connectedSemaphore = DispatchSemaphore(value: 0)
        let newStateUpdateHandler: @Sendable (NWConnection.State) -> Void = { state in
            if let altHandler = oldStateUpdateHandler {
                altHandler(state)
            }
            switch state {
            case .ready:
                connectedSemaphore.signal()
            default:
                break
            }
        }
        connection.stateUpdateHandler = newStateUpdateHandler
        connection.start(queue: dedicatedQueue)
        let connectionResult = connectedSemaphore.wait(timeout: DispatchTime.now() + 1)
        connection.stateUpdateHandler = oldStateUpdateHandler
        guard connectionResult == .success else { throw RTLSDRError.cantEstablishTCPConnection }
        executeBacklog()
    }
    // Can only send commands when a network connection is open, trying to keep this transparent to the user by keeping a list of commands to send immediately upon connection.
    private var commandBacklog: [() throws -> Void] = []
    
    private func executeBacklog() {
        guard activeConnection else { return }
        for command in commandBacklog {
            do {
                try command()
            } catch {
                print("Error executing command: \(error)")
            }
        }
        commandBacklog.removeAll()
    }
    
    private func sendCommand(command: UInt8, argument: UInt32, callOnSuccess: @Sendable @escaping () -> Void = {  }) {
        guard activeConnection else { return }
        // MSB sent last making this little endian (rtltcp expects big endian)
        let argBytes = [UInt8(argument & 0xFF), UInt8((argument >> 8) & 0xFF), UInt8((argument >> 16) & 0xFF), UInt8((argument >> 24) & 0xFF)]
        let argBytesNetworkOrder = argBytes.reversed()
        let combinedNetworkOrdered = [command] + argBytesNetworkOrder
        let data = Data(combinedNetworkOrdered)
        connection.send(content: data, completion: .contentProcessed({ error in
            if let error = error {
                print("Error sending command: \(error)")
            } else {
                callOnSuccess()
            }
        }))
    }
    
    public var centerFrequency: Int? = nil
    public func setCenterFrequency(_ frequency: Int) throws {
        guard activeConnection else {
            let deferredFunc = { try self.setCenterFrequency(frequency) }
            commandBacklog.append(deferredFunc)
            return
        }
        let freq = UInt32(frequency)
        let command = UInt8(0x01)
        sendCommand(command: command, argument: freq, callOnSuccess: {
            self.centerFrequency = frequency
        })
    }
    
    public var frequencyCorrection: Int = -1
    public func setFrequencyCorrection(_ correction: Int) throws {
        guard activeConnection else {
            let deferredFunc = { try self.setFrequencyCorrection(correction) }
            commandBacklog.append(deferredFunc)
            return
        }
        let ppm = UInt32(correction)
        let command = UInt8(0x05)
        sendCommand(command: command, argument: ppm, callOnSuccess: {
            self.frequencyCorrection = correction
        })
    }
    
    public var tunerGain: Int? = nil
    public var tunerGains: [Int]?
    public func setTunerGain(_ gain: Int) throws {
        guard activeConnection else {
            let deferredFunc = { try self.setTunerGain(gain) }
            commandBacklog.append(deferredFunc)
            return
        }
        if(self.tunerGains == nil) {
            print("Warning: Setting tuner gain while tunerGains list is nil. If this operation succeeds, new gain will be unknown.")
        }
        let ppm = UInt32(gain)
        let command = UInt8(0x0d)
        sendCommand(command: command, argument: ppm, callOnSuccess: {
            self.tunerGain = self.tunerGains?[gain] ?? -1
        })
    }
    
    public var tunerBandwidth: Int = -1
    public func setTunerBandwidth(_ bandwidth: Int) throws {
        print("Setting bandwidth on networked SDRs currently unsupported.")
        throw RTLSDRError.operationFailed(operation: "setTunerBandwidth")
    }
    
    public var intermediateFrequencyGain: (Int, Int) = (-1, -1)
    public func setIntermediateFrequencyGain(stage: Int, gain: Int) throws {
        guard activeConnection else {
            let deferredFunc = { try self.setIntermediateFrequencyGain(stage: stage, gain: gain) }
            commandBacklog.append(deferredFunc)
            return
        }
        let stage = UInt16(stage)
        let gain = UInt16(gain)
        let combined = UInt32(0) | (UInt32(stage << 16)) | UInt32(gain)
        let command = UInt8(0x0d)
        sendCommand(command: command, argument: combined, callOnSuccess: {
            self.intermediateFrequencyGain = (Int(stage), Int(gain))
        })
    }
    
    public var manualGainEnabled: Bool = false
    public func setManualGainEnabled(_ enabled: Bool) throws {
        guard activeConnection else {
            let deferredFunc = { try self.setManualGainEnabled(enabled)}
            commandBacklog.append(deferredFunc)
            return
        }
        let command = UInt8(0x03)
        let argument: UInt32 = enabled ? 1 : 0
        sendCommand(command: command, argument: argument, callOnSuccess: {
            self.manualGainEnabled = enabled
        })
    }
    
    public var sampleRate: Int? = nil
    public func setSampleRate(_ sampleRate: Int) throws {
        guard activeConnection else {
            let deferredFunc = { try self.setSampleRate(sampleRate) }
            commandBacklog.append(deferredFunc)
            return
        }
        let command = UInt8(0x02)
        let argument = UInt32(sampleRate)
        sendCommand(command: command, argument: argument, callOnSuccess: {
            self.sampleRate = sampleRate
        })
    }
    
    public var testModeEnabled: Bool = false
    public func setTestModeEnabled(_ enabled: Bool) throws {
        guard activeConnection else {
            let deferredFunc = { try self.setTestModeEnabled(enabled) }
            commandBacklog.append(deferredFunc)
            return
        }
        let command = UInt8(0x07)
        let argument: UInt32 = enabled ? 1 : 0
        sendCommand(command: command, argument: argument, callOnSuccess: {
            self.testModeEnabled = enabled
        })
    }
    
    public var digitalAGCEnabled: Bool = false
    public func setDigitalAGCEnabled(_ enabled: Bool) throws {
        guard activeConnection else {
            let deferredFunc = { try self.setDigitalAGCEnabled(enabled) }
            commandBacklog.append(deferredFunc)
            return
        }
        let command = UInt8(0x08)
        let argument: UInt32 = enabled ? 1 : 0
        sendCommand(command: command, argument: argument, callOnSuccess: {
            self.digitalAGCEnabled = enabled
        })
    }
    
    public var directSamplingMode: DirectSamplingMode? = nil
    public func setDirectSamplingMode(_ mode: DirectSamplingMode) throws {
        guard activeConnection else {
            let deferredFunc = { try self.setDirectSamplingMode(mode) }
            commandBacklog.append(deferredFunc)
            return
        }
        let command: UInt8 = 0x09
        let argument: UInt32
        switch mode {
            case .disabled:
            argument = 0x00
            case .iADC:
            argument = 0x01
            case .qADC:
            argument = 0x02
        }
        sendCommand(command: command, argument: argument, callOnSuccess: {
            self.directSamplingMode = mode
        })
    }
    
    public var offsetTuningEnabled: Bool? = nil
    public func setOffsetTuningEnabled(_ enabled: Bool) throws {
        guard activeConnection else {
            let deferredFunc = { try self.setOffsetTuningEnabled(enabled) }
            commandBacklog.append(deferredFunc)
            return
        }
        let command = UInt8(0x0a)
        let argument: UInt32 = enabled ? 1 : 0
        sendCommand(command: command, argument: argument, callOnSuccess: {
            self.offsetTuningEnabled = enabled
        })
    }
    
    public init(host: String, port: UInt16) throws {
        let host = NWEndpoint.Host(host)
        guard let port = NWEndpoint.Port(rawValue: port) else {
            throw RTLSDRError.failedToInitialize
        }
        let endpoint = NWEndpoint.hostPort(host: host, port: port)
        let connection = NWConnection(to: endpoint, using: .tcp)
        
        // Setting default
        self.deviceName = "RTLSDR TCP (\(host):\(port))"
        self.connection = connection
        self.commandBacklog = []
        self.tuner = .unknown
        self.dedicatedQueue = DispatchQueue(label: "tcpRTLSDRQueue\(host):\(port)")
        
        guard testConnection(connection) else {
            print("Failed to establish TCP connection to RTLSDR. Check if rtltcp server is running, and if host/port is correct.")
            throw RTLSDRError.failedToInitialize
        }
        self.initOperations()
    }
    
    private func initOperations() {
        do {
            try self.setDigitalAGCEnabled(false)
            try self.setTestModeEnabled(false)
            try self.setOffsetTuningEnabled(false)
            try self.setManualGainEnabled(false)
            try self.setSampleRate(Int(2.4e6))
            try self.setCenterFrequency(24*MHZ)
        }
        catch {
            print("Init operations failed.")
        }
    }
    
    private func testConnection(_ connection: NWConnection) -> Bool {
        let oldStateHandler = connection.stateUpdateHandler.take()
        let connectSem = DispatchSemaphore(value: 0)
        let newStateHandler: @Sendable (NWConnection.State) -> Void = { newState in
            if(newState == .ready) { connectSem.signal() }
            if(newState == .cancelled) { connectSem.signal() }
        }
        let testQueue = DispatchQueue(label: "RTLSDRReachabilityTestQueue")
        connection.stateUpdateHandler = newStateHandler
        connection.start(queue: testQueue)
        let connectResult = connectSem.wait(timeout: DispatchTime.now() + 1)
        guard connectResult == .success else { return false }
        connection.cancel()
        // Putting second wait() here so connection is recognized as closed prior to initOperations being called
        connectSem.wait()
        connection.stateUpdateHandler = oldStateHandler
        return true
    }
    
    func syncReadSamples(count: Int) -> [DSPComplex] {
        guard !self.activeConnection else {
            print("Can't start sync read: connection is already active.")
            return []
        }
        let connectionEstasblishedSemaphore = DispatchSemaphore(value: 0)
        self.connection.stateUpdateHandler = { state in
            if state == .ready {
                connectionEstasblishedSemaphore.signal()
            }
        }
        var receivedSamples: [DSPComplex] = .init(repeating: .init(real: 0, imag: 0), count: count)
        var wrappedReceivedSamples: Wrapped<[DSPComplex]> = .init(value: receivedSamples)
        var validSampleCount: Wrapped<Int> = .init(value: 0)
        let receivedSamplesSemaphore = DispatchSemaphore(value: 0)
        connection.start(queue: self.dedicatedQueue)
        self.syncReceiveLoop(buffer: wrappedReceivedSamples, validCount: validSampleCount, semaphore: receivedSamplesSemaphore)
        receivedSamplesSemaphore.wait()
        return wrappedReceivedSamples.value
    }
    
    private func syncReceiveLoop(buffer: Wrapped<[DSPComplex]>, validCount: Wrapped<Int>, semaphore: DispatchSemaphore) {
        let name = self.deviceName
        guard self.activeConnection else {
            print("\(name): Cancelling receive loop -- connection not active.")
            return
        }
        self.connection.receiveMessage(completion: { data, context, isComplete, error in
            guard error == nil else {
                print("\(name): Stopping receive loop due to error: \(error!)")
                return
            }
            if let rxData = data {
                let samples: [UInt8] = Array(rxData)
                var complexSamples = IQSamplesFromBuffer(samples)
                self.writeToPreallocatedBuffer(buffer: buffer, validCount: validCount, vals: complexSamples)
                if(validCount.value >= buffer.value.count) {
                    semaphore.signal()
                    return
                }
            }
            if isComplete {
                print("\(name): Stopping receive loop early -- final message received.")
                return
            }
            self.syncReceiveLoop(buffer: buffer, validCount: validCount, semaphore: semaphore)
        })
    }
    
    private func writeToPreallocatedBuffer(buffer: Wrapped<[DSPComplex]>, validCount: Wrapped<Int>, vals: [DSPComplex]) {
        let numToWrite = (validCount.value + vals.count < buffer.value.count) ? vals.count : (buffer.value.count - validCount.value)
        for i in 0..<numToWrite {
            guard validCount.value + i < buffer.value.count else {
                print("Write out of bounds — skipping remaining samples.")
                break
            }
            buffer.value[validCount.value + i] = vals[i]
        }
        validCount.value += numToWrite
    }
    
    func asyncReadSamples(callback: @escaping ([DSPComplex]) -> Void) {
        guard !self.activeConnection else {
            print("Can't start async read: connection is already active.")
            return
        }
        let connectionEstasblishedSemaphore = DispatchSemaphore(value: 0)
        self.connection.stateUpdateHandler = { state in
            if state == .ready {
                connectionEstasblishedSemaphore.signal()
            }
        }
        connection.start(queue: self.dedicatedQueue)
        let connectionEstablishedResult = connectionEstasblishedSemaphore.wait(timeout: .now() + 1)
        guard connectionEstablishedResult == .success else {
            print("Failed to establish TCP connection to RTLSDR. Check if rtltcp server is running, and if host/port is correct.")
            return
        }
        self.asyncReceieveLoop(callback: callback)
    }
    
    private func asyncReceieveLoop(callback: @escaping ([DSPComplex]) -> Void) {
        let name = self.deviceName
        guard self.activeConnection else {
            print("\(name): Cancelling receive loop -- connection not active.")
            return
        }
        connection.receiveMessage(completion: { data, context, isComplete, error in
            guard error == nil else {
                print("\(name): Stopping receive loop due to error: \(error!)")
                return
            }
            if let rxData = data {
                let samples: [UInt8] = Array(rxData)
                callback(IQSamplesFromBuffer(samples))
            }
            if isComplete {
                print("\(name): Stopping receive loop, final message receieved. ")
                return
            }
            self.asyncReceieveLoop(callback: callback)
        })
    }
    
    func stopAsyncRead() {
        guard self.activeConnection else { return }
        self.connection.cancel()
    }
    
    
}


final class Wrapped<T> {
    var value: T
    init(value: T) { self.value = value }
}
