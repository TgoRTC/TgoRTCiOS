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
    
    public func getAllParticipants(includeTimeout: Bool = false) -> [TgoParticipant] {
        var list: [TgoParticipant] = []
        if let local = getLocalParticipant() {
            list.append(local)
        }
        
        let remote = getRemoteParticipants(includeTimeout: includeTimeout)
        let filteredRemote = remote.filter { $0.uid != localParticipant?.uid }
        list.append(contentsOf: filteredRemote)
        
        return list
    }
    
    public func getRemoteParticipants(includeTimeout: Bool = false) -> [TgoParticipant] {
        guard let roomInfo = TgoRTC.shared.roomManager.currentRoomInfo else {
            return []
        }
        
        let lkParticipants = TgoRTC.shared.roomManager.room?.remoteParticipants ?? [:]
        let uidList = roomInfo.uidList
        let loginUID = roomInfo.loginUID
        
        var list: [TgoParticipant] = []
        var addedUids = Set<String>()
        
        // 1. Process uidList from roomInfo
        for uid in uidList {
            if uid == loginUID { continue }
            
            let lkParticipant = lkParticipants.values.first { $0.identity?.stringValue == uid }
            
            let tgoParticipant: TgoParticipant
            if let existing = remoteParticipants[uid] {
                tgoParticipant = existing
            } else {
                tgoParticipant = TgoParticipant(uid: uid, localParticipant: nil, remoteParticipant: lkParticipant)
                remoteParticipants[uid] = tgoParticipant
            }
            
            if let lkParticipant = lkParticipant {
                tgoParticipant.setRemoteParticipant(lkParticipant)
                if tgoParticipant.isTimeout {
                    tgoParticipant.markTimeout(false)
                }
            }
            
            if includeTimeout || !tgoParticipant.isTimeout {
                list.append(tgoParticipant)
            }
            addedUids.insert(uid)
        }
        
        // 2. Add other participants from LiveKit not in uidList
        for lkParticipant in lkParticipants.values {
            guard let identity = lkParticipant.identity?.stringValue else { continue }
            if addedUids.contains(identity) { continue }
            
            let tgoParticipant: TgoParticipant
            if let existing = remoteParticipants[identity] {
                tgoParticipant = existing
            } else {
                tgoParticipant = TgoParticipant(uid: identity, localParticipant: nil, remoteParticipant: lkParticipant)
                remoteParticipants[identity] = tgoParticipant
            }
            
            tgoParticipant.setRemoteParticipant(lkParticipant)
            if tgoParticipant.isTimeout {
                tgoParticipant.markTimeout(false)
            }
            list.append(tgoParticipant)
        }
        
        return list
    }
    
    public func inviteParticipant(uids: [String]) {
        guard let roomInfo = TgoRTC.shared.roomManager.currentRoomInfo else {
            TgoLogger.shared.warning("邀请参与者失败: 当前不在房间中")
            return
        }
        
        TgoLogger.shared.info("邀请参与者 - uids: \(uids)")
        
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
            notifyNewParticipant(tgoParticipant)
            TgoRTC.shared.roomManager.currentRoomInfo?.uidList.append(uid)
        }
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
