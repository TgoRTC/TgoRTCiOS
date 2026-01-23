//
//  ParticipantManager.swift
//  TgoRTCIOS
//
//  Created by Slun on 2026/1/16.
//

import Foundation
import LiveKit

public final class ParticipantManager {
    public static let shared = ParticipantManager()
    
    private init() {
    }
    private var newParticipantListeners: [UUID: (TgoParticipant) -> Void] = [:]
    private var localParticipant: TgoParticipant?
    private var remoteParticipants: [String: TgoParticipant] = [:]
    
    public func getLocalParticipant() -> TgoParticipant? {
        guard let roomInfo = TgoRTC.shared.roomManager.currentRoomInfo else {
            return nil
        }
        
        let loginUID = roomInfo.loginUID
        let lkParticipant = TgoRTC.shared.roomManager.room?.localParticipant
        
        if localParticipant == nil {
            localParticipant = TgoParticipant(uid: loginUID, localParticipant: lkParticipant, remoteParticipant: nil)
        } else if let lkParticipant = lkParticipant {
            localParticipant?.setLocalParticipant(lkParticipant)
        }
        
        return localParticipant
    }
    
    public func getAllParticipants() -> [TgoParticipant] {
        var list: [TgoParticipant] = []
        if let local = getLocalParticipant() {
            list.append(local)
        }
        
        let remote = getRemoteParticipants()
        let filteredRemote = remote.filter { $0.uid != localParticipant?.uid }
        list.append(contentsOf: filteredRemote)
        
        TgoLogger.shared.debug("getAllParticipants() -> 返回 \(list.count) 个参与者: \(list.map { $0.uid }.joined(separator: ", "))")
        
        return list
    }
    
    public func getRemoteParticipants() -> [TgoParticipant] {
        guard let roomInfo = TgoRTC.shared.roomManager.currentRoomInfo else {
            return []
        }
        
        let lkParticipants = TgoRTC.shared.roomManager.room?.remoteParticipants ?? [:]
        let loginUID = roomInfo.loginUID
        
        var list: [TgoParticipant] = []
        var processedUids = Set<String>()
        
        // 1. 返回已缓存的远程参与者（不创建新的，避免重置 createdAt）
        for (uid, tgoParticipant) in remoteParticipants {
            if uid == loginUID { continue }
            
            // 检查是否有对应的 LiveKit 参与者
            if let lkParticipant = lkParticipants.values.first(where: { $0.identity?.stringValue == uid }) {
                // 如果还没设置 remoteParticipant，设置它
                if tgoParticipant.remoteParticipant == nil {
                    tgoParticipant.setRemoteParticipant(lkParticipant)
                }
            }
            
            list.append(tgoParticipant)
            processedUids.insert(uid)
        }
        
        // 2. 添加 LiveKit 中存在但未缓存的参与者（新加入的）
        for lkParticipant in lkParticipants.values {
            guard let identity = lkParticipant.identity?.stringValue else { continue }
            if identity == loginUID { continue }
            if processedUids.contains(identity) { continue }
            
            // 这是一个新的远程参与者，创建并缓存
            let tgoParticipant = TgoParticipant(uid: identity, localParticipant: nil, remoteParticipant: lkParticipant)
            remoteParticipants[identity] = tgoParticipant
            list.append(tgoParticipant)
        }
        
        return list
    }
    
    /// 初始化 uidList 中的待加入参与者（在加入房间时调用）
    /// 此方法在 join() 中同步调用，确保 UI 层可以立即获取 pending 状态的参与者
    public func initializePendingParticipants() {
        guard let roomInfo = TgoRTC.shared.roomManager.currentRoomInfo else { return }
        
        let loginUID = roomInfo.loginUID
        for uid in roomInfo.uidList {
            if uid == loginUID { continue }
            if remoteParticipants[uid] != nil { continue }
            
            // 创建待加入的参与者，此时 createdAt 记录为当前时间
            let tgoParticipant = TgoParticipant(uid: uid, localParticipant: nil, remoteParticipant: nil)
            remoteParticipants[uid] = tgoParticipant
            TgoLogger.shared.debug("初始化待加入参与者 - uid: \(uid)")
        }
    }
    
