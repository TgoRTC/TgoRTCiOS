//
//  TgoRoomBridge.swift
//  TgoRTCSDK
//
//  Created by Cursor on 2026/01/22.
//

import Foundation

/// Delegate protocol for room events (Objective-C compatible)
@objc public protocol TgoRoomDelegateObjC: AnyObject {
    /// Called when the connection status of the room changes
    @objc optional func room(_ roomName: String, didChangeStatus status: TgoConnectStatusObjC)
    
    /// Called when the local video info is updated
    @objc optional func room(_ roomName: String, didUpdateVideoInfo info: TgoVideoInfoObjC)
}

/// Objective-C compatible bridge for room management
@objcMembers
public class TgoRoomBridge: NSObject {
    public weak var delegate: TgoRoomDelegateObjC?
    
    private var connectionToken: ListenerToken?
    private var videoInfoToken: ListenerToken?
    
    public override init() {
        super.init()
        setupListeners()
    }
    
    private func setupListeners() {
        connectionToken = RoomManager.shared.addConnectionStatusListener { [weak self] roomName, status in
            let objcStatus: TgoConnectStatusObjC
            switch status {
            case .connecting: objcStatus = .connecting
            case .connected: objcStatus = .connected
            case .disconnected: objcStatus = .disconnected
            }
            self?.delegate?.room?(roomName, didChangeStatus: objcStatus)
        }
        
        videoInfoToken = RoomManager.shared.addVideoInfoListener { [weak self] info in
            let objcInfo = TgoVideoInfoObjC(from: info)
            let roomName = RoomManager.shared.currentRoomInfo?.roomName ?? ""
            self?.delegate?.room?(roomName, didUpdateVideoInfo: objcInfo)
        }
    }
    
    /// Join a room (non-blocking)
    /// The completion callback is called immediately after initiating the join.
    /// Use the delegate's room(_:didChangeStatus:) to monitor connection status.
    public func join(roomInfo: TgoRoomInfoObjC,
                    micEnabled: Bool,
                    cameraEnabled: Bool,
                    completion: ((Bool) -> Void)?) {
        // join 是非阻塞方法，调用后立即返回，连接在后台进行
        RoomManager.shared.join(
            roomInfo: roomInfo.toSwift(),
            micEnabled: micEnabled,
            cameraEnabled: cameraEnabled
        )
        // 立即回调，表示加入请求已发起
        DispatchQueue.main.async {
            completion?(true)
        }
    }
    
    /// Leave the current room
    public func leaveRoom(completion: (() -> Void)?) {
        Task {
            await RoomManager.shared.leaveRoom()
            DispatchQueue.main.async {
                completion?()
            }
        }
    }
    
    deinit {
        connectionToken?.cancel()
        videoInfoToken?.cancel()
    }
}
