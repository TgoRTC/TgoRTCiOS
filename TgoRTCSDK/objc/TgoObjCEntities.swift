//
//  TgoObjCEntities.swift
//  TgoRTCSDK
//
//  Created by Cursor on 2026/01/22.
//

import Foundation

/// Objective-C compatible room information
@objcMembers
public class TgoRoomInfoObjC: NSObject {
    public var roomName: String = ""
    public var token: String = ""
    public var url: String = ""
    public var maxParticipants: Int = 2
    public var rtcType: TgoRTCTypeObjC = .audio
    public var isP2P: Bool = true
    public var uidList: [String] = []
    public var timeout: Int = 30
    public var creatorUid: String = ""
    public var loginUID: String = ""
    
    public override init() {
        super.init()
    }
    
    internal func toSwift() -> RoomInfo {
        let type: RTCType = (rtcType == .audio) ? .audio : .video
        return RoomInfo(
            roomName: roomName,
            token: token,
            url: url,
            maxParticipants: maxParticipants,
            rtcType: type,
            isP2P: isP2P,
            uidList: uidList,
            timeout: timeout,
            creatorUid: creatorUid,
            loginUID: loginUID
        )
    }
}

/// Objective-C compatible video information
@objcMembers
public class TgoVideoInfoObjC: NSObject {
    public let width: Int
    public let height: Int
    public let bitrate: Int
    public let frameRate: Double
    public let layerId: String?
    public let qualityLimitationReason: String?
    
    public init(width: Int, height: Int, bitrate: Int, frameRate: Double, layerId: String? = nil, qualityLimitationReason: String? = nil) {
        self.width = width
        self.height = height
        self.bitrate = bitrate
        self.frameRate = frameRate
        self.layerId = layerId
        self.qualityLimitationReason = qualityLimitationReason
        super.init()
    }
    
    internal convenience init(from swiftInfo: VideoInfo) {
        self.init(
            width: swiftInfo.width,
            height: swiftInfo.height,
            bitrate: swiftInfo.bitrate,
            frameRate: swiftInfo.frameRate,
            layerId: swiftInfo.layerId,
            qualityLimitationReason: swiftInfo.qualityLimitationReason
        )
    }
}

/// Objective-C compatible options
@objcMembers
public class TgoOptionsObjC: NSObject {
    public var isDebug: Bool = true
    public var mirror: Bool = false
    
    public override init() {
        super.init()
    }
    
    internal func toSwift() -> Options {
        let options = Options()
        options.isDebug = isDebug
        options.mirror = mirror
        return options
    }
}
