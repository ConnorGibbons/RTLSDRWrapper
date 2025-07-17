//
//  Types.swift
//  RTLSDRWrapper
//
//  Created by Connor Gibbons  on 4/18/25.
//
import Foundation
import Accelerate

let KB = 1024
let MHZ = 1_000_000
let MSPS = 1_000_000
let ONE_SECOND = 1_000_000_000
let NORMALIZATION_FACTOR: Float = 1 / 127.5

nonisolated(unsafe) let FLOAT_FROM_UINT8_LUT: UnsafePointer<Float> = (0...255).map { Float($0) * (NORMALIZATION_FACTOR) }.withUnsafeBufferPointer { UnsafePointer($0.baseAddress!) }

func IQSamplesFromBuffer(_ buffer: [UInt8]) -> [DSPComplex] {
    let count = buffer.count & ~1
    let totalSamples = buffer.count / 2
    var samples = [DSPComplex].init(repeating: DSPComplex(real: 0, imag: 0), count: totalSamples)
    for index in stride(from: 0, to: count, by: 2) {
        let I: Float = Float(buffer[index]) * NORMALIZATION_FACTOR - 1
        let Q: Float = Float(buffer[index+1]) * NORMALIZATION_FACTOR - 1
        samples[index / 2] = DSPComplex(real: I, imag: Q)
    }
    return samples
}

// Here just for proof of concept & testing. It takes double the time that IQSamplesFromBuffer (multi.) uses.
func IQSamplesFromBufferLUT(_ buffer: [UInt8]) -> [DSPComplex] {
    var samples: [DSPComplex] = []
    var count = buffer.count
    if(buffer.count % 2 != 0) {
        print("IQ Sample buffer has uneven length, something might be wrong, ignoring last pair.")
        count -= 1
    }
    for index in stride(from: 0, to: buffer.count, by: 2) {
        let I: Float = FLOAT_FROM_UINT8_LUT[Int(buffer[index])]
        let Q: Float = FLOAT_FROM_UINT8_LUT[Int(buffer[index])]
        samples.append(DSPComplex(real: I, imag: Q))
    }
    return samples
}

public func samplesToCSV(_ samples: [DSPComplex], path: String) {
    var csvText = "I,Q\n"
    for sample in samples {
        csvText.append("\(sample.real),\(sample.imag)\n")
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

public func fmDemod(_ samples: [DSPComplex]) -> [Float] {
    var diffs =  [Float].init(repeating: 0.0, count: samples.count - 1)
    for i in 1..<samples.count {
        let i0 = samples[i-1].real
        let q0 = samples[i-1].imag
        let i1 = samples[i].real
        let q1 = samples[i].imag
        
        let realPart = (i1 * i0) + (q1 * q0)
        let imaginaryPart = (q1 * i0) - (q0 * i1)
        diffs[i - 1] = atan2(imaginaryPart, realPart)
    }
    return diffs
}

public func vDSPfmDemod(_ samples: [DSPComplex]) -> [Float] {
    let n = vDSP_Length(samples.count - 1)
    var diffs = [Float].init(repeating: 0.0, count: samples.count - 1)
    samples.withUnsafeBufferPointer { samplesPtr in
        let basePointer = samplesPtr.baseAddress!
        basePointer.withMemoryRebound(to: Float.self, capacity: 2 * samples.count) { ptr in
            let i0 = UnsafePointer(ptr)
            let q0 = UnsafePointer(ptr.advanced(by: 1))
            let i1 = UnsafePointer(ptr.advanced(by: 2))
            let q1 = UnsafePointer(ptr.advanced(by: 3))
            // Temp arrays to store z1 * z0(conj.) as vectors:
            // tempReal[x] = (samples[x].i * samples[x-1].i) + (samples[x].q * samples[x-1].q)
            // tempIm[x] = (samples[x].q * samples[x-1].i) - (samples[x].i * samples[x-1].q)
            var tempReal = [Float].init(repeating: 0.0, count: samples.count - 1)
            var tempIm = [Float].init(repeating: 0.0, count: samples.count - 1)
            
            let stride = vDSP_Stride(2) // One IQSample struct's worth of memory should be 2 floats
            let shortStride = vDSP_Stride(1)
            tempReal.withUnsafeMutableBufferPointer { tempRealPtr in
                tempIm.withUnsafeMutableBufferPointer { tempImPtr in
                    var A: DSPSplitComplex = .init(realp: UnsafeMutablePointer(mutating: i0), imagp: UnsafeMutablePointer(mutating: q0)) // prev
                    var B: DSPSplitComplex = .init(realp: UnsafeMutablePointer(mutating: i1), imagp: UnsafeMutablePointer(mutating: q1)) // curr
                    var C: DSPSplitComplex = .init(realp: tempRealPtr.baseAddress!, imagp: tempImPtr.baseAddress!)
                    vDSP_zvmul(&A, stride, &B, stride, &C, 1, n, -1)
                    vDSP_zvphas(&C, shortStride, &diffs, shortStride, n)
                }
            }
        }
    }
    return diffs
}

@available(macOS 14.0, *)
public func vDSPfmDemodv2(_ samples: [DSPComplex]) -> [Float] {
    let n = samples.count - 1
    let vDSPn = vDSP_Length(n)
    let stride = vDSP_Stride(1)
    var prev = DSPSplitComplex(realp: .allocate(capacity: n), imagp: .allocate(capacity: n))
    vDSP.convert(interleavedComplexVector: Array<DSPComplex>(samples.prefix(n)), toSplitComplexVector: &prev)
    var curr = DSPSplitComplex(realp: .allocate(capacity: n), imagp: .allocate(capacity: n))
    vDSP.convert(interleavedComplexVector: samples.suffix(n), toSplitComplexVector: &curr)
    var prod = DSPSplitComplex(realp: .allocate(capacity: n), imagp: .allocate(capacity: n))
    vDSP_zvmul(&prev, stride, &curr, stride, &prod, stride, vDSPn, -1)
    var diffs = [Float](repeating: 0, count: n)
    vDSP.phase(prod, result: &diffs)
    defer {
        prev.imagp.deallocate()
        prev.realp.deallocate()
        curr.imagp.deallocate()
        curr.realp.deallocate()
        prod.imagp.deallocate()
        prod.realp.deallocate()
    }
    return diffs
}


struct TimeOperation {
    var t0: DispatchTime
    var t1: DispatchTime
    let operationName: String
    
    init(operationName: String) {
        self.t0 = DispatchTime.distantFuture
        self.t1 = DispatchTime.distantFuture
        self.operationName = operationName
    }
    
    mutating func start() {
        t0 = .now()
    }
    
    mutating func stop() -> String {
        defer {
            t0 = .distantFuture
            t1 = .distantFuture
        }
        t1 = .now()
        guard t0 != .distantFuture else {
            return "\(operationName) never started."
        }
        return "\(operationName) took \(Double(DispatchTime.now().uptimeNanoseconds - t0.uptimeNanoseconds) / 1_000_000) ms"
    }
    
}
