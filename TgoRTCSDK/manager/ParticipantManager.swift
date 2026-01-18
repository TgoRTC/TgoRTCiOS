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
            localParticipant?.setLocalParticipant(participant: lkParticipant)
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
                tgoParticipant.setRemoteParticipant(participant: lkParticipant)
                if tgoParticipant.isTimeout {
                    tgoParticipant.setTimeout(false)
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
            
            tgoParticipant.setRemoteParticipant(participant: lkParticipant)
            if tgoParticipant.isTimeout {
                tgoParticipant.setTimeout(false)
            }
            list.append(tgoParticipant)
        }
        
        return list
    }
    
    public func inviteParticipant(uids: [String]) {
        guard let roomInfo = TgoRTC.shared.roomManager.currentRoomInfo else { return }
        
        let existingUids = Set(remoteParticipants.keys)
        var newUids = uids.filter { !existingUids.contains($0) }
        
        if newUids.isEmpty { return }
        
        let currentCount = roomInfo.uidList.count
        let availableSlots = roomInfo.maxParticipants - currentCount
        
        if availableSlots <= 0 {
            TgoLogger.shared.error("已达到最大参与人数限制: \(roomInfo.maxParticipants)")
            return
        }
        
        if newUids.count > availableSlots {
            TgoLogger.shared.error("邀请人数超出限制，最多还能添加 \(availableSlots) 人，实际邀请 \(newUids.count) 人")
            newUids = Array(newUids.prefix(availableSlots))
        }
        
        for uid in newUids {
            let tgoParticipant = TgoParticipant(uid: uid, localParticipant: nil, remoteParticipant: nil)
            remoteParticipants[uid] = tgoParticipant
            notifyNewParticipant(tgoParticipant)
            TgoRTC.shared.roomManager.currentRoomInfo?.uidList.append(uid)
        }
    }
    
    public func setParticipantJoin(participant: RemoteParticipant) {
        guard let identity = participant.identity?.stringValue else { return }
        
        if let existing = remoteParticipants[identity] {
            existing.setRemoteParticipant(participant: participant)
            return
        }
        
        if let roomInfo = TgoRTC.shared.roomManager.currentRoomInfo, !roomInfo.uidList.contains(identity) {
            roomInfo.uidList.append(identity)
        }
        
        let tgoParticipant = TgoParticipant(uid: identity, localParticipant: nil, remoteParticipant: participant)
        remoteParticipants[identity] = tgoParticipant
        notifyNewParticipant(tgoParticipant)
    }
    
    public func setParticipantLeave(participant: RemoteParticipant) {
        guard let identity = participant.identity?.stringValue else { return }
        
        if let tgoParticipant = remoteParticipants[identity] {
            tgoParticipant.notifyLeave()
        }
        remoteParticipants.removeValue(forKey: identity)
        TgoRTC.shared.roomManager.currentRoomInfo?.uidList.removeAll { $0 == identity }
    }
    
    public func clear() {
        localParticipant?.dispose()
        localParticipant = nil
        for p in remoteParticipants.values {
            p.dispose()
        }
        remoteParticipants.removeAll()
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
