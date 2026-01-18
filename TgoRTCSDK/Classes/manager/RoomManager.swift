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
            TgoLogger.shared.warning("already in room")
            return
        }
        
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
            try await room.connect(url: roomInfo.url, token: roomInfo.token, connectOptions: ConnectOptions(
                autoSubscribe: true
            ))
            
            // Initial track setup
            if micEnabled {
                try await room.localParticipant.setMicrophone(enabled: true)
            }
            if cameraEnabled {
                try await room.localParticipant.setCamera(enabled: true)
            }
            if screenShareEnabled {
                try await room.localParticipant.setScreenShare(enabled: true)
            }
            
            startTimeoutChecker(timeoutSeconds: roomInfo.timeout)
            
        } catch {
            TgoLogger.shared.error("连接到房间错误: \(error.localizedDescription)")
            notifyConnectionStatusChanged(roomName: roomInfo.roomName, status: .disconnected)
            self.currentRoomInfo = nil
            self.room = nil
        }
    }
    
    public func leaveRoom() async {
        stopTimeoutChecker()
        await room?.disconnect()
        room = nil
        currentRoomInfo = nil
        ParticipantManager.shared.clear()
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
        
        if case .connecting = state {
            notifyConnectionStatusChanged(roomName: roomName, status: .connecting)
        } else if case .connected = state {
            notifyConnectionStatusChanged(roomName: roomName, status: .connected)
            ParticipantManager.shared.getLocalParticipant()?.setLocalParticipant(participant: room.localParticipant)
            ParticipantManager.shared.getLocalParticipant()?.notifyJoined()
        } else if case .disconnected = state {
            notifyConnectionStatusChanged(roomName: roomName, status: .disconnected)
            ParticipantManager.shared.getLocalParticipant()?.notifyLeave()
        } else if case .reconnecting = state {
            notifyConnectionStatusChanged(roomName: roomName, status: .connecting)
        }
    }
    
    public func room(_ room: Room, participantDidConnect participant: RemoteParticipant) {
        ParticipantManager.shared.setParticipantJoin(participant: participant)
    }
    
    public func room(_ room: Room, participantDidDisconnect participant: RemoteParticipant) {
        ParticipantManager.shared.setParticipantLeave(participant: participant)
    }
    
    public func room(_ room: Room, participant: Participant, didUpdatePublication publication: TrackPublication, muted: Bool) {
        // Handle mute updates if needed, but TgoParticipant will handle its own listeners
    }
}
