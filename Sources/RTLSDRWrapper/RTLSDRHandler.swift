//
//  RTLSDRHandler.swift
//  RTLSDRWrapper
//
//  Created by Connor Gibbons  on 4/21/25.
//
//
import Foundation
import CRTLSDR
import Accelerate

let wBUF_NUM: UInt32 = 15
let wBUF_LEN: UInt32 = 16 * 32 * 512


@_cdecl("rtlsdr_handler")
func rtlsdr_handler(_ buf: UnsafeMutablePointer<UInt8>?, _ len: UInt32, _ ctx: UnsafeMutableRawPointer?) {
    guard ctx != nil, buf != nil else {
        return
    }
    let handler = Unmanaged<RTLSDRHandler>.fromOpaque(ctx!).takeUnretainedValue()
    handler.handleBuffer(buf, len)
}


class RTLSDRHandler {
    let device: OpaquePointer
    var isActive: Bool
    var callback: (([DSPComplex]) -> Void)?
    
    
    init(device: OpaquePointer) {
        self.device = device
        self.isActive = false
        self.callback = nil
    }
    
    func handleBuffer(_ buffer: UnsafeMutablePointer<UInt8>?, _ length: UInt32) {
        guard let buffer = buffer, let callback = self.callback else {
            return
        }
        let buff = Array(UnsafeBufferPointer(start: buffer, count: Int(length)))
        callback(IQSamplesFromBuffer(buff))
    }
    
    // **Always** call this function on a background thread!! It will block until stopAsyncRead is called.
    func startAsyncRead(callback: @escaping ([DSPComplex]) -> Void) {
        let retainedSelf = Unmanaged.passRetained(self)
        guard !isActive else { return }
        self.callback = callback
        isActive = true
        let result = rtlsdr_read_async(self.device, rtlsdr_handler, retainedSelf.toOpaque(), wBUF_NUM, wBUF_LEN)
        self.isActive = false
        print("Async read ended, code: \(result)")
        retainedSelf.release()
    }
    
    func stopAsyncRead() {
        guard isActive else { return }
        rtlsdr_cancel_async(device)
        isActive = false
    }
    
    deinit {
        print("!! RTLSDRHandler deinit")
    }
    
}
