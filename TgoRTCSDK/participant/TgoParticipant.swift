//
//  TgoParticipant.swift
//  TgoRTCIOS
//
//  Created by Slun on 2026/1/16.
//
import Foundation
import LiveKit
import Combine
import AVFoundation

/// Represents a participant in a room (local or remote).
/// 使用 Combine 的 @Published 属性来通知状态变化，符合 SwiftUI 的数据流模式
public final class TgoParticipant: NSObject, ObservableObject {
    
    // MARK: - Identity
    
    public let uid: String
    public let createdAt: Date = Date()
    
    // MARK: - Published State (SwiftUI 可直接绑定)
    
    @Published public private(set) var isMicrophoneOn: Bool = false
    @Published public private(set) var isCameraOn: Bool = false
    @Published public private(set) var isSpeaking: Bool = false
    @Published public private(set) var audioLevel: Float = 0
    @Published public private(set) var connectionQuality: TgoConnectionQuality = .unknown
    @Published public private(set) var cameraPosition: TgoCameraPosition = .front
    @Published public private(set) var isTimeout: Bool = false
    @Published public private(set) var hasJoined: Bool = false
    @Published public private(set) var videoInfo: VideoInfo = .empty
    
    // MARK: - Event Publishers (一次性事件)
    
    public let onJoined = PassthroughSubject<Void, Never>()
    public let onLeave = PassthroughSubject<Void, Never>()
    public let onTimeout = PassthroughSubject<Void, Never>()
    public let onTrackPublished = PassthroughSubject<Void, Never>()
    public let onTrackUnpublished = PassthroughSubject<Void, Never>()
    
    // MARK: - Internal State
    
    public private(set) var localParticipant: LocalParticipant?
    public private(set) var remoteParticipant: RemoteParticipant?
    
    private var isDisposed = false
    private var audioLevelTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    public var isLocal: Bool {
        localParticipant != nil || uid == TgoRTC.shared.roomManager.currentRoomInfo?.loginUID
    }
    
    // MARK: - Init
    
    public init(uid: String, localParticipant: LocalParticipant? = nil, remoteParticipant: RemoteParticipant? = nil) {
        self.uid = uid
        self.localParticipant = localParticipant
        self.remoteParticipant = remoteParticipant
        super.init()
        setupDelegate()
        updateState()
    }
    
    // MARK: - Get Video Track
    
    public func getVideoTrack(source: Track.Source = .camera) -> VideoTrack? {
        let participant = localParticipant ?? remoteParticipant
        return participant?.videoTracks.first { $0.source == source }?.track as? VideoTrack
    }
    
    // MARK: - Set Participant
    
    public func setLocalParticipant(_ participant: LocalParticipant) {
        self.localParticipant = participant
        setupDelegate()
        updateState()
        
        hasJoined = true
        onJoined.send()
    }
    
    public func setRemoteParticipant(_ participant: RemoteParticipant) {
        self.remoteParticipant = participant
        setupDelegate()
        updateState()
        
        hasJoined = true
        onJoined.send()
        
        if !participant.trackPublications.isEmpty {
            onTrackPublished.send()
        }
    }
    
    public func markTimeout(_ value: Bool) {
        isTimeout = value
        if value {
            onTimeout.send()
        }
    }
    
    public func notifyLeave() {
        guard !isDisposed else { return }
        onLeave.send()
        dispose()
    }

    public func setSpeakerphoneOn(_ enabled: Bool) async {
        await TgoRTC.shared.audioManager.setSpeakerphoneOn(enabled)
    }
    
    // MARK: - Control Methods (Local only)
    
    public func setMicrophoneEnabled(_ enabled: Bool) async {
        guard let local = localParticipant else { return }
        do {
            try await local.setMicrophone(enabled: enabled)
            await MainActor.run { isMicrophoneOn = enabled }
        } catch {
            TgoLogger.shared.error("设置麦克风失败: \(error.localizedDescription)")
        }
    }
    
    public func setCameraEnabled(_ enabled: Bool) async {
        guard let local = localParticipant else { return }
        do {
            try await local.setCamera(enabled: enabled)
            await MainActor.run { isCameraOn = enabled }
        } catch {
            TgoLogger.shared.error("设置摄像头失败: \(error.localizedDescription)")
        }
    }
    
    public func setScreenShareEnabled(_ enabled: Bool) async {
        guard let local = localParticipant else { return }
        do {
            try await local.setScreenShare(enabled: enabled)
        } catch {
            TgoLogger.shared.error("设置屏幕共享失败: \(error.localizedDescription)")
        }
    }
    
