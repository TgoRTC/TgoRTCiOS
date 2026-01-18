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

public typealias TgoVideoInfoListener = (VideoInfo) -> Void

public final class TgoParticipant: NSObject, ObservableObject {
    public var uid: String
    public var localParticipant: LocalParticipant?
    public var remoteParticipant: RemoteParticipant?
    
    // Video info related
    private var videoInfoListeners: [UUID: TgoVideoInfoListener] = [:]
    public private(set) var currentVideoInfo: VideoInfo = .empty
    
    public let createdAt: Date = Date()
    public private(set) var isTimeout: Bool = false
    
    // Thread safety
    private var isDisposed: Bool = false
    private let lock = NSLock()
    
    public init(uid: String, localParticipant: LocalParticipant?, remoteParticipant: RemoteParticipant?) {
        self.uid = uid
        self.localParticipant = localParticipant
        self.remoteParticipant = remoteParticipant
        super.init()
        self.initListener()
    }
    
    private var timeoutListeners: [UUID: () -> Void] = [:]
    private var microphoneListeners: [UUID: (Bool) -> Void] = [:]
    private var cameraListeners: [UUID: (Bool) -> Void] = [:]
    private var speakerListeners: [UUID: (Bool) -> Void] = [:]
    private var screenShareListeners: [UUID: (Bool) -> Void] = [:]
    private var speakingListeners: [UUID: (Bool) -> Void] = [:]
    private var cameraPositionListeners: [UUID: (TgoCameraPosition) -> Void] = [:]
    private var connectionQualityListeners: [UUID: (TgoConnectionQuality) -> Void] = [:]
    private var joinedListeners: [UUID: () -> Void] = [:]
    private var leaveListeners: [UUID: () -> Void] = [:]
    private var trackPublishedListeners: [UUID: () -> Void] = [:]
    private var trackUnpublishedListeners: [UUID: () -> Void] = [:]
    
    public func setLocalParticipant(participant: LocalParticipant) {
        self.localParticipant = participant
        self.initListener()
        self.notifyInitialState()
    }
    
    public func setRemoteParticipant(participant: RemoteParticipant) {
        self.remoteParticipant = participant
        self.initListener()
        self.notifyInitialState()
        self.notifyJoined()
    }
    
    public func setTimeout(_ value: Bool) {
        self.isTimeout = value
        if value {
            self.notifyTimeout()
        }
    }
    
    public func isLocal() -> Bool {
        return localParticipant != nil
    }
    
    public func isJoined() -> Bool {
        return remoteParticipant != nil || localParticipant != nil
    }
    
    public func getVideoTrack(source: Track.Source = .camera) -> VideoTrack? {
        if let local = localParticipant {
            return local.videoTracks.first(where: { $0.source == source })?.track as? VideoTrack
        }
        if let remote = remoteParticipant {
            return remote.videoTracks.first(where: { $0.source == source })?.track as? VideoTrack
        }
        return nil
    }
    
    public func isMicrophoneEnabled() -> Bool {
        return localParticipant?.isMicrophoneEnabled() ?? remoteParticipant?.isMicrophoneEnabled() ?? false
    }
    
    public func isCameraEnabled() -> Bool {
        return localParticipant?.isCameraEnabled() ?? remoteParticipant?.isCameraEnabled() ?? false
    }
    
    public func isScreenShareEnabled() -> Bool {
        return localParticipant?.isScreenShareEnabled() ?? remoteParticipant?.isScreenShareEnabled() ?? false
    }
    
    // only local
    public func setMicrophoneEnabled(enable: Bool) async {
        guard let local = localParticipant else { return }
        do {
            try await local.setMicrophone(enabled: enable)
        } catch {
            TgoLogger.shared.error("设置麦克风失败: \(error.localizedDescription)")
        }
    }
    
    // only local
    public func setCameraEnabled(enabled: Bool) async {
        guard let local = localParticipant else { return }
        do {
            try await local.setCamera(enabled: enabled)
        } catch {
            TgoLogger.shared.error("设置摄像头失败: \(error.localizedDescription)")
        }
    }
    
    // only local
    public func setScreenShareEnabled(enabled: Bool) async {
        guard let local = localParticipant else { return }
        do {
            try await local.setScreenShare(enabled: enabled)
        } catch {
            TgoLogger.shared.error("设置共享屏幕失败: \(error.localizedDescription)")
        }
    }
    
    private var currentCameraPosition: AVCaptureDevice.Position = .front
    