    /// 同步已在房间中的远程参与者（连接成功后调用）
    /// 此方法会检查 LiveKit 中已存在的参与者，并更新对应的 TgoParticipant 的 isJoined 状态
    public func syncExistingRemoteParticipants() {
        guard let room = TgoRTC.shared.roomManager.room else {
            TgoLogger.shared.warning("syncExistingRemoteParticipants: room 为空")
            return
        }
        guard let roomInfo = TgoRTC.shared.roomManager.currentRoomInfo else {
            TgoLogger.shared.warning("syncExistingRemoteParticipants: roomInfo 为空")
            return
        }
        
        let loginUID = roomInfo.loginUID
        let lkParticipants = room.remoteParticipants
        
        TgoLogger.shared.info("同步已在房间中的远程参与者 - LiveKit 参与者数量: \(lkParticipants.count)")
        
        for lkParticipant in lkParticipants.values {
            guard let identity = lkParticipant.identity?.stringValue else { continue }
            if identity == loginUID { continue }
            
            if let existing = remoteParticipants[identity] {
                // 已缓存的 pending 参与者，设置 remoteParticipant（触发 isJoined = true）
                if existing.remoteParticipant == nil {
                    TgoLogger.shared.debug("同步参与者 \(identity) - 设置 remoteParticipant，isJoined 将变为 true")
                    existing.setRemoteParticipant(lkParticipant)
                }
            } else {
                // 未知的参与者（不在 uidList 中），创建并通知
                TgoLogger.shared.info("发现新的远程参与者 - uid: \(identity)")
                let tgoParticipant = TgoParticipant(uid: identity, localParticipant: nil, remoteParticipant: lkParticipant)
                remoteParticipants[identity] = tgoParticipant
                
                // 添加到 uidList
                if !roomInfo.uidList.contains(identity) {
                    roomInfo.uidList.append(identity)
                }
                
                notifyNewParticipant(tgoParticipant)
            }
        }
    }

    public func missedParticipants(roomName: String, uids: [String]) {
        guard !uids.isEmpty else { return }
        
        // 判断是否是当前通话
        guard let currentRoomInfo = TgoRTC.shared.roomManager.currentRoomInfo,
              currentRoomInfo.roomName == roomName else {
            TgoLogger.shared.debug("missedParticipants: roomName(\(roomName)) 不是当前通话，跳过")
            return
        }
        
        TgoLogger.shared.info("移除超时参与者 - roomName: \(roomName), uids: \(uids)")
        
        var removedCount = 0
        for uid in uids {
            guard let tgoParticipant = remoteParticipants[uid] else {
                TgoLogger.shared.debug("参与者 \(uid) 不存在，跳过")
                continue
            }
            
            // 只移除尚未加入的参与者
            if !tgoParticipant.isJoined {
                tgoParticipant.notifyLeave(reason: .timeout)
                remoteParticipants.removeValue(forKey: uid)
                currentRoomInfo.uidList.removeAll { $0 == uid }
                removedCount += 1
                TgoLogger.shared.debug("参与者 \(uid) 已移除（超时未加入）")
            } else {
                TgoLogger.shared.debug("参与者 \(uid) 已加入，跳过移除")
            }
        }
        
        TgoLogger.shared.info("超时移除完成 - 共移除 \(removedCount) 个参与者")
    }
    
