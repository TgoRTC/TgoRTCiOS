//
//  RoomResponse.swift
//  TgoRTCIOS
//
//  Created by Cursor on 2026/1/18.
//

import Foundation

public struct RoomResponse: Codable {
    public let sourceChannelId: String
    public let sourceChannelType: Int
    public let roomId: String
    public let creator: String
    public let token: String
    public let url: String
    public let status: Int
    public let createdAt: String
    public let maxParticipants: Int
    public let timeout: Int
    public let rtcType: Int
    public let uids: [String]

    enum CodingKeys: String, CodingKey {
        case sourceChannelId = "source_channel_id"
        case sourceChannelType = "source_channel_type"
        case roomId = "room_id"
        case creator
        case token
        case url
        case status
        case createdAt = "created_at"
        case maxParticipants = "max_participants"
        case timeout
        case rtcType = "rtc_type"
        case uids
    }
}
