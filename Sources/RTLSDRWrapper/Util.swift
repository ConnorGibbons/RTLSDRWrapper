//
//  Types.swift
//  RTLSDRWrapper
//
//  Created by Connor Gibbons  on 4/18/25.
//
import Foundation

let KB = 1024
let MHZ = 1_000_000
let MSPS = 1_000_000
let ONE_SECOND = 1_000_000_000
let NORMALIZATION_FACTOR: Float = 1 / 127.5
nonisolated(unsafe) let IQSAMPLE_FROM_UINT8_LUT: UnsafePointer<Float> = (0...255).map { Float($0) * (NORMALIZATION_FACTOR) }.withUnsafeBufferPointer { UnsafePointer($0.baseAddress!) }

public struct IQSample: Codable {
    let i: Float
    let q: Float
    
    public var description: String {
        return "(I: \(i), Q: \(q))"
    }
    
    public func magnitude() -> Float {
        return sqrt( (i * i) + (q * q) )
    }
}

func IQSamplesFromBuffer(_ buffer: [UInt8]) -> [IQSample] {
    let t0 = Date.timeIntervalSinceReferenceDate
    let count = buffer.count & ~1
    let totalSamples = buffer.count / 2
    var samples = [IQSample].init(repeating: IQSample(i: 0, q: 0), count: totalSamples)
    for index in stride(from: 0, to: count, by: 2) {
        let I: Float = Float(buffer[index]) * NORMALIZATION_FACTOR - 1
        let Q: Float = Float(buffer[index+1]) * NORMALIZATION_FACTOR - 1
        samples[index / 2] = IQSample(i: I, q: Q)
    }
    let t1 = Date.timeIntervalSinceReferenceDate
    // print("Time to convert buffer to \(totalSamples) samples: \(t1-t0) seconds (\(Double(totalSamples) * 1/(t1-t0))) samples per second")
    return samples
}

// Here just for proof of concept & testing. It takes double the time that IQSamplesFromBuffer (multi.) uses.
func IQSamplesFromBufferLUT(_ buffer: [UInt8]) -> [IQSample] {
    let t0 = Date.timeIntervalSinceReferenceDate
    var samples: [IQSample] = []
    var count = buffer.count
    if(buffer.count % 2 != 0) {
        print("IQ Sample buffer has uneven length, something might be wrong, ignoring last pair.")
        count -= 1
    }
    for index in stride(from: 0, to: buffer.count, by: 2) {
        let I: Float = IQSAMPLE_FROM_UINT8_LUT[Int(buffer[index])]
        let Q: Float = IQSAMPLE_FROM_UINT8_LUT[Int(buffer[index])]
        samples.append(IQSample(i: I, q: Q))
    }
    let t1 = Date.timeIntervalSinceReferenceDate
    // print("Time to convert buffer to samples: \(t1-t0) seconds")
    return samples
}

public func samplesToCSV(_ samples: [IQSample], path: String) {
    var csvText = "I,Q\n"
    for sample in samples {
        csvText.append("\(sample.i),\(sample.q)\n")
    }
    do {
        try csvText.write(toFile: path, atomically: true, encoding: .utf8)
    }
    catch {
        print("Failed to write sample data to csv file.")
    }
}

public func magsToCSV(_ mags: [Float], path: String) {
    var csvText = "t,Mag\n"
    var t = 0
    for mag in mags {
        csvText.append("\(t),\(mag)\n")
        t += 1
    }
    do {
        try csvText.write(toFile: path, atomically: true, encoding: .utf8)
    }
    catch {
        
    }
}

public func fmDemod(_ samples: [IQSample]) -> [Float] {
    var diffs =  [Float].init(repeating: 0.0, count: samples.count - 1)
    for i in 1..<samples.count {
        let i0 = samples[i-1].i
        let q0 = samples[i-1].q
        let i1 = samples[i].i
        let q1 = samples[i].q
        
        let realPart = (i1 * i0) + (q1 * q0)
        let imaginaryPart = (q1 * i0) - (q0 * i1)
        diffs[i - 1] = atan2(imaginaryPart, realPart)
    }
    return diffs
}
