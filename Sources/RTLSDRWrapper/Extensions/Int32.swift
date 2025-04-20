//
//  Int32.swift
//  RTLSDRWrapper
//
//  Created by Connor Gibbons  on 4/17/25.
//

extension Int32 {
    
    init(int: Int) {
        if(int > Int32.max){
            print("! Warning: Int32 overflow, clamped to Int32.max")
            self = Int32.max
        }
        else if(int < Int32.min) {
            print("! Warning: Int32 overflow, clamped to Int32.min")
            self = Int32.min
        }
        else {
            self = Int32(int)
        }
    }
    
    init(bool: Bool) {
        self = bool ? 1 : 0
    }
    
}
