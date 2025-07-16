import Testing
@testable import RTLSDRWrapper
import CRTLSDR
import Foundation
import Accelerate

@Test func example() async throws {
    #expect(SDRProbe.getDeviceCount() == CRTLSDR.rtlsdr_get_device_count())
    let newSDR = try RTLSDR_USB.init(deviceIndex: 0)
    try newSDR.setCenterFrequency(94*MHZ)
    try newSDR.setDigitalAGCEnabled(true)
    print(newSDR.signalChainSummary)
    try await Task.sleep(nanoseconds: UInt64(Double(ONE_SECOND)*0.5))
    var storedSamples: [DSPComplex] = []
    storedSamples.append(contentsOf: newSDR.syncReadSamples(count: 16384)) // If this isn't included, the USB transfer for the async read fails. Only god knows why
    storedSamples.removeAll(keepingCapacity: true)
    newSDR.asyncReadSamples(callback: { (samples) in
        storedSamples.append(contentsOf: samples)
    })
    try await Task.sleep(nanoseconds: UInt64(ONE_SECOND))
    newSDR.stopAsyncRead()
    let t0 = Date.timeIntervalSinceReferenceDate
    let fmDemodulated = vDSPfmDemod(storedSamples)
    let t1 = Date.timeIntervalSinceReferenceDate
    print("Demodulation time: \(t1-t0)s (\(Double(storedSamples.count) / (t1-t0)) samples/s, \(storedSamples.count) samples")
    let decimated = stride(from: 0, to: fmDemodulated.count, by: 42).map { fmDemodulated[$0] }
    let stats = (
        min: fmDemodulated.min() ?? 0,
        max: fmDemodulated.max() ?? 0,
        first: fmDemodulated.first ?? 0,
        nanCount: fmDemodulated.filter { $0.isNaN }.count
    )
    print("Stats → min: \(stats.min), max: \(stats.max), first: \(stats.first), NaNs: \(stats.nanCount)")
}


@Test func RTLSDR_TCPConnectionTest() throws {
    do {
        let localTCPSDR = try RTLSDR_TCP(host: "127.0.0.1", port: UInt16(1234))
    }
    catch {
        print(error)
        assert(false)
    }
}
