//
//  RoomInfo.swift
//  TgoRTCIOS
//
//  Created by Slun on 2026/1/16.
//

public final class RoomInfo {
    public var roomName: String = ""
    public var token: String = ""
    public var url: String = ""
    public var maxParticipants: Int = 2
    public var rtcType: RTCType = .audio
    public var isP2P: Bool = true
    public var uidList: [String] = []
    public var timeout: Int = 30
    public var creatorUid: String = ""
    public var loginUID: String = ""
    
    public init(roomName: String = "",
         token: String = "",
         url: String = "",
         maxParticipants: Int = 2,
         rtcType: RTCType = .audio,
         isP2P: Bool = true,
         uidList: [String] = [],
         timeout: Int = 30,
         creatorUid: String = "",
         loginUID: String = "") {
        self.roomName = roomName
        self.token = token
        self.url = url
        self.maxParticipants = maxParticipants
        self.rtcType = rtcType
        self.isP2P = isP2P
        self.uidList = uidList
        self.timeout = timeout
        self.creatorUid = creatorUid
        self.loginUID = loginUID
    }
    
    public func isCreator() -> Bool {
        return creatorUid == loginUID
    }
    
    public func getP2PToUID() -> String {
        return uidList.first(where: { $0 != loginUID }) ?? creatorUid
    }
}
