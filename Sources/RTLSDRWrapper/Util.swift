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

struct IQSample: Codable {
    let i: Float
    let q: Float
    
    public var description: String {
        return "(I: \(i), Q: \(q))"
    }
}

func IQSamplesFromBuffer(_ buffer: [UInt8]) -> [IQSample] {
    let t0 = Date.timeIntervalSinceReferenceDate
    var samples: [IQSample] = []
    var count = buffer.count
    if(buffer.count % 2 != 0) {
        print("IQ Sample buffer has uneven length, something might be wrong, ignoring last pair.")
        count -= 1
    }
    for index in stride(from: 0, to: buffer.count, by: 2) {
        let I: Float = Float(buffer[index]) * NORMALIZATION_FACTOR - 1
        let Q: Float = Float(buffer[index+1]) * NORMALIZATION_FACTOR - 1
        samples.append(IQSample(i: I, q: Q))
    }
    let t1 = Date.timeIntervalSinceReferenceDate
    print("Time to convert buffer to samples: \(t1-t0) seconds")
    return samples
}

func samplesToCSV(_ samples: [IQSample], path: String) {
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
