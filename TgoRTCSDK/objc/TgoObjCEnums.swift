//
//  TgoObjCEnums.swift
//  TgoRTCSDK
//
//  Created by Cursor on 2026/01/22.
//

import Foundation

/// Objective-C compatible RTC type
@objc public enum TgoRTCTypeObjC: Int {
    case audio = 0
    case video = 1
}

/// Objective-C compatible connection status
@objc public enum TgoConnectStatusObjC: Int {
    case connecting = 0
    case connected = 1
    case disconnected = 2
}

/// Objective-C compatible camera position
@objc public enum TgoCameraPositionObjC: Int {
    case front = 0
    case back = 1
}

/// Objective-C compatible connection quality
@objc public enum TgoConnectionQualityObjC: Int {
    case unknown = 0
    case excellent = 1
    case good = 2
    case poor = 3
    case lost = 4
}
