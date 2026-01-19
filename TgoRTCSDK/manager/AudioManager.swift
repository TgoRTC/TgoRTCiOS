//
//  AudioManager.swift
//  TgoRTCIOS
//
//  Created by Slun on 2026/1/16.
//

import Foundation
import LiveKit
import AVFoundation

public final class AudioManager {
    public static let shared = AudioManager()
    
    private init() {
    }
    
    public var isSpeakerOn: Bool = false
    
    private var deviceChangeListeners: [UUID: ([String]) -> Void] = [:]
    
    public func addDeviceChangeListener(_ listener: @escaping ([String]) -> Void) -> ListenerToken {
        let id = UUID()
        deviceChangeListeners[id] = listener
        return ListenerToken { [weak self] in
            self?.deviceChangeListeners.removeValue(forKey: id)
        }
    }
    
    public func setSpeakerphoneOn(_ on: Bool, forceSpeakerOutput: Bool = false) async {
        TgoLogger.shared.info("设置扬声器状态 - enabled: \(on)")
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            if on {
                try session.overrideOutputAudioPort(.speaker)
            } else {
                try session.overrideOutputAudioPort(.none)
            }
            self.isSpeakerOn = on
            TgoLogger.shared.debug("扬声器状态设置成功 - enabled: \(on)")
        } catch {
            TgoLogger.shared.error("设置扬声器失败: \(error.localizedDescription)")
        }
        #endif
    }
    
    public func toggleSpeakerphone() async {
        TgoLogger.shared.debug("切换扬声器状态 - 当前: \(isSpeakerOn)")
        await setSpeakerphoneOn(!isSpeakerOn)
    }
    
    public func getAudioInputDevices() async -> [String] {
        // Simplified for SDK interface
        return ["Default"]
    }
    
    public func getAudioOutputDevices() async -> [String] {
        // Simplified for SDK interface
        return ["Default"]
    }
    
    public func dispose() {
        deviceChangeListeners.removeAll()
    }
}
