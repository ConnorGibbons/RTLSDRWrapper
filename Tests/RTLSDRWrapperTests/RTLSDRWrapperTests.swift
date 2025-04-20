import Testing
@testable import RTLSDRWrapper
import CRTLSDR

@Test func example() async throws {
    #expect(SDRProbe.getDeviceCount() == CRTLSDR.rtlsdr_get_device_count())
    let newSDR = try RTLSDR.init(deviceIndex: 0)
    print(newSDR.signalChainSummary)
    try await Task.sleep(nanoseconds: UInt64(Double(ONE_SECOND)*0.5))
    let samples = newSDR.syncReadSamples(count: 16384)
    samplesToCSV(samples, path: "/Users/connorgibbons/Desktop/iqSample.csv")
}