    public func switchCamera() {
        guard let local = localParticipant else { return }
        Task {
            do {
                // 切换摄像头位置
                let newPos: AVCaptureDevice.Position = (currentCameraPosition == .front) ? .back : .front
                
                try await local.setCamera(enabled: true, captureOptions: CameraCaptureOptions(position: newPos))
                
                currentCameraPosition = newPos
                
                DispatchQueue.main.async {
                    for listener in self.cameraPositionListeners.values {
                        listener(newPos == .front ? .front : .back)
                    }
                }
            } catch {
                TgoLogger.shared.error("切换摄像头失败: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Listeners
    
    public func addTimeoutListener(_ listener: @escaping () -> Void) -> ListenerToken {
        let id = UUID()
        timeoutListeners[id] = listener
        return ListenerToken { [weak self] in self?.timeoutListeners.removeValue(forKey: id) }
    }
    
    public func addMicrophoneStatusListener(_ listener: @escaping (Bool) -> Void) -> ListenerToken {
        let id = UUID()
        microphoneListeners[id] = listener
        // Immediately notify current state
        let currentState = isMicrophoneEnabled()
        DispatchQueue.main.async {
            listener(currentState)
        }
        return ListenerToken { [weak self] in self?.microphoneListeners.removeValue(forKey: id) }
    }
    
    public func addCameraStatusListener(_ listener: @escaping (Bool) -> Void) -> ListenerToken {
        let id = UUID()
        cameraListeners[id] = listener
        // Immediately notify current state
        let currentState = isCameraEnabled()
        DispatchQueue.main.async {
            listener(currentState)
        }
        return ListenerToken { [weak self] in self?.cameraListeners.removeValue(forKey: id) }
    }
    
    public func addSpeakingListener(_ listener: @escaping (Bool) -> Void) -> ListenerToken {
        let id = UUID()
        speakingListeners[id] = listener
        return ListenerToken { [weak self] in self?.speakingListeners.removeValue(forKey: id) }
    }
    
    public func addCameraPositionListener(_ listener: @escaping (TgoCameraPosition) -> Void) -> ListenerToken {
        let id = UUID()
        cameraPositionListeners[id] = listener
        return ListenerToken { [weak self] in self?.cameraPositionListeners.removeValue(forKey: id) }
    }
    
    public func addConnQualityListener(_ listener: @escaping (TgoConnectionQuality) -> Void) -> ListenerToken {
        let id = UUID()
        connectionQualityListeners[id] = listener
        return ListenerToken { [weak self] in self?.connectionQualityListeners.removeValue(forKey: id) }
    }
    
    public func addJoinedListener(_ listener: @escaping () -> Void) -> ListenerToken {
        let id = UUID()
        joinedListeners[id] = listener
        return ListenerToken { [weak self] in self?.joinedListeners.removeValue(forKey: id) }
    }
    
    public func addLeaveListener(_ listener: @escaping () -> Void) -> ListenerToken {
        let id = UUID()
        leaveListeners[id] = listener
        return ListenerToken { [weak self] in self?.leaveListeners.removeValue(forKey: id) }
    }
    
    public func addTrackPublishedListener(_ listener: @escaping () -> Void) -> ListenerToken {
        let id = UUID()
        trackPublishedListeners[id] = listener
        return ListenerToken { [weak self] in self?.trackPublishedListeners.removeValue(forKey: id) }
    }
    
    public func addTrackUnpublishedListener(_ listener: @escaping () -> Void) -> ListenerToken {
        let id = UUID()
        trackUnpublishedListeners[id] = listener
        return ListenerToken { [weak self] in self?.trackUnpublishedListeners.removeValue(forKey: id) }
    }
    
    public func addVideoInfoListener(_ listener: @escaping TgoVideoInfoListener) -> ListenerToken {
        let id = UUID()
        videoInfoListeners[id] = listener
        if currentVideoInfo.isValid {
            listener(currentVideoInfo)
        }
        return ListenerToken { [weak self] in self?.videoInfoListeners.removeValue(forKey: id) }
    }

    private func initListener() {
        if let local = localParticipant {
            local.add(delegate: self)
        }
        if let remote = remoteParticipant {
            remote.add(delegate: self)
        }
    }
    
    public func notifyTimeout() {
        guard !isDisposed else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.isDisposed else { return }
            for listener in self.timeoutListeners.values { listener() }
        }
    }
    
    public func notifyJoined() {
        guard !isDisposed else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.isDisposed else { return }
            for listener in self.joinedListeners.values { listener() }
        }
    }
    
    public func notifyLeave() {
        let listeners = leaveListeners.values
        DispatchQueue.main.async {
            for listener in listeners { listener() }
        }
        dispose()
    }
    
    private func notifyInitialState() {
        guard !isDisposed else { return }
        let micEnabled = isMicrophoneEnabled()
        let camEnabled = isCameraEnabled()
        let speaking = localParticipant?.isSpeaking ?? remoteParticipant?.isSpeaking ?? false
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.isDisposed else { return }
            for listener in self.microphoneListeners.values { listener(micEnabled) }
            for listener in self.cameraListeners.values { listener(camEnabled) }
            for listener in self.speakingListeners.values { listener(speaking) }
        }
    }
    
    private func notifyVideoInfoChanged(_ info: VideoInfo) {
        guard !isDisposed else { return }
        guard currentVideoInfo != info else { return }
        self.currentVideoInfo = info
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.isDisposed else { return }
            for listener in self.videoInfoListeners.values { listener(info) }
        }
    }
    
