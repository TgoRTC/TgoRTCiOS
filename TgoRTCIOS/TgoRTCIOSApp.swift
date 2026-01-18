//
//  TgoRTCIOSApp.swift
//  TgoRTCIOS
//
//  Created by Slun on 2026/1/16.
//

import SwiftUI

@main
struct TgoRTCIOSApp: App {
    
    init() {
        // 初始化 TgoRTC SDK
        let options = Options()
        options.isDebug = true
        options.mirror = true
        TgoRTC.shared.configure(options: options)
    }
    
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}
