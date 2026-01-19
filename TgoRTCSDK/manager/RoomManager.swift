//
//  roomManager.swift
//  TgoRTCIOS
//
//  Created by Slun on 2026/1/16.
//

import Foundation
import LiveKit
import AVFoundation

public typealias VideoInfoListener = (VideoInfo) -> Void

public final class RoomManager: NSObject {
    public static let shared = RoomManager()
    
    private override init() {
        super.init()
    }
    
    public var currentRoomInfo: RoomInfo?
    public private(set) var room: Room?
    private var timeoutTimer: Timer?
    
    private var connectionStatusListeners: [UUID: (String, ConnectStatus) -> Void] = [:]
    
    // Video info related
    private var localVideoInfoListeners: [UUID: VideoInfoListener] = [:]
    private var currentVideoInfo: VideoInfo = .empty
    
    public func addConnectionStatusListener(_ listener: @escaping (String, ConnectStatus) -> Void) -> ListenerToken {
        let id = UUID()
        connectionStatusListeners[id] = listener
        return ListenerToken { [weak self] in
            self?.connectionStatusListeners.removeValue(forKey: id)
        }
    }
    
    public func addVideoInfoListener(_ listener: @escaping VideoInfoListener) -> ListenerToken {
        let id = UUID()
        localVideoInfoListeners[id] = listener
        if currentVideoInfo.isValid {
            listener(currentVideoInfo)
        }
        return ListenerToken { [weak self] in
            self?.localVideoInfoListeners.removeValue(forKey: id)
        }
    }

    private func notifyConnectionStatusChanged(roomName: String, status: ConnectStatus) {
        DispatchQueue.main.async {
            for listener in self.connectionStatusListeners.values {
                listener(roomName, status)
            }
        }
    }
    
    private func notifyVideoInfoChanged(_ info: VideoInfo) {
        guard currentVideoInfo != info else { return }
        currentVideoInfo = info
        TgoLogger.shared.info("[Video] Stats updated: \(info.resolutionString) \(info.bitrateString)")
        DispatchQueue.main.async {
            for listener in self.localVideoInfoListeners.values {
                listener(info)
            }
        }
    }

    public func join(roomInfo: RoomInfo,
              micEnabled: Bool = false,
              cameraEnabled: Bool = false,
              screenShareEnabled: Bool = false) async {
        if currentRoomInfo != nil {
            TgoLogger.shared.warning("已在房间中，无法重复加入")
            return
        }
        
        TgoLogger.shared.info("开始加入房间 - roomName: \(roomInfo.roomName), loginUID: \(roomInfo.loginUID)")
        TgoLogger.shared.debug("加入配置 - mic: \(micEnabled), camera: \(cameraEnabled), screenShare: \(screenShareEnabled)")
        
        self.currentRoomInfo = roomInfo
        notifyConnectionStatusChanged(roomName: roomInfo.roomName, status: .connecting)
        
        let roomOptions = RoomOptions(
            defaultCameraCaptureOptions: CameraCaptureOptions(
                position: .front,
                dimensions: .h1080_169, // 1080p - 更稳定
                fps: 30
            ),
            defaultVideoPublishOptions: VideoPublishOptions(
                encoding: VideoEncoding(
                    maxBitrate: 3_000_000, // 3 Mbps for 1080p
                    maxFps: 30
                ),
                simulcast: true
            ),
            adaptiveStream: true,
            dynacast: true
        )
        
        let room = Room(delegate: self, roomOptions: roomOptions)
        self.room = room
        
        do {
            TgoLogger.shared.debug("正在连接到服务器...")
            try await room.connect(url: roomInfo.url, token: roomInfo.token, connectOptions: ConnectOptions(
                autoSubscribe: true
            ))
            TgoLogger.shared.info("成功连接到房间 - roomName: \(roomInfo.roomName)")
            
            // Initial track setup
            if micEnabled {
                TgoLogger.shared.debug("初始化麦克风...")
                try await room.localParticipant.setMicrophone(enabled: true)
            }
            if cameraEnabled {
                TgoLogger.shared.debug("初始化摄像头...")
                try await room.localParticipant.setCamera(enabled: true)
            }
            if screenShareEnabled {
                TgoLogger.shared.debug("初始化屏幕共享...")
                try await room.localParticipant.setScreenShare(enabled: true)
            }
            
            startTimeoutChecker(timeoutSeconds: roomInfo.timeout)
            
        } catch {
            TgoLogger.shared.error("连接到房间失败: \(error.localizedDescription)")
            notifyConnectionStatusChanged(roomName: roomInfo.roomName, status: .disconnected)
            self.currentRoomInfo = nil
            self.room = nil
        }
    }
    
