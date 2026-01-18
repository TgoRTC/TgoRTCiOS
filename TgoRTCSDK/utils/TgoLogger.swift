//
//  TgoLogger.swift
//  TgoRTCIOS
//
//  Created by Slun on 2026/1/16.
//

final class TgoLogger {
    static let shared = TgoLogger()
    let tag: String = "TgoRTC"
    private init() {}
    
    func error(_ message: String) {
        if TgoRTC.shared.options?.isDebug == true {
            print("[\(tag)] [ERROR] \(message)")
        }
    }
    
    func warning(_ message: String) {
        if TgoRTC.shared.options?.isDebug == true {
            print("[\(tag)] [WARNING] \(message)")
        }
    }
    
    func info(_ message: String) {
        if TgoRTC.shared.options?.isDebug == true {
            print("[\(tag)] [INFO] \(message)")
        }
    }
    
    func debug(_ message: String) {
        if TgoRTC.shared.options?.isDebug == true {
            print("[\(tag)] [DEBUG] \(message)")
        }
    }
}
