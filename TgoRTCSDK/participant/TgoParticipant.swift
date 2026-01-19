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
        TgoLogger.shared.info("TgoParticipant 初始化 - uid: \(uid), isLocal: \(localParticipant != nil)")
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
        TgoLogger.shared.info("本地用户加入房间 - uid: \(uid)")
        self.localParticipant = participant
        self.initListener()
        self.notifyInitialState()
    }
    
    public func setRemoteParticipant(participant: RemoteParticipant) {
        TgoLogger.shared.info("远程用户加入房间 - uid: \(uid)")
        self.remoteParticipant = participant
        self.initListener()
        
        // 打印远程用户当前的轨道状态，用于诊断
        let publications = Array(participant.trackPublications.values)
        TgoLogger.shared.debug("远程用户轨道数量: \(publications.count)")
        for pub in publications {
            let sourceName = pub.source == Track.Source.microphone ? "麦克风" : (pub.source == Track.Source.camera ? "摄像头" : "其他")
            TgoLogger.shared.debug("  - 轨道: \(sourceName), subscribed: \(pub.isSubscribed), muted: \(pub.isMuted)")
        }
        
        // 检查远程用户的摄像头和麦克风状态
        let micEnabled = participant.isMicrophoneEnabled()
        let camEnabled = participant.isCameraEnabled()
        TgoLogger.shared.info("远程用户初始状态 - uid: \(uid), mic: \(micEnabled), camera: \(camEnabled)")
        
        self.notifyInitialState()
        self.notifyJoined()
        
        // 如果远程用户已经有发布的轨道，主动通知 trackPublished
        if !publications.isEmpty {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, !self.isDisposed else { return }
                for listener in self.trackPublishedListeners.values { listener() }
            }
        }
        
        // 开始监控轨道变化（因为摄像头轨道可能稍后才同步过来）
        startTrackMonitoring(for: participant)
    }
    
    /// 监控远程用户的轨道变化，因为轨道可能在连接后才同步过来
    private func startTrackMonitoring(for participant: RemoteParticipant) {
        // 延迟检查，等待轨道同步
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self, !self.isDisposed else { return }
            self.checkAndNotifyTrackState()
        }
        
        // 再次延迟检查
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self, !self.isDisposed else { return }
            self.checkAndNotifyTrackState()
        }
        
        // 第三次延迟检查
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self, !self.isDisposed else { return }
            self.checkAndNotifyTrackState()
        }
    }
    
    /// 检查并通知当前轨道状态
    private func checkAndNotifyTrackState() {
        guard let remote = remoteParticipant else { return }
        
        let publications = Array(remote.trackPublications.values)
        let hasCameraTrack = publications.contains { $0.source == Track.Source.camera }
        let camEnabled = isCameraEnabled()
        let micEnabled = isMicrophoneEnabled()
        
        TgoLogger.shared.debug("轨道状态检查 - uid: \(uid), 轨道数: \(publications.count), 有摄像头: \(hasCameraTrack), camera: \(camEnabled), mic: \(micEnabled)")
        
        // 通知监听器当前状态
        for listener in cameraListeners.values {
            listener(camEnabled)
        }
        for listener in microphoneListeners.values {
            listener(micEnabled)
        }
        
        // 如果有轨道，通知 trackPublished
        if !publications.isEmpty {
            for listener in trackPublishedListeners.values {
                listener()
            }
        }
    }
    
    public func setTimeout(_ value: Bool) {
        self.isTimeout = value
        if value {
            TgoLogger.shared.warning("用户超时 - uid: \(uid)")
            self.notifyTimeout()
        }
    }
    
    public func isLocal() -> Bool {
        return localParticipant != nil
    }
    
    public func isJoined() -> Bool {
        return remoteParticipant != nil || localParticipant != nil
    }
    
    public func getVideoTrack(source: Track.Source = Track.Source.camera) -> VideoTrack? {
        if let local = localParticipant {
            return local.videoTracks.first(where: { $0.source == source })?.track as? VideoTrack
        }
        if let remote = remoteParticipant {
            return remote.videoTracks.first(where: { $0.source == source })?.track as? VideoTrack
        }
        return nil
    }
    
    public func isMicrophoneEnabled() -> Bool {
        if let local = localParticipant {
            return local.isMicrophoneEnabled()
        }
        if let remote = remoteParticipant {
            // 对于远程用户，检查是否有已发布的麦克风轨道（不管是否已订阅）
            let hasPublishedMic = remote.trackPublications.values.contains { pub in
                pub.source == Track.Source.microphone && !pub.isMuted 
            }
            let lkEnabled = remote.isMicrophoneEnabled()
            return hasPublishedMic || lkEnabled
        }
        return false
    }
    
    public func isCameraEnabled() -> Bool {
        if let local = localParticipant {
            return local.isCameraEnabled()
        }
        if let remote = remoteParticipant {
            // 对于远程用户，检查是否有已发布的摄像头轨道（不管是否已订阅）
            // 因为 isCameraEnabled() 可能只在订阅后才返回 true
            let hasPublishedCamera = remote.trackPublications.values.contains { pub in
                pub.source == Track.Source.camera && !pub.isMuted 
            }
            let lkEnabled = remote.isCameraEnabled()
            
            // 如果有已发布且未静音的摄像头轨道，或者 LiveKit 认为已启用，都返回 true
            return hasPublishedCamera || lkEnabled
        }
        return false
    }
    
    public func isScreenShareEnabled() -> Bool {
        return localParticipant?.isScreenShareEnabled() ?? remoteParticipant?.isScreenShareEnabled() ?? false
    }
    
    // only local
    public func setMicrophoneEnabled(enable: Bool) async {
        guard let local = localParticipant else {
            TgoLogger.shared.warning("设置麦克风失败: localParticipant 为空")
            return
        }
        TgoLogger.shared.info("设置麦克风状态 - uid: \(uid), enabled: \(enable)")
        do {
            try await local.setMicrophone(enabled: enable)
            TgoLogger.shared.debug("麦克风状态设置成功 - enabled: \(enable)")
        } catch {
            TgoLogger.shared.error("设置麦克风失败: \(error.localizedDescription)")
        }
    }
    
    // only local
    public func setCameraEnabled(enabled: Bool) async {
        guard let local = localParticipant else {
            TgoLogger.shared.warning("设置摄像头失败: localParticipant 为空")
            return
        }
        TgoLogger.shared.info("设置摄像头状态 - uid: \(uid), enabled: \(enabled)")
        do {
            try await local.setCamera(enabled: enabled)
            TgoLogger.shared.debug("摄像头状态设置成功 - enabled: \(enabled)")
        } catch {
            TgoLogger.shared.error("设置摄像头失败: \(error.localizedDescription)")
        }
    }
    
    // only local
    public func setScreenShareEnabled(enabled: Bool) async {
        guard let local = localParticipant else {
            TgoLogger.shared.warning("设置屏幕共享失败: localParticipant 为空")
            return
        }
        TgoLogger.shared.info("设置屏幕共享状态 - uid: \(uid), enabled: \(enabled)")
        do {
            try await local.setScreenShare(enabled: enabled)
            TgoLogger.shared.debug("屏幕共享状态设置成功 - enabled: \(enabled)")
        } catch {
            TgoLogger.shared.error("设置共享屏幕失败: \(error.localizedDescription)")
        }
    }
    
    private var currentCameraPosition: AVCaptureDevice.Position = .front
    
    public func switchCamera() {
        guard let local = localParticipant else {
            TgoLogger.shared.warning("切换摄像头失败: localParticipant 为空")
            return
        }
        
        // 获取摄像头视频轨道
        guard let cameraTrack = local.localVideoTracks.first(where: { $0.source == Track.Source.camera })?.track as? LocalVideoTrack,
              let cameraCapturer = cameraTrack.capturer as? CameraCapturer else {
            TgoLogger.shared.warning("切换摄像头失败: 找不到摄像头轨道或 CameraCapturer")
            return
        }
        
        let oldPos = currentCameraPosition
        TgoLogger.shared.info("开始切换摄像头 - uid: \(uid), 当前: \(oldPos == .front ? "前置" : "后置")")
        
        Task {
            do {
                // 使用 CameraCapturer 的 switchCameraPosition 方法
                let success = try await cameraCapturer.switchCameraPosition()
                
                if success {
                    // 更新当前摄像头位置
                    currentCameraPosition = (currentCameraPosition == .front) ? .back : .front
                    let newPos = currentCameraPosition
                    TgoLogger.shared.info("切换摄像头成功 - uid: \(uid), 新位置: \(newPos == .front ? "前置" : "后置")")
                    
                    DispatchQueue.main.async {
                        for listener in self.cameraPositionListeners.values {
                            listener(newPos == .front ? .front : .back)
                        }
                    }
                } else {
                    TgoLogger.shared.warning("切换摄像头返回 false")
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
        // If already timeout, immediately notify
        if isTimeout {
            DispatchQueue.main.async {
                listener()
            }
        }
        return ListenerToken { [weak self] in self?.timeoutListeners.removeValue(forKey: id) }
    }
    
    public func addMicrophoneStatusListener(_ listener: @escaping (Bool) -> Void) -> ListenerToken {
        let id = UUID()
        microphoneListeners[id] = listener
        // Immediately notify current state
        let currentState = isMicrophoneEnabled()
        TgoLogger.shared.debug("添加麦克风监听器 - uid: \(uid), 当前状态: \(currentState)")
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
        TgoLogger.shared.debug("添加摄像头监听器 - uid: \(uid), 当前状态: \(currentState)")
        DispatchQueue.main.async {
            listener(currentState)
        }
        return ListenerToken { [weak self] in self?.cameraListeners.removeValue(forKey: id) }
    }
    
    public func addSpeakingListener(_ listener: @escaping (Bool) -> Void) -> ListenerToken {
        let id = UUID()
        speakingListeners[id] = listener
        // Immediately notify current state
        let currentState = localParticipant?.isSpeaking ?? remoteParticipant?.isSpeaking ?? false
        DispatchQueue.main.async {
            listener(currentState)
        }
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
        // Immediately notify current state
        let lkQuality = localParticipant?.connectionQuality ?? remoteParticipant?.connectionQuality ?? .unknown
        let currentQuality: TgoConnectionQuality = {
            switch lkQuality {
            case .excellent: return .excellent
            case .good: return .good
            case .poor: return .poor
            case .lost: return .lost
            default: return .unknown
            }
        }()
        DispatchQueue.main.async {
            listener(currentQuality)
        }
        return ListenerToken { [weak self] in self?.connectionQualityListeners.removeValue(forKey: id) }
    }
    
    public func addJoinedListener(_ listener: @escaping () -> Void) -> ListenerToken {
        let id = UUID()
        joinedListeners[id] = listener
        // If already joined, immediately notify
        let alreadyJoined = isJoined()
        TgoLogger.shared.debug("添加加入监听器 - uid: \(uid), 已加入: \(alreadyJoined)")
        if alreadyJoined {
            DispatchQueue.main.async {
                listener()
            }
        }
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
        // If already has published tracks, immediately notify
        let hasPublishedTracks = (localParticipant?.trackPublications.count ?? 0) > 0 ||
                                  (remoteParticipant?.trackPublications.count ?? 0) > 0
        if hasPublishedTracks {
            DispatchQueue.main.async {
                listener()
            }
        }
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
    
    // MARK: - Track State Handling (called from RoomDelegate)
    
    /// 处理轨道 mute 状态变化（由 RoomManager 调用）
    public func handleTrackMuteChanged(source: Track.Source, muted: Bool) {
        guard !isDisposed else { return }
        
        let sourceName = source == Track.Source.microphone ? "麦克风" : (source == Track.Source.camera ? "摄像头" : "其他")
        let isEnabled = !muted
        TgoLogger.shared.info("处理轨道状态变化 - uid: \(uid), source: \(sourceName), enabled: \(isEnabled)")
        
        notifyTrackStateChange(source: source, enabled: isEnabled)
    }
    
    /// 处理远程轨道发布事件
    public func handleRemoteTrackPublished(source: Track.Source, muted: Bool) {
        guard !isDisposed else { return }
        
        let sourceName = source == Track.Source.microphone ? "麦克风" : (source == Track.Source.camera ? "摄像头" : "其他")
        let isEnabled = !muted
        TgoLogger.shared.info("处理远程轨道发布 - uid: \(uid), source: \(sourceName), enabled: \(isEnabled)")
        
        notifyTrackStateChange(source: source, enabled: isEnabled)
        
        // 通知 trackPublished 监听器
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.isDisposed else { return }
            for listener in self.trackPublishedListeners.values { listener() }
        }
    }
    
    /// 处理远程轨道取消发布事件
    public func handleRemoteTrackUnpublished(source: Track.Source) {
        guard !isDisposed else { return }
        
        let sourceName = source == Track.Source.microphone ? "麦克风" : (source == Track.Source.camera ? "摄像头" : "其他")
        TgoLogger.shared.info("处理远程轨道取消发布 - uid: \(uid), source: \(sourceName)")
        
        notifyTrackStateChange(source: source, enabled: false)
        
        // 通知 trackUnpublished 监听器
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.isDisposed else { return }
            for listener in self.trackUnpublishedListeners.values { listener() }
        }
    }
    
    /// 处理远程轨道订阅事件（最可靠的事件！）
    public func handleRemoteTrackSubscribed(source: Track.Source, muted: Bool) {
        guard !isDisposed else { return }
        
        let sourceName = source == Track.Source.microphone ? "麦克风" : (source == Track.Source.camera ? "摄像头" : "其他")
        let isEnabled = !muted
        TgoLogger.shared.info("处理远程轨道订阅 - uid: \(uid), source: \(sourceName), enabled: \(isEnabled)")
        
        notifyTrackStateChange(source: source, enabled: isEnabled)
        
        // 通知 trackPublished 监听器
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.isDisposed else { return }
            for listener in self.trackPublishedListeners.values { listener() }
        }
    }
    
    /// 处理远程轨道取消订阅事件
    public func handleRemoteTrackUnsubscribed(source: Track.Source) {
        guard !isDisposed else { return }
        
        let sourceName = source == Track.Source.microphone ? "麦克风" : (source == Track.Source.camera ? "摄像头" : "其他")
        TgoLogger.shared.info("处理远程轨道取消订阅 - uid: \(uid), source: \(sourceName)")
        
        notifyTrackStateChange(source: source, enabled: false)
    }
    
    /// 统一的轨道状态通知方法
    private func notifyTrackStateChange(source: Track.Source, enabled: Bool) {
        if source == Track.Source.microphone {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, !self.isDisposed else { return }
                TgoLogger.shared.debug("通知麦克风监听器 - uid: \(self.uid), enabled: \(enabled), 监听器数量: \(self.microphoneListeners.count)")
                for listener in self.microphoneListeners.values { listener(enabled) }
            }
        } else if source == Track.Source.camera {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, !self.isDisposed else { return }
                TgoLogger.shared.debug("通知摄像头监听器 - uid: \(self.uid), enabled: \(enabled), 监听器数量: \(self.cameraListeners.count)")
                for listener in self.cameraListeners.values { listener(enabled) }
            }
        }
    }

    private func initListener() {
        if let local = localParticipant {
            TgoLogger.shared.debug("添加本地用户 delegate - uid: \(uid)")
            local.add(delegate: self)
        }
        if let remote = remoteParticipant {
            TgoLogger.shared.debug("添加远程用户 delegate - uid: \(uid)")
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
        TgoLogger.shared.info("通知用户加入事件 - uid: \(uid), isLocal: \(isLocal())")
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.isDisposed else { return }
            for listener in self.joinedListeners.values { listener() }
        }
    }
    
    public func notifyLeave() {
        TgoLogger.shared.info("用户离开房间 - uid: \(uid), isLocal: \(isLocal())")
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
        
        let listenerCount = microphoneListeners.count + cameraListeners.count + speakingListeners.count
        TgoLogger.shared.debug("notifyInitialState - uid: \(uid), mic: \(micEnabled), camera: \(camEnabled), speaking: \(speaking), 监听器数量: \(listenerCount)")
        
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
        
        TgoLogger.shared.debug("释放 TgoParticipant 资源 - uid: \(uid)")
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
        TgoLogger.shared.debug("连接质量更新 - uid: \(uid), quality: \(tgoQuality)")
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.isDisposed else { return }
            for listener in self.connectionQualityListeners.values { listener(tgoQuality) }
        }
    }
    
    public func participant(_ participant: Participant, didUpdateIsSpeaking isSpeaking: Bool) {
        guard !isDisposed else { return }
        TgoLogger.shared.debug("说话状态更新 - uid: \(uid), isSpeaking: \(isSpeaking)")
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.isDisposed else { return }
            for listener in self.speakingListeners.values { listener(isSpeaking) }
        }
    }
    
    public func participant(_ participant: Participant, didUpdatePublication publication: TrackPublication, muted: Bool) {
        guard !isDisposed else { return }
        let sourceName = publication.source == Track.Source.microphone ? "麦克风" : (publication.source == Track.Source.camera ? "摄像头" : "其他")
        TgoLogger.shared.info("轨道状态更新 - uid: \(uid), source: \(sourceName), muted: \(muted)")
        if publication.source == Track.Source.microphone {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, !self.isDisposed else { return }
                for listener in self.microphoneListeners.values { listener(!muted) }
            }
        } else if publication.source == Track.Source.camera {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, !self.isDisposed else { return }
                for listener in self.cameraListeners.values { listener(!muted) }
            }
        }
    }
    
    public func participant(_ participant: Participant, didPublishPublication publication: TrackPublication) {
        guard !isDisposed else { return }
        let sourceName = publication.source == Track.Source.microphone ? "麦克风" : (publication.source == Track.Source.camera ? "摄像头" : "屏幕共享")
        TgoLogger.shared.info("轨道发布 - uid: \(uid), source: \(sourceName)")
        if publication.source == Track.Source.camera {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, !self.isDisposed else { return }
                for listener in self.cameraListeners.values { listener(true) }
            }
        } else if publication.source == Track.Source.microphone {
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
        let sourceName = publication.source == Track.Source.microphone ? "麦克风" : (publication.source == Track.Source.camera ? "摄像头" : "屏幕共享")
        TgoLogger.shared.info("轨道取消发布 - uid: \(uid), source: \(sourceName)")
        if publication.source == Track.Source.camera {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, !self.isDisposed else { return }
                for listener in self.cameraListeners.values { listener(false) }
            }
        } else if publication.source == Track.Source.microphone {
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
        let sourceName = publication.source == Track.Source.microphone ? "麦克风" : (publication.source == Track.Source.camera ? "摄像头" : "其他")
        TgoLogger.shared.info("订阅远程轨道 - uid: \(uid), source: \(sourceName)")
        if publication.source == Track.Source.camera {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, !self.isDisposed else { return }
                for listener in self.cameraListeners.values { listener(true) }
            }
        } else if publication.source == Track.Source.microphone {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, !self.isDisposed else { return }
                for listener in self.microphoneListeners.values { listener(true) }
            }
        }
    }
    
    public func participant(_ participant: RemoteParticipant, didUnsubscribePublication publication: RemoteTrackPublication, track: Track) {
        guard !isDisposed else { return }
        let sourceName = publication.source == Track.Source.microphone ? "麦克风" : (publication.source == Track.Source.camera ? "摄像头" : "其他")
        TgoLogger.shared.info("取消订阅远程轨道 - uid: \(uid), source: \(sourceName)")
        if publication.source == Track.Source.camera {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, !self.isDisposed else { return }
                for listener in self.cameraListeners.values { listener(false) }
            }
        } else if publication.source == Track.Source.microphone {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, !self.isDisposed else { return }
                for listener in self.microphoneListeners.values { listener(false) }
            }
        }
    }
    
    // 远程用户轨道启用/禁用状态变化 (mute/unmute)
    public func participant(_ participant: RemoteParticipant, didUpdatePublication publication: RemoteTrackPublication) {
        guard !isDisposed else { return }
        let sourceName = publication.source == Track.Source.microphone ? "麦克风" : (publication.source == Track.Source.camera ? "摄像头" : "其他")
        let isEnabled = !publication.isMuted
        TgoLogger.shared.info("远程轨道状态变化 - uid: \(uid), source: \(sourceName), enabled: \(isEnabled), muted: \(publication.isMuted)")
        
        if publication.source == Track.Source.microphone {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, !self.isDisposed else { return }
                for listener in self.microphoneListeners.values { listener(isEnabled) }
            }
        } else if publication.source == Track.Source.camera {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, !self.isDisposed else { return }
                for listener in self.cameraListeners.values { listener(isEnabled) }
            }
        }
    }
    
    // 远程用户 Track 更新
    public func participant(_ participant: RemoteParticipant, didUpdateTrack publication: RemoteTrackPublication) {
        guard !isDisposed else { return }
        let sourceName = publication.source == Track.Source.microphone ? "麦克风" : (publication.source == Track.Source.camera ? "摄像头" : "其他")
        TgoLogger.shared.debug("远程轨道更新 - uid: \(uid), source: \(sourceName), subscribed: \(publication.isSubscribed), muted: \(publication.isMuted)")
    }
}