    public func switchCamera() {
        guard let local = localParticipant,
              let cameraTrack = local.localVideoTracks.first(where: { $0.source == .camera })?.track as? LocalVideoTrack,
              let cameraCapturer = cameraTrack.capturer as? CameraCapturer else { return }
        
        Task {
            do {
                let success = try await cameraCapturer.switchCameraPosition()
                if success {
                    await MainActor.run {
                        cameraPosition = (cameraPosition == .front) ? .back : .front
                    }
                }
            } catch {
                TgoLogger.shared.error("切换摄像头失败: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupDelegate() {
        localParticipant?.add(delegate: self)
        remoteParticipant?.add(delegate: self)
    }
    
    private func updateState() {
        if let local = localParticipant {
            isMicrophoneOn = local.isMicrophoneEnabled()
            isCameraOn = local.isCameraEnabled()
            isSpeaking = local.isSpeaking
            audioLevel = Float(local.audioLevel)
        } else if let remote = remoteParticipant {
            isMicrophoneOn = remote.trackPublications.values.contains { $0.source == .microphone && !$0.isMuted }
            isCameraOn = remote.trackPublications.values.contains { $0.source == .camera && !$0.isMuted }
            isSpeaking = remote.isSpeaking
            audioLevel = Float(remote.audioLevel)
        }
    }
    
    // MARK: - Dispose
    
    public func dispose() {
        guard !isDisposed else { return }
        isDisposed = true
        
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
        
        localParticipant?.remove(delegate: self)
        remoteParticipant?.remove(delegate: self)
        
        cancellables.removeAll()
        
        localParticipant = nil
        remoteParticipant = nil
    }
}

// MARK: - ParticipantDelegate
extension TgoParticipant: ParticipantDelegate {
    
    public func participant(_ participant: Participant, trackPublication: TrackPublication, didUpdateIsMuted isMuted: Bool) {
        guard !isDisposed else { return }
        let enabled = !isMuted
        
        DispatchQueue.main.async {
            switch trackPublication.source {
            case .microphone:
                self.isMicrophoneOn = enabled
            case .camera:
                self.isCameraOn = enabled
            default:
                break
            }
        }
    }
    
    public func participant(_ participant: Participant, didUpdateIsSpeaking speaking: Bool) {
        guard !isDisposed else { return }
        DispatchQueue.main.async {
            self.isSpeaking = speaking
            self.audioLevel = Float(participant.audioLevel)
        }
    }
    
    public func participant(_ participant: Participant, didUpdateConnectionQuality quality: ConnectionQuality) {
        guard !isDisposed else { return }
        DispatchQueue.main.async {
            self.connectionQuality = TgoConnectionQuality(from: quality)
        }
    }
    
    public func participant(_ participant: RemoteParticipant, didSubscribeTrack publication: RemoteTrackPublication) {
        guard !isDisposed else { return }
        DispatchQueue.main.async {
            switch publication.source {
            case .microphone:
                self.isMicrophoneOn = !publication.isMuted
            case .camera:
                self.isCameraOn = !publication.isMuted
            default:
                break
            }
            self.onTrackPublished.send()
        }
    }
    
    public func participant(_ participant: RemoteParticipant, didUnsubscribeTrack publication: RemoteTrackPublication) {
        guard !isDisposed else { return }
        DispatchQueue.main.async {
            switch publication.source {
            case .microphone:
                self.isMicrophoneOn = false
            case .camera:
                self.isCameraOn = false
            default:
                break
            }
            self.onTrackUnpublished.send()
        }
    }
    
    public func participant(_ participant: LocalParticipant, didPublishTrack publication: LocalTrackPublication) {
        guard !isDisposed else { return }
        DispatchQueue.main.async {
            switch publication.source {
            case .microphone:
                self.isMicrophoneOn = true
            case .camera:
                self.isCameraOn = true
            default:
                break
            }
            self.onTrackPublished.send()
        }
    }
    
    public func participant(_ participant: LocalParticipant, didUnpublishTrack publication: LocalTrackPublication) {
        guard !isDisposed else { return }
        DispatchQueue.main.async {
            switch publication.source {
            case .microphone:
                self.isMicrophoneOn = false
            case .camera:
                self.isCameraOn = false
            default:
                break
            }
            self.onTrackUnpublished.send()
        }
    }
}

// MARK: - TgoConnectionQuality Extension
extension TgoConnectionQuality {
    init(from quality: ConnectionQuality) {
        switch quality {
        case .excellent: self = .excellent
        case .good: self = .good
        case .poor: self = .poor
        case .lost: self = .lost
        default: self = .unknown
        }
    }
}
