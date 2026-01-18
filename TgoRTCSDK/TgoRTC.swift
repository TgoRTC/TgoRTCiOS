//
//  TgoRTC.swift
//  TgoRTCIOS
//
//  Created by Slun on 2026/1/16.
//

// todo 模块总入口
public final class TgoRTC {
    // 单例实例
    public static let shared = TgoRTC()
    
    // 私有化初始化方法，确保单例模式
    private init() {
        // 单例初始化，不进行具体配置
    }
    public var options: Options?
    
    public func configure(options: Options? = nil) {
        self.options = options
    }
    
    public let roomManager: RoomManager = RoomManager.shared
    public let participantManager: ParticipantManager = ParticipantManager.shared
    public let audioManager: AudioManager = AudioManager.shared
}