    public func dispose() {
        lock.lock()
        defer { lock.unlock() }
        
        isDisposed = true
        
        // Remove delegates to prevent callbacks after disposal
        localParticipant?.remove(delegate: self)
        remoteParticipant?.remove(delegate: self)
        
        timeoutListeners.removeAll()
        microphoneListeners.removeAll()
        cameraListeners.removeAll()
        screenShareListeners.removeAll()
        speakerListeners.removeAll()
        speakingListeners.removeAll()
        cameraPositionListeners.removeAll()
        connectionQualityListeners.removeAll()
        joinedListeners.removeAll()
        leaveListeners.removeAll()
        trackPublishedListeners.removeAll()
        trackUnpublishedListeners.removeAll()
        videoInfoListeners.removeAll()
        
        localParticipant = nil
        remoteParticipant = nil
    }
}

extension TgoParticipant: ParticipantDelegate {
    public func participant(_ participant: Participant, didUpdateConnectionQuality quality: ConnectionQuality) {
        guard !isDisposed else { return }
        let tgoQuality: TgoConnectionQuality = {
            switch quality {
            case .excellent: return .excellent
            case .good: return .good
            case .poor: return .poor
            case .lost: return .lost
            default: return .unknown
            }
        }()
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.isDisposed else { return }
            for listener in self.connectionQualityListeners.values { listener(tgoQuality) }
        }
    }
    
    public func participant(_ participant: Participant, didUpdateIsSpeaking isSpeaking: Bool) {
        guard !isDisposed else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.isDisposed else { return }
            for listener in self.speakingListeners.values { listener(isSpeaking) }
        }
    }
    
    public func participant(_ participant: Participant, didUpdatePublication publication: TrackPublication, muted: Bool) {
        guard !isDisposed else { return }
        if publication.source == .microphone {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, !self.isDisposed else { return }
                for listener in self.microphoneListeners.values { listener(!muted) }
            }
        } else if publication.source == .camera {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, !self.isDisposed else { return }
                for listener in self.cameraListeners.values { listener(!muted) }
            }
        }
    }
    
    public func participant(_ participant: Participant, didPublishPublication publication: TrackPublication) {
        guard !isDisposed else { return }
        if publication.source == .camera {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, !self.isDisposed else { return }
                for listener in self.cameraListeners.values { listener(true) }
            }
        } else if publication.source == .microphone {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, !self.isDisposed else { return }
                for listener in self.microphoneListeners.values { listener(true) }
            }
        }
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.isDisposed else { return }
            for listener in self.trackPublishedListeners.values { listener() }
        }
    }
    
    public func participant(_ participant: Participant, didUnpublishPublication publication: TrackPublication) {
        guard !isDisposed else { return }
        if publication.source == .camera {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, !self.isDisposed else { return }
                for listener in self.cameraListeners.values { listener(false) }
            }
        } else if publication.source == .microphone {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, !self.isDisposed else { return }
                for listener in self.microphoneListeners.values { listener(false) }
            }
        }
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.isDisposed else { return }
            for listener in self.trackUnpublishedListeners.values { listener() }
        }
    }
    
    public func participant(_ participant: RemoteParticipant, didSubscribePublication publication: RemoteTrackPublication, track: Track) {
        guard !isDisposed else { return }
        if publication.source == .camera {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, !self.isDisposed else { return }
                for listener in self.cameraListeners.values { listener(true) }
            }
        } else if publication.source == .microphone {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, !self.isDisposed else { return }
                for listener in self.microphoneListeners.values { listener(true) }
            }
        }
    }
    
    public func participant(_ participant: RemoteParticipant, didUnsubscribePublication publication: RemoteTrackPublication, track: Track) {
        guard !isDisposed else { return }
        if publication.source == .camera {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, !self.isDisposed else { return }
                for listener in self.cameraListeners.values { listener(false) }
            }
        } else if publication.source == .microphone {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, !self.isDisposed else { return }
                for listener in self.microphoneListeners.values { listener(false) }
            }
        }
    }
}
