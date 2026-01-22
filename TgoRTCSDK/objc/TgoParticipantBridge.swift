//
//  TgoParticipantBridge.swift
//  TgoRTCSDK
//
//  Created by Cursor on 2026/01/22.
//

import Foundation
import Combine

/// Delegate protocol for participant events (Objective-C compatible)
@objc public protocol TgoParticipantDelegateObjC: AnyObject {
    @objc optional func participant(_ participant: TgoParticipantBridge, didUpdateMicrophoneOn isOn: Bool)
    @objc optional func participant(_ participant: TgoParticipantBridge, didUpdateCameraOn isOn: Bool)
    @objc optional func participant(_ participant: TgoParticipantBridge, didUpdateSpeaking isSpeaking: Bool)
    @objc optional func participant(_ participant: TgoParticipantBridge, didUpdateAudioLevel level: Float)
    @objc optional func participant(_ participant: TgoParticipantBridge, didUpdateConnectionQuality quality: TgoConnectionQualityObjC)
    @objc optional func participant(_ participant: TgoParticipantBridge, didUpdateVideoInfo info: TgoVideoInfoObjC)
    @objc optional func participantDidJoin(_ participant: TgoParticipantBridge)
    @objc optional func participantDidLeave(_ participant: TgoParticipantBridge)
    @objc optional func participantDidTimeout(_ participant: TgoParticipantBridge)
}

/// Objective-C compatible bridge for participant information and control
@objcMembers
public class TgoParticipantBridge: NSObject {
    public weak var delegate: TgoParticipantDelegateObjC?
    internal let swiftParticipant: TgoParticipant
    private var cancellables = Set<AnyCancellable>()
    
    // Properties
    public var uid: String { swiftParticipant.uid }
    public var isLocal: Bool { swiftParticipant.isLocal }
    public var isMicrophoneOn: Bool { swiftParticipant.isMicrophoneOn }
    public var isCameraOn: Bool { swiftParticipant.isCameraOn }
    public var isSpeaking: Bool { swiftParticipant.isSpeaking }
    public var audioLevel: Float { swiftParticipant.audioLevel }
    public var isJoined: Bool { swiftParticipant.isJoined }
    public var isTimeout: Bool { swiftParticipant.isTimeout }
    
    public var connectionQuality: TgoConnectionQualityObjC {
        switch swiftParticipant.connectionQuality {
        case .unknown: return .unknown
        case .excellent: return .excellent
        case .good: return .good
        case .poor: return .poor
        case .lost: return .lost
        }
    }
    
    public var videoInfo: TgoVideoInfoObjC {
        return TgoVideoInfoObjC(from: swiftParticipant.videoInfo)
    }
    
    public var cameraPosition: TgoCameraPositionObjC {
        return (swiftParticipant.cameraPosition == .front) ? .front : .back
    }
    
    internal init(swiftParticipant: TgoParticipant) {
        self.swiftParticipant = swiftParticipant
        super.init()
        setupBindings()
    }
    
    private func setupBindings() {
        // Observe property changes using Combine and notify delegate
        swiftParticipant.$isMicrophoneOn
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isOn in
                guard let self = self else { return }
                self.delegate?.participant?(self, didUpdateMicrophoneOn: isOn)
            }
            .store(in: &cancellables)
            
        swiftParticipant.$isCameraOn
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isOn in
                guard let self = self else { return }
                self.delegate?.participant?(self, didUpdateCameraOn: isOn)
            }
            .store(in: &cancellables)
            
        swiftParticipant.$isSpeaking
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isSpeaking in
                guard let self = self else { return }
                self.delegate?.participant?(self, didUpdateSpeaking: isSpeaking)
            }
            .store(in: &cancellables)
            
        swiftParticipant.$audioLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                guard let self = self else { return }
                self.delegate?.participant?(self, didUpdateAudioLevel: level)
            }
            .store(in: &cancellables)
            
        swiftParticipant.$connectionQuality
            .receive(on: DispatchQueue.main)
            .sink { [weak self] quality in
                guard let self = self else { return }
                let objcQuality: TgoConnectionQualityObjC
                switch quality {
                case .unknown: objcQuality = .unknown
                case .excellent: objcQuality = .excellent
                case .good: objcQuality = .good
                case .poor: objcQuality = .poor
                case .lost: objcQuality = .lost
                }
                self.delegate?.participant?(self, didUpdateConnectionQuality: objcQuality)
            }
            .store(in: &cancellables)
            
        swiftParticipant.$videoInfo
            .receive(on: DispatchQueue.main)
            .sink { [weak self] info in
                guard let self = self else { return }
                self.delegate?.participant?(self, didUpdateVideoInfo: TgoVideoInfoObjC(from: info))
            }
            .store(in: &cancellables)
            
        // Event publishers
        swiftParticipant.onJoined
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.delegate?.participantDidJoin?(self)
            }
            .store(in: &cancellables)
            
        swiftParticipant.onLeave
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.delegate?.participantDidLeave?(self)
            }
            .store(in: &cancellables)
            
        swiftParticipant.onTimeout
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.delegate?.participantDidTimeout?(self)
            }
            .store(in: &cancellables)
    }
    
    // Control methods
    public func setMicrophoneEnabled(_ enabled: Bool, completion: ((Bool) -> Void)?) {
        Task {
            await swiftParticipant.setMicrophoneEnabled(enabled)
            DispatchQueue.main.async { completion?(true) }
        }
    }
    
    public func setCameraEnabled(_ enabled: Bool, completion: ((Bool) -> Void)?) {
        Task {
            await swiftParticipant.setCameraEnabled(enabled)
            DispatchQueue.main.async { completion?(true) }
        }
    }
    
    public func switchCamera() {
        swiftParticipant.switchCamera()
    }
    
    public func setSpeakerphoneOn(_ enabled: Bool, completion: ((Bool) -> Void)?) {
        Task {
            await swiftParticipant.setSpeakerphoneOn(enabled)
            DispatchQueue.main.async { completion?(true) }
        }
    }
}
