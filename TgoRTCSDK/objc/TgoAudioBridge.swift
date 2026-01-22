//
//  TgoAudioBridge.swift
//  TgoRTCSDK
//
//  Created by Cursor on 2026/01/22.
//

import Foundation

/// Objective-C compatible bridge for audio output device
@objcMembers
public class TgoAudioOutputDeviceObjC: NSObject {
    public let id: String
    public let name: String
    public let typeString: String
    public let isActive: Bool
    
    internal init(from swiftDevice: AudioOutputDevice) {
        self.id = swiftDevice.id
        self.name = swiftDevice.name
        self.typeString = swiftDevice.type.rawValue
        self.isActive = swiftDevice.isActive
        super.init()
    }
}

/// Objective-C compatible bridge for audio management
@objcMembers
public class TgoAudioBridge: NSObject {
    private var deviceToken: ListenerToken?
    public var onDeviceChange: (([TgoAudioOutputDeviceObjC]) -> Void)?
    
    public var isSpeakerOn: Bool {
        return AudioManager.shared.isSpeakerOn
    }
    
    public override init() {
        super.init()
        setupListeners()
    }
    
    private func setupListeners() {
        deviceToken = AudioManager.shared.addDeviceChangeListener { [weak self] devices in
            let objcDevices = devices.map { TgoAudioOutputDeviceObjC(from: $0) }
            self?.onDeviceChange?(objcDevices)
        }
    }
    
    public func setSpeakerphoneOn(_ on: Bool, completion: ((Bool) -> Void)?) {
        Task {
            await AudioManager.shared.setSpeakerphoneOn(on)
            DispatchQueue.main.async { completion?(true) }
        }
    }
    
    public func toggleSpeakerphone(completion: ((Bool) -> Void)?) {
        Task {
            await AudioManager.shared.toggleSpeakerphone()
            DispatchQueue.main.async { completion?(true) }
        }
    }
    
    public func getAudioOutputDevices(completion: @escaping ([TgoAudioOutputDeviceObjC]) -> Void) {
        Task {
            let devices = await AudioManager.shared.getAudioOutputDevices()
            let objcDevices = devices.map { TgoAudioOutputDeviceObjC(from: $0) }
            DispatchQueue.main.async {
                completion(objcDevices)
            }
        }
    }
    
    deinit {
        deviceToken?.cancel()
    }
}
