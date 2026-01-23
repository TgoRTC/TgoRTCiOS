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
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            if on {
                try session.overrideOutputAudioPort(.speaker)
            } else {
                try session.overrideOutputAudioPort(.none)
            }
            self.isSpeakerOn = on
        } catch {
            TgoLogger.shared.error("设置扬声器失败: \(error.localizedDescription)")
        }
        #endif
    }
    
    public func toggleSpeakerphone() async {
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
