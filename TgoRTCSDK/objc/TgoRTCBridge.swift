//
//  TgoRTCBridge.swift
//  TgoRTCSDK
//
//  Created by Cursor on 2026/01/22.
//

import Foundation

/// Main entry point for TgoRTC SDK (Objective-C compatible)
@objcMembers
public class TgoRTCBridge: NSObject {
    /// Singleton instance
    @objc public static let shared = TgoRTCBridge()
    
    public let room: TgoRoomBridge = TgoRoomBridge()
    public let audio: TgoAudioBridge = TgoAudioBridge()
    
    private var participantBridges: [String: TgoParticipantBridge] = [:]
    private var newParticipantToken: ListenerToken?
    
    /// Delegate for global participant events
    public weak var participantDelegate: TgoParticipantDelegateObjC?
    
    private override init() {
        super.init()
        setupListeners()
    }
    
    private func setupListeners() {
        newParticipantToken = ParticipantManager.shared.addNewParticipantListener { [weak self] swiftParticipant in
            guard let self = self else { return }
            let bridge = self.getOrCreateBridge(for: swiftParticipant)
            self.participantDelegate?.participantDidJoin?(bridge)
        }
    }
    
    /// Configure the SDK
    public func configure(options: TgoOptionsObjC?) {
        TgoRTC.shared.configure(options: options?.toSwift())
    }
    
    /// Get the local participant
    public func getLocalParticipant() -> TgoParticipantBridge? {
        guard let swiftParticipant = ParticipantManager.shared.getLocalParticipant() else {
            return nil
        }
        return getOrCreateBridge(for: swiftParticipant)
    }
    
    /// Get all participants in the room
    public func getAllParticipants(includeTimeout: Bool = false) -> [TgoParticipantBridge] {
        let swiftParticipants = ParticipantManager.shared.getAllParticipants(includeTimeout: includeTimeout)
        return swiftParticipants.map { getOrCreateBridge(for: $0) }
    }
    
    /// Get remote participants in the room
    public func getRemoteParticipants(includeTimeout: Bool = false) -> [TgoParticipantBridge] {
        let swiftParticipants = ParticipantManager.shared.getRemoteParticipants(includeTimeout: includeTimeout)
        return swiftParticipants.map { getOrCreateBridge(for: $0) }
    }
    
    /// Invite participants to the room
    public func inviteParticipant(uids: [String]) {
        ParticipantManager.shared.inviteParticipant(uids: uids)
    }
    
    /// Mark participants as missed/timeout
    public func missedParticipants(roomName: String, uids: [String]) {
        ParticipantManager.shared.missedParticipants(roomName: roomName, uids: uids)
    }
    
    // Internal helper to manage bridge instances
    private func getOrCreateBridge(for swiftParticipant: TgoParticipant) -> TgoParticipantBridge {
        if let existing = participantBridges[swiftParticipant.uid] {
            return existing
        }
        let newBridge = TgoParticipantBridge(swiftParticipant: swiftParticipant)
        newBridge.delegate = self.participantDelegate
        participantBridges[swiftParticipant.uid] = newBridge
        return newBridge
    }
    
    deinit {
        newParticipantToken?.cancel()
    }
}
