public func dcBlock(samples: [Float], alpha: Float = 0.995) -> [Float] {
    var y: [Float] = []
    y.reserveCapacity(samples.count)
    var prevY: Float = 0
    var prevX: Float = 0

    for x in samples {
        let current = x - prevX + alpha * prevY
        y.append(current)
        prevX = x
        prevY = current
    }
    return y
}

public func lowPass(samples: [Float], alpha: Float = 0.05) -> [Float] {
    var y = [Float](repeating: 0, count: samples.count)
    y[0] = samples[0]
    for i in 1..<samples.count {
        y[i] = alpha * samples[i] + (1 - alpha) * y[i - 1]
    }
    return y
}

public func normalize(samples: [Float], peak: Float = 2.3561945) -> [Float] {
    return samples.map { min(max($0 / peak, -1.0), 1.0) }
}

public func decimate(samples: [Float]) -> [Float] {
    var result: [Float] = []
    for i in stride(from: 0, to: samples.count, by: 42) {
        result.append(samples[i])
    }
    return result
}
