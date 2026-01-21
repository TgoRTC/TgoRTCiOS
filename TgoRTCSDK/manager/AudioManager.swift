//
//  AudioManager.swift
//  TgoRTCIOS
//
//  Created by Slun on 2026/1/16.
//

import Foundation
import LiveKit
import AVFoundation

// MARK: - 音频输出设备类型
public enum AudioOutputDeviceType: String, Sendable {
    case receiver = "receiver"           // 听筒
    case speaker = "speaker"             // 扬声器
    case headphones = "headphones"       // 有线耳机
    case bluetoothA2DP = "bluetoothA2DP" // 蓝牙 A2DP
    case bluetoothHFP = "bluetoothHFP"   // 蓝牙 HFP
    case bluetoothLE = "bluetoothLE"     // 蓝牙 LE
    case airPlay = "airPlay"             // AirPlay
    case carAudio = "carAudio"           // 车载音频
    case hdmi = "hdmi"                   // HDMI
    case usbAudio = "usbAudio"           // USB 音频
    case unknown = "unknown"             // 未知
}

// MARK: - 音频输出设备
public struct AudioOutputDevice: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let type: AudioOutputDeviceType
    public let portType: String?          // 原始 AVAudioSession port type
    public let isActive: Bool             // 是否当前正在使用
    
    public init(id: String, name: String, type: AudioOutputDeviceType, portType: String? = nil, isActive: Bool = false) {
        self.id = id
        self.name = name
        self.type = type
        self.portType = portType
        self.isActive = isActive
    }
    
    public static func == (lhs: AudioOutputDevice, rhs: AudioOutputDevice) -> Bool {
        return lhs.id == rhs.id
    }
}

public final class AudioManager {
    public static let shared = AudioManager()
    
    private init() {
        #if os(iOS)
        setupRouteChangeNotification()
        #endif
    }
    
    public var isSpeakerOn: Bool = false
    
    /// 当前选中的输出设备
    public private(set) var currentOutputDevice: AudioOutputDevice?
    
    private var deviceChangeListeners: [UUID: ([AudioOutputDevice]) -> Void] = [:]
    
    // MARK: - 设备变化监听
    
    public func addDeviceChangeListener(_ listener: @escaping ([AudioOutputDevice]) -> Void) -> ListenerToken {
        let id = UUID()
        deviceChangeListeners[id] = listener
        return ListenerToken { [weak self] in
            self?.deviceChangeListeners.removeValue(forKey: id)
        }
    }
    
