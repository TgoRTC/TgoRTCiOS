//
//  TgoVideoViewBridge.swift
//  TgoRTCSDK
//
//  Created by Cursor on 2026/01/22.
//

import Foundation
import UIKit
import LiveKit
import Combine

/// Layout mode for video rendering (Objective-C compatible)
@objc public enum TgoVideoLayoutMode: Int {
    case fill = 0   // Video fills the view (may crop)
    case fit = 1    // Video fits within the view (may letterbox)
}

/// Mirror mode for video (Objective-C compatible)
@objc public enum TgoVideoMirrorMode: Int {
    case auto = 0   // Auto-detect (front camera mirrors, back doesn't)
    case off = 1    // Never mirror
    case mirror = 2 // Always mirror
}

/// Objective-C compatible video view for rendering participant video
@objcMembers
public class TgoVideoView: UIView {
    
    private var videoView: VideoView?
    private var currentTrack: VideoTrack?
    private weak var attachedParticipant: TgoParticipantBridge?
    private var isCamera: Bool = true
    private var cancellables = Set<AnyCancellable>()
    private var retryTimer: Timer?
    
    private var layoutMode: TgoVideoLayoutMode = .fill
    private var mirrorMode: TgoVideoMirrorMode = .auto
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupVideoView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupVideoView()
    }
    
    deinit {
        retryTimer?.invalidate()
        cancellables.removeAll()
    }
    
    private func setupVideoView() {
        videoView = VideoView(frame: bounds)
        videoView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        videoView?.backgroundColor = .black
        if let videoView = videoView {
            addSubview(videoView)
        }
        backgroundColor = .black
    }
    
    /// Attach a participant's video track to this view
    /// - Parameters:
    ///   - participant: The participant bridge to display
    ///   - isCamera: true for camera video, false for screen share
    public func attachParticipant(_ participant: TgoParticipantBridge, isCamera: Bool) {
        // Store reference for later retry
        self.attachedParticipant = participant
        self.isCamera = isCamera
        
        // Cancel any existing retry timer
        retryTimer?.invalidate()
        
        // Try to attach immediately
        tryAttachTrack()
        
        // If track not available, set up retry mechanism
        if currentTrack == nil {
            startRetryTimer()
        }
        
        // Also listen for camera state changes
        participant.swiftParticipant.$isCameraOn
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isOn in
                if isOn {
                    self?.tryAttachTrack()
                }
            }
            .store(in: &cancellables)
    }
    
    private func startRetryTimer() {
        // Retry every 0.5 seconds until track is available
        retryTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            self.tryAttachTrack()
            
            // Stop retrying after successful attach or max attempts
            if self.currentTrack != nil {
                timer.invalidate()
                self.retryTimer = nil
            }
        }
    }
    
    private func tryAttachTrack() {
        guard let participant = attachedParticipant else { return }
        
        let source: Track.Source = isCamera ? .camera : .screenShareVideo
        if let track = participant.swiftParticipant.getVideoTrack(source: source) {
            attachTrack(track)
        }
    }
    
    /// Attach a video track directly
    internal func attachTrack(_ track: VideoTrack) {
        // Skip if same track
        if currentTrack === track {
            return
        }
        
        // Remove previous track
        if currentTrack != nil {
            videoView?.track = nil
            self.currentTrack = nil
        }
        
        // Set new track
        currentTrack = track
        videoView?.track = track
        
        // Apply layout mode
        switch layoutMode {
        case .fill:
            videoView?.layoutMode = .fill
        case .fit:
            videoView?.layoutMode = .fit
        }
        
        // Apply mirror mode
        switch mirrorMode {
        case .auto:
            videoView?.mirrorMode = .auto
        case .off:
            videoView?.mirrorMode = .off
        case .mirror:
            videoView?.mirrorMode = .mirror
        }
        
        // Stop retry timer
        retryTimer?.invalidate()
        retryTimer = nil
    }
    
    /// Detach the current video track
    public func detach() {
        retryTimer?.invalidate()
        retryTimer = nil
        cancellables.removeAll()
        attachedParticipant = nil
        videoView?.track = nil
        currentTrack = nil
    }
    
    /// Set the layout mode
    public func setLayoutMode(_ mode: TgoVideoLayoutMode) {
        self.layoutMode = mode
        switch mode {
        case .fill:
            videoView?.layoutMode = .fill
        case .fit:
            videoView?.layoutMode = .fit
        }
    }
    
    /// Set the mirror mode
    public func setMirrorMode(_ mode: TgoVideoMirrorMode) {
        self.mirrorMode = mode
        switch mode {
        case .auto:
            videoView?.mirrorMode = .auto
        case .off:
            videoView?.mirrorMode = .off
        case .mirror:
            videoView?.mirrorMode = .mirror
        }
    }
    
    /// Check if a track is currently attached
    public var hasTrack: Bool {
        return currentTrack != nil
    }
}

// MARK: - Extension to TgoParticipantBridge for getting video view

extension TgoParticipantBridge {
    
    /// Create a video view for this participant
    /// - Parameter frame: The frame for the video view
    /// - Returns: A configured TgoVideoView
    @objc public func createVideoView(frame: CGRect) -> TgoVideoView {
        let view = TgoVideoView(frame: frame)
        view.attachParticipant(self, isCamera: true)
        return view
    }
    
    /// Attach this participant's camera video to an existing view
    @objc public func attachCameraTo(_ videoView: TgoVideoView) {
        videoView.attachParticipant(self, isCamera: true)
    }
    
    /// Attach this participant's screen share to an existing view
    @objc public func attachScreenShareTo(_ videoView: TgoVideoView) {
        videoView.attachParticipant(self, isCamera: false)
    }
}
