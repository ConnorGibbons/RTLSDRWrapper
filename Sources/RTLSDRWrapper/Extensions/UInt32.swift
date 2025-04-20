//
//  UInt32.swift
//  RTLSDRWrapper
//
//  Created by Connor Gibbons  on 4/17/25.
//

extension UInt32 {
    
    init(int: Int) {
        if(int > UInt32.max) {
            print("! Warning: UInt32 overflow, clamped to Int32.max")
            self = UInt32.max
        }
        else if(int < 0) {
            print("! Warning: Attempt to initialize UInt32 with negative Int, clamped to 0")
            self = 0
        }
        else {
            self = UInt32(int)
        }
    }
    
}
