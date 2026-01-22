//
//  TgoSDKBridge.swift
//  ObjCExample
//
//  This file helps bridge TgoRTCSDK (Swift) to Objective-C
//  It re-exports the SDK types so they can be accessed from ObjC code
//

import Foundation
import TgoRTCSDK

// Re-export all SDK types for ObjC access
// Type aliases ensure these types are visible in the generated -Swift.h header

// Enums
public typealias TgoRTCTypeObjC = TgoRTCSDK.TgoRTCTypeObjC
public typealias TgoConnectStatusObjC = TgoRTCSDK.TgoConnectStatusObjC
public typealias TgoCameraPositionObjC = TgoRTCSDK.TgoCameraPositionObjC
public typealias TgoConnectionQualityObjC = TgoRTCSDK.TgoConnectionQualityObjC

// Entity classes
public typealias TgoRoomInfoObjC = TgoRTCSDK.TgoRoomInfoObjC
public typealias TgoVideoInfoObjC = TgoRTCSDK.TgoVideoInfoObjC
public typealias TgoOptionsObjC = TgoRTCSDK.TgoOptionsObjC

// Bridge classes
public typealias TgoRTCBridge = TgoRTCSDK.TgoRTCBridge
public typealias TgoRoomBridge = TgoRTCSDK.TgoRoomBridge
public typealias TgoParticipantBridge = TgoRTCSDK.TgoParticipantBridge
public typealias TgoAudioBridge = TgoRTCSDK.TgoAudioBridge
public typealias TgoVideoView = TgoRTCSDK.TgoVideoView
public typealias TgoVideoLayoutMode = TgoRTCSDK.TgoVideoLayoutMode
public typealias TgoVideoMirrorMode = TgoRTCSDK.TgoVideoMirrorMode

// Protocols - need to be re-declared for ObjC visibility
@objc public protocol TgoRoomDelegate: AnyObject {
    @objc optional func room(_ roomName: String, didChangeStatus status: TgoConnectStatusObjC)
    @objc optional func room(_ roomName: String, didUpdateVideoInfo info: TgoVideoInfoObjC)
}

@objc public protocol TgoParticipantDelegate: AnyObject {
    @objc optional func participant(_ participant: TgoParticipantBridge, didUpdateMicrophoneOn isOn: Bool)
    @objc optional func participant(_ participant: TgoParticipantBridge, didUpdateCameraOn isOn: Bool)
    @objc optional func participant(_ participant: TgoParticipantBridge, didUpdateSpeaking isSpeaking: Bool)
    @objc optional func participantDidJoin(_ participant: TgoParticipantBridge)
    @objc optional func participantDidLeave(_ participant: TgoParticipantBridge)
    @objc optional func participantDidTimeout(_ participant: TgoParticipantBridge)
}

// Helper class
@objc public class TgoSDKHelper: NSObject {
    
    @objc public static func getSharedBridge() -> TgoRTCBridge {
        return TgoRTCBridge.shared
    }
    
    @objc public static func createRoomInfo() -> TgoRoomInfoObjC {
        return TgoRoomInfoObjC()
    }
    
    @objc public static func createOptions() -> TgoOptionsObjC {
        return TgoOptionsObjC()
    }
}