    #if os(iOS)
    private func setupRouteChangeNotification() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }
    
    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        TgoLogger.shared.debug("音频路由变化: reason=\(reason.rawValue)")
        
        // 获取最新设备列表并通知监听者
        Task {
            let devices = await getAudioOutputDevices()
            await MainActor.run {
                for listener in deviceChangeListeners.values {
                    listener(devices)
                }
            }
        }
    }
    #endif
    
    public func setSpeakerphoneOn(_ on: Bool, forceSpeakerOutput: Bool = false) async {
        TgoLogger.shared.info("设置扬声器状态 - enabled: \(on)")
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            if on {
                // 使用扬声器：设置 category 包含 defaultToSpeaker，并覆盖输出端口
                try session.setCategory(
                    .playAndRecord,
                    mode: .voiceChat,
                    options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker]
                )
                try session.overrideOutputAudioPort(.speaker)
            } else {
                // 使用听筒：重新设置 category 不包含 defaultToSpeaker
                try session.setCategory(
                    .playAndRecord,
                    mode: .voiceChat,
                    options: [.allowBluetooth, .allowBluetoothA2DP]
                )
                try session.overrideOutputAudioPort(.none)
            }
            try session.setActive(true)
            self.isSpeakerOn = on
            TgoLogger.shared.debug("扬声器状态设置成功 - enabled: \(on), category options: \(session.categoryOptions)")
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
    
    // MARK: - 获取音频输出设备列表
    
    /// 获取可用的音频输出设备列表
    /// 注意：iOS 没有 availableOutputs API，只能通过 currentRoute.outputs 获取当前输出设备
    /// 并推断可能可用的设备（扬声器/听筒始终可用，蓝牙根据连接状态判断）
    public func getAudioOutputDevices() async -> [AudioOutputDevice] {
        #if os(iOS)
        var devices: [AudioOutputDevice] = []
        let session = AVAudioSession.sharedInstance()
        let currentOutputs = session.currentRoute.outputs
        
        // 获取当前活跃的输出端口类型
        let activePortTypes = Set(currentOutputs.map { $0.portType })
        
        // 记录当前输出设备
        for output in currentOutputs {
            TgoLogger.shared.debug("当前输出设备: type=\(output.portType.rawValue), name=\(output.portName)")
        }
        
        // 内置设备始终可用
        let isReceiverActive = activePortTypes.contains(.builtInReceiver)
        let isSpeakerActive = activePortTypes.contains(.builtInSpeaker)
        
        devices.append(AudioOutputDevice(
            id: "receiver",
            name: "听筒",
            type: .receiver,
            portType: AVAudioSession.Port.builtInReceiver.rawValue,
            isActive: isReceiverActive
        ))
        
        devices.append(AudioOutputDevice(
            id: "speaker",
            name: "扬声器",
            type: .speaker,
            portType: AVAudioSession.Port.builtInSpeaker.rawValue,
            isActive: isSpeakerActive
        ))
        
        // 检查当前路由中的蓝牙/外部设备
        for output in currentOutputs {
            let deviceType = mapPortTypeToDeviceType(output.portType)
            
            // 跳过内置设备（已添加）
            if output.portType == .builtInReceiver || output.portType == .builtInSpeaker {
                continue
            }
            
            // 避免重复
            let deviceId = "\(output.portType.rawValue)_\(output.uid ?? output.portName)"
            if !devices.contains(where: { $0.id == deviceId }) {
                devices.append(AudioOutputDevice(
                    id: deviceId,
                    name: output.portName,
                    type: deviceType,
                    portType: output.portType.rawValue,
                    isActive: true
                ))
            }
        }
        
        // 更新当前输出设备
        if let activeDevice = devices.first(where: { $0.isActive }) {
            currentOutputDevice = activeDevice
        }
        
        TgoLogger.shared.debug("可用输出设备列表: \(devices.map { "\($0.name)(\($0.type.rawValue))" })")
        return devices
        #else
        return [AudioOutputDevice(id: "default", name: "Default", type: .speaker, isActive: true)]
        #endif
    }
    
    #if os(iOS)
    private func mapPortTypeToDeviceType(_ portType: AVAudioSession.Port) -> AudioOutputDeviceType {
        switch portType {
        case .builtInReceiver:
            return .receiver
        case .builtInSpeaker:
            return .speaker
        case .headphones:
            return .headphones
        case .bluetoothA2DP:
            return .bluetoothA2DP
        case .bluetoothHFP:
            return .bluetoothHFP
        case .bluetoothLE:
            return .bluetoothLE
        case .airPlay:
            return .airPlay
        case .carAudio:
            return .carAudio
        case .HDMI:
            return .hdmi
        case .usbAudio:
            return .usbAudio
        default:
            return .unknown
        }
    }
    #endif
    
    // MARK: - 选择音频输出设备
    
    /// 选择指定的音频输出设备
    /// - Parameter device: 要切换到的输出设备
    /// - Returns: 是否切换成功
    @discardableResult
    public func selectAudioOutputDevice(_ device: AudioOutputDevice) async -> Bool {
        TgoLogger.shared.info("选择音频输出设备: \(device.name) (\(device.type.rawValue))")
        
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            
            switch device.type {
            case .receiver:
                // 切换到听筒
                try session.setCategory(
                    .playAndRecord,
                    mode: .voiceChat,
                    options: [.allowBluetooth, .allowBluetoothA2DP]
                )
                try session.overrideOutputAudioPort(.none)
                isSpeakerOn = false
                
            case .speaker:
                // 切换到扬声器
                try session.setCategory(
                    .playAndRecord,
                    mode: .voiceChat,
                    options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker]
                )
                try session.overrideOutputAudioPort(.speaker)
                isSpeakerOn = true
                
            case .headphones, .bluetoothA2DP, .bluetoothHFP, .bluetoothLE, .carAudio, .usbAudio:
                // 外部设备：取消扬声器覆盖，让系统自动路由到已连接的设备
                try session.setCategory(
                    .playAndRecord,
                    mode: .voiceChat,
                    options: [.allowBluetooth, .allowBluetoothA2DP]
                )
                try session.overrideOutputAudioPort(.none)
                isSpeakerOn = false
                
            case .airPlay, .hdmi:
                // AirPlay/HDMI：保持当前设置，由系统控制
                try session.overrideOutputAudioPort(.none)
                isSpeakerOn = false
                
            case .unknown:
                TgoLogger.shared.warning("未知设备类型，跳过切换")
                return false
            }
            
            try session.setActive(true)
            currentOutputDevice = device
            TgoLogger.shared.debug("音频输出设备切换成功: \(device.name)")
            return true
            
        } catch {
            TgoLogger.shared.error("切换音频输出设备失败: \(error.localizedDescription)")
            return false
        }
        #else
        return false
        #endif
    }
    
    public func dispose() {
        deviceChangeListeners.removeAll()
    }
}
