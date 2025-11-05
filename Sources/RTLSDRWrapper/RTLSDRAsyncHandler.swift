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
let wBUF_LEN: UInt32 = 16 * 32 * 512 // Note: Must be a multiple of 512


/// A pointer to this function & a pointer to an RTLSDRAsyncHandler instance are provided to rtlsdr-read-async.
/// When a buffer is ready, this function is called, and ctx is an opaque pointer to the same RTLSDRAsyncHandler instance, letting us call RTLSDRAsyncHandler.handleBuffer
@_cdecl("rtlsdr_handler")
func rtlsdr_handler(_ buf: UnsafeMutablePointer<UInt8>?, _ len: UInt32, _ ctx: UnsafeMutableRawPointer?) {
    guard ctx != nil, buf != nil else {
        return
    }
    let handler = Unmanaged<RTLSDRAsyncHandler>.fromOpaque(ctx!).takeUnretainedValue()
    handler.handleBuffer(buf, len)
}

/// Class for handling RTL-SDR (USB) async reads.
/// This shouldn't be touched by the user, just internal to RTLSDR_USB
class RTLSDRAsyncHandler {
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
    
    /// Starts an async read on the RTL-SDR referred to by self.device.
    /// Calls 'callback' with a buffer of samples repeatedly until stopped.
    /// Cycles through 15 buffers of length 262,144
    /// **Always** call this function on a background thread!! It will block until stopAsyncRead is called.
    func startAsyncRead(callback: @escaping ([DSPComplex]) -> Void) {
        guard !isActive else { return }
        
        // Need to make an Unmanaged instance to get an opaque pointer.
        let retainedSelf = Unmanaged.passUnretained(self)
        self.callback = callback
        isActive = true
        let result = rtlsdr_read_async(self.device, rtlsdr_handler, retainedSelf.toOpaque(), wBUF_NUM, wBUF_LEN)
        
        self.isActive = false
        print("Async read ended, code: \(result)")
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