    public func inviteParticipant(roomName: String, uids: [String]) {
        guard let roomInfo = TgoRTC.shared.roomManager.currentRoomInfo else {
            TgoLogger.shared.warning("邀请参与者失败: 当前不在房间中")
            return
        }
        
        // 判断是否是当前通话
        guard roomInfo.roomName == roomName else {
            TgoLogger.shared.debug("inviteParticipant: roomName(\(roomName)) 不是当前通话，跳过")
            return
        }
        
        TgoLogger.shared.info("邀请参与者 - roomName: \(roomName), uids: \(uids)")
        
        let existingUids = Set(remoteParticipants.keys)
        var newUids = uids.filter { !existingUids.contains($0) }
        
        if newUids.isEmpty {
            TgoLogger.shared.debug("邀请的参与者已存在，无需重复添加")
            return
        }
        
        let currentCount = roomInfo.uidList.count
        let availableSlots = roomInfo.maxParticipants - currentCount
        
        if availableSlots <= 0 {
            TgoLogger.shared.error("已达到最大参与人数限制: \(roomInfo.maxParticipants)")
            return
        }
        
        if newUids.count > availableSlots {
            TgoLogger.shared.warning("邀请人数超出限制，最多还能添加 \(availableSlots) 人，实际邀请 \(newUids.count) 人")
            newUids = Array(newUids.prefix(availableSlots))
        }
        
        for uid in newUids {
            TgoLogger.shared.debug("添加待加入参与者 - uid: \(uid)")
            let tgoParticipant = TgoParticipant(uid: uid, localParticipant: nil, remoteParticipant: nil)
            remoteParticipants[uid] = tgoParticipant
            TgoRTC.shared.roomManager.currentRoomInfo?.uidList.append(uid)
            notifyNewParticipant(tgoParticipant)
            TgoLogger.shared.debug("通知新成员加入")
        }
        
        // 重启超时检查器
        TgoRTC.shared.roomManager.restartTimeoutCheckerIfNeeded()
    }
    
    public func setParticipantJoin(participant: RemoteParticipant) {
        guard let identity = participant.identity?.stringValue else {
            TgoLogger.shared.warning("参与者加入失败: identity 为空")
            return
        }
        
        TgoLogger.shared.info("处理参与者加入 - uid: \(identity)")
        
        if let existing = remoteParticipants[identity] {
            TgoLogger.shared.debug("更新已存在的参与者 - uid: \(identity)")
            existing.setRemoteParticipant(participant)
            return
        }
        
        if let roomInfo = TgoRTC.shared.roomManager.currentRoomInfo, !roomInfo.uidList.contains(identity) {
            roomInfo.uidList.append(identity)
        }
        
        TgoLogger.shared.info("创建新的远程参与者 - uid: \(identity)")
        let tgoParticipant = TgoParticipant(uid: identity, localParticipant: nil, remoteParticipant: participant)
        remoteParticipants[identity] = tgoParticipant
        notifyNewParticipant(tgoParticipant)
    }
    
    public func setParticipantLeave(participant: RemoteParticipant) {
        guard let identity = participant.identity?.stringValue else {
            TgoLogger.shared.warning("参与者离开处理失败: identity 为空")
            return
        }
        
        TgoLogger.shared.info("处理参与者离开 - uid: \(identity)")
        
        if let tgoParticipant = remoteParticipants[identity] {
            tgoParticipant.notifyLeave()
        }
        remoteParticipants.removeValue(forKey: identity)
        TgoRTC.shared.roomManager.currentRoomInfo?.uidList.removeAll { $0 == identity }
    }
    
    public func clear() {
        TgoLogger.shared.debug("清理所有参与者 - 本地: \(localParticipant != nil ? 1 : 0), 远程: \(remoteParticipants.count)")
        localParticipant?.dispose()
        localParticipant = nil
        for p in remoteParticipants.values {
            p.dispose()
        }
        remoteParticipants.removeAll()
        TgoLogger.shared.info("参与者清理完成")
    }
    
    private func notifyNewParticipant(_ participant: TgoParticipant) {
        DispatchQueue.main.async {
            for listener in self.newParticipantListeners.values {
                listener(participant)
            }
        }
    }
    
    public func addNewParticipantListener(_ listener: @escaping (TgoParticipant) -> Void) -> ListenerToken {
        let id = UUID()
        newParticipantListeners[id] = listener
        return ListenerToken { [weak self] in
            self?.newParticipantListeners.removeValue(forKey: id)
        }
    }
}
