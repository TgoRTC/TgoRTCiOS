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

    /// 加入房间（非阻塞版本）
    /// 调用后立即返回，连接过程在后台进行。
    /// UI 层可以立即调用 getAllParticipants() 获取参与者列表（pending 状态）。
    /// 连接状态变化通过 addConnectionStatusListener 监听。
    public func join(roomInfo: RoomInfo,
                     micEnabled: Bool = false,
                     cameraEnabled: Bool = false,
                     screenShareEnabled: Bool = false) {
        if currentRoomInfo != nil {
            TgoLogger.shared.warning("已在房间中，无法重复加入")
            return
        }
        
        TgoLogger.shared.info("开始加入房间 - roomName: \(roomInfo.roomName), loginUID: \(roomInfo.loginUID)")
        TgoLogger.shared.debug("加入配置 - mic: \(micEnabled), camera: \(cameraEnabled), screenShare: \(screenShareEnabled)")
        
        // 1. 同步设置 roomInfo
        self.currentRoomInfo = roomInfo
        
        // 2. 立即初始化待加入参与者（UI 层可立即获取 pending 状态的参与者）
        ParticipantManager.shared.initializePendingParticipants()
        
        // 3. 通知连接中状态
        notifyConnectionStatusChanged(roomName: roomInfo.roomName, status: .connecting)
        
        // 4. 后台执行连接
        Task {
            await connectInternal(roomInfo: roomInfo,
                                  micEnabled: micEnabled,
                                  cameraEnabled: cameraEnabled,
                                  screenShareEnabled: screenShareEnabled)
        }
    }
    
    /// 内部异步连接方法
    private func connectInternal(roomInfo: RoomInfo,
                                 micEnabled: Bool,
                                 cameraEnabled: Bool,
                                 screenShareEnabled: Bool) async {
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
        // 确保在主线程创建 Timer
        DispatchQueue.main.async { [weak self] in
            self?.timeoutTimer?.invalidate()
            TgoLogger.shared.info("启动超时检查器 - 超时时间: \(timeoutSeconds)秒")
            self?.timeoutTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.checkParticipantsTimeout(timeoutSeconds: timeoutSeconds)
            }
        }
    }
    
    /// 重启超时检查器（当有新参与者被邀请时调用）
    public func restartTimeoutCheckerIfNeeded() {
        guard let roomInfo = currentRoomInfo, timeoutTimer == nil else { return }
        startTimeoutChecker(timeoutSeconds: roomInfo.timeout)
    }
    
    private func stopTimeoutChecker() {
        DispatchQueue.main.async { [weak self] in
            self?.timeoutTimer?.invalidate()
            self?.timeoutTimer = nil
        }
    }
    
    private func checkParticipantsTimeout(timeoutSeconds: Int) {
        let now = Date()
        let participants = ParticipantManager.shared.getRemoteParticipants()
        
        // 收集超时的参与者 uid
        var timeoutUids: [String] = []
        var pendingCount = 0
        
        for participant in participants {
            if participant.isLocal { continue }
            
            // 已加入的参与者，跳过
            if participant.isJoined {
                continue
            }
            
            // 待加入的参与者
            pendingCount += 1
            
            let elapsed = Int(now.timeIntervalSince(participant.createdAt))
            if elapsed >= timeoutSeconds {
                TgoLogger.shared.info("参与者 \(participant.uid) 超时未加入 (已等待 \(elapsed)秒, 阈值 \(timeoutSeconds)秒)")
                timeoutUids.append(participant.uid)
                pendingCount -= 1
            }
        }
        
        // 移除超时的参与者
        if !timeoutUids.isEmpty, let roomName = currentRoomInfo?.roomName {
            ParticipantManager.shared.missedParticipants(roomName: roomName, uids: timeoutUids)
        }
        
        // 如果没有待处理的参与者了，停止计时器
        if pendingCount == 0 && !participants.isEmpty {
            TgoLogger.shared.debug("所有参与者已处理完毕，停止超时检查器")
            stopTimeoutChecker()
        }
    }
}

extension RoomManager: RoomDelegate {
    
    public func room(_ room: Room, didUpdateConnectionState state: ConnectionState, from oldState: ConnectionState) {
        guard let roomName = currentRoomInfo?.roomName else { return }
        
        switch state {
        case .connecting:
            notifyConnectionStatusChanged(roomName: roomName, status: .connecting)
        case .connected:
            notifyConnectionStatusChanged(roomName: roomName, status: .connected)
            ParticipantManager.shared.getLocalParticipant()?.setLocalParticipant(room.localParticipant)
            // 同步已在房间中的远程参与者（触发 isJoined 状态更新）
            ParticipantManager.shared.syncExistingRemoteParticipants()
        case .disconnected:
            notifyConnectionStatusChanged(roomName: roomName, status: .disconnected)
            ParticipantManager.shared.getLocalParticipant()?.notifyLeave()
        case .reconnecting:
            notifyConnectionStatusChanged(roomName: roomName, status: .connecting)
        @unknown default:
            break
        }
    }
    
    public func room(_ room: Room, participantDidConnect participant: RemoteParticipant) {
        ParticipantManager.shared.setParticipantJoin(participant: participant)
    }
    
    public func room(_ room: Room, participantDidDisconnect participant: RemoteParticipant) {
        ParticipantManager.shared.setParticipantLeave(participant: participant)
    }
    
    // 轨道事件由 TgoParticipant 的 ParticipantDelegate 自己处理
    // RoomDelegate 不需要重复处理
}