    public func leaveRoom() async {
        TgoLogger.shared.info("正在离开房间 - roomName: \(currentRoomInfo?.roomName ?? "unknown")")
        stopTimeoutChecker()
        await room?.disconnect()
        room = nil
        currentRoomInfo = nil
        ParticipantManager.shared.clear()
        TgoLogger.shared.info("已离开房间")
    }
    
    private func startTimeoutChecker(timeoutSeconds: Int) {
        timeoutTimer?.invalidate()
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkParticipantsTimeout(timeoutSeconds: timeoutSeconds)
        }
    }
    
    private func stopTimeoutChecker() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
    }
    
    private func checkParticipantsTimeout(timeoutSeconds: Int) {
        let now = Date()
        let participants = ParticipantManager.shared.getRemoteParticipants(includeTimeout: true)
        
        for participant in participants {
            if participant.isLocal() { continue }
            
            if participant.isJoined() {
                if participant.isTimeout {
                    participant.setTimeout(false)
                }
                continue
            }
            
            let elapsed = Int(now.timeIntervalSince(participant.createdAt))
            if elapsed >= timeoutSeconds && !participant.isTimeout {
                participant.setTimeout(true)
                TgoLogger.shared.info("参与者 \(participant.uid) 超时未加入")
            }
        }
    }
}

extension RoomManager: RoomDelegate {
    public func room(_ room: Room, didUpdateConnectionState state: ConnectionState, from oldState: ConnectionState) {
        guard let roomName = currentRoomInfo?.roomName else { return }
        
        TgoLogger.shared.info("房间连接状态变化 - roomName: \(roomName), \(oldState) -> \(state)")
        
        if case .connecting = state {
            notifyConnectionStatusChanged(roomName: roomName, status: .connecting)
        } else if case .connected = state {
            TgoLogger.shared.info("本地用户已连接到房间 - roomName: \(roomName)")
            notifyConnectionStatusChanged(roomName: roomName, status: .connected)
            ParticipantManager.shared.getLocalParticipant()?.setLocalParticipant(participant: room.localParticipant)
            ParticipantManager.shared.getLocalParticipant()?.notifyJoined()
        } else if case .disconnected = state {
            TgoLogger.shared.info("本地用户已断开连接 - roomName: \(roomName)")
            notifyConnectionStatusChanged(roomName: roomName, status: .disconnected)
            ParticipantManager.shared.getLocalParticipant()?.notifyLeave()
        } else if case .reconnecting = state {
            TgoLogger.shared.warning("正在重新连接 - roomName: \(roomName)")
            notifyConnectionStatusChanged(roomName: roomName, status: .connecting)
        }
    }
    
    public func room(_ room: Room, participantDidConnect participant: RemoteParticipant) {
        let identity = participant.identity?.stringValue ?? "unknown"
        TgoLogger.shared.info("远程用户连接 - uid: \(identity)")
        ParticipantManager.shared.setParticipantJoin(participant: participant)
    }
    
    public func room(_ room: Room, participantDidDisconnect participant: RemoteParticipant) {
        let identity = participant.identity?.stringValue ?? "unknown"
        TgoLogger.shared.info("远程用户断开连接 - uid: \(identity)")
        ParticipantManager.shared.setParticipantLeave(participant: participant)
    }
    
    public func room(_ room: Room, participant: Participant, didUpdatePublication publication: TrackPublication, muted: Bool) {
        // 处理本地和远程用户的 mute/unmute 事件
        let identity = participant.identity?.stringValue ?? "unknown"
        let sourceName = publication.source == Track.Source.microphone ? "麦克风" : (publication.source == Track.Source.camera ? "摄像头" : "其他")
        let isRemote = participant is RemoteParticipant
        
        TgoLogger.shared.info("轨道 mute 状态变化 (RoomDelegate) - uid: \(identity), source: \(sourceName), muted: \(muted), isRemote: \(isRemote)")
        
        // 通知对应的 TgoParticipant
        if isRemote {
            // 远程用户
            let participants = ParticipantManager.shared.getRemoteParticipants(includeTimeout: true)
            if let tgoParticipant = participants.first(where: { $0.uid == identity }) {
                tgoParticipant.handleTrackMuteChanged(source: publication.source, muted: muted)
            }
        } else {
            // 本地用户
            if let localParticipant = ParticipantManager.shared.getLocalParticipant() {
                localParticipant.handleTrackMuteChanged(source: publication.source, muted: muted)
            }
        }
    }
}
