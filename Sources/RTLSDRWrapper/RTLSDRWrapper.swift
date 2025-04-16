import CRTLSDR

public enum SDRProbe {
    
    public static func getDeviceCount() -> UInt32 {
        return CRTLSDR.rtlsdr_get_device_count()
    }
    
}
