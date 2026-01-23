//
//  CallView.swift
//  TgoRTCIOS
//
//  Created by Cursor on 2026/1/18.
//

import SwiftUI
import LiveKit
import Combine

struct CallView: View {
    let serverUrl: String
    let roomResponse: RoomResponse
    let uid: String
    
    @Environment(\.dismiss) var dismiss
    
    @State private var isMicEnabled: Bool = true
    @State private var isCameraEnabled: Bool = true
    @State private var isConnected: Bool = false
    @State private var isConnecting: Bool = true
    @State private var statusMessage: String = "正在连接..."
    @State private var participants: [TgoParticipant] = []
    @State private var localParticipant: TgoParticipant?
    
    @State private var pulseValue: Double = 0.0
    
    // Combine 订阅
    @State private var cancellables = Set<AnyCancellable>()
    @State private var connectionStatusToken: ListenerToken?
    @State private var participantToken: ListenerToken?
    
    var body: some View {
        ZStack {
            // Background
            Color(hex: "0F0F23").ignoresSafeArea()
            RadialGradient(
                gradient: Gradient(colors: [Color(hex: "1A1A3E"), Color(hex: "0F0F23")]),
                center: .center,
                startRadius: 0,
                endRadius: 500
            ).ignoresSafeArea()
            
            VStack {
                // Header
                headerView
                
                // Content
                Group {
                    if isConnecting {
                        connectingView
                    } else if isConnected {
                        participantsGrid
                    } else {
                        errorView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Controls
                if isConnected {
                    controlsView
                }
            }
            .safeAreaInset(edge: .top) { Color.clear.frame(height: 0) }
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 0) }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            joinRoom()
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseValue = 1.0
            }
        }
        .onDisappear {
            leaveRoom()
        }
    }
    
    private var headerView: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(isConnected ? Color(hex: "10B981") : (isConnecting ? Color(hex: "FBBF24") : Color(hex: "EF4444")))
                    .frame(width: 8, height: 8)
                
                Text(roomResponse.roomId)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.1))
            .cornerRadius(20)
            
            Spacer()
            
            Text("\(participants.count) 人")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private var connectingView: some View {
        VStack(spacing: 32) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "6366F1").opacity(0.3 + pulseValue * 0.3),
                                Color(hex: "8B5CF6").opacity(0.3 + pulseValue * 0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "phone.connection")
                    .font(.system(size: 48))
                    .foregroundColor(.white)
            }
            
            Text(statusMessage)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
        }
    }
    
    private var errorView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color(hex: "EF4444").opacity(0.2))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundColor(Color(hex: "EF4444"))
            }
            
            Text(statusMessage)
                .font(.system(size: 16))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button(action: { dismiss() }) {
                Text("返回")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(Color(hex: "6366F1"))
                    .cornerRadius(12)
            }
        }
    }
    
    private var participantsGrid: some View {
        let count = participants.count
        let columns = count <= 1 ? 1 : (count <= 4 ? 2 : 3)
        let layout = Array(repeating: GridItem(.flexible(), spacing: 12), count: columns)
        
        return ScrollView {
            LazyVGrid(columns: layout, spacing: 12) {
                ForEach(participants, id: \.uid) { participant in
                    ParticipantTile(participant: participant)
                }
            }
            .padding(12)
        }
    }
    
    private var controlsView: some View {
        HStack(spacing: 32) {
            ControlButton(
                icon: isMicEnabled ? "mic.fill" : "mic.slash.fill",
                label: isMicEnabled ? "静音" : "取消静音",
                isActive: isMicEnabled,
                action: toggleMicrophone
            )
            
            ControlButton(
                icon: isCameraEnabled ? "video.fill" : "video.slash.fill",
                label: isCameraEnabled ? "关闭摄像头" : "打开摄像头",
                isActive: isCameraEnabled,
                action: toggleCamera
            )
            
            ControlButton(
                icon: "phone.down.fill",
                label: "挂断",
                isActive: false,
                isDestructive: true,
                action: hangUp
            )
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
    }
    
    // SDK Integration
    private func joinRoom() {
        let roomInfo = RoomInfo(
            roomName: roomResponse.roomId,
            token: roomResponse.token,
            url: roomResponse.url,
            maxParticipants: roomResponse.maxParticipants,
            rtcType: roomResponse.rtcType == 1 ? .video : .audio,
            isP2P: false,
            uidList: roomResponse.uids,
            timeout: roomResponse.timeout,
            creatorUid: roomResponse.creator,
            loginUID: uid
        )
        
        connectionStatusToken = TgoRTC.shared.roomManager.addConnectionStatusListener { roomName, status in
            DispatchQueue.main.async {
                switch status {
                case .connecting:
                    self.isConnecting = true
                    self.statusMessage = "正在连接..."
                case .connected:
                    self.isConnected = true
                    self.isConnecting = false
                    self.statusMessage = "已连接"
                    self.localParticipant = TgoRTC.shared.participantManager.getLocalParticipant()
                    self.updateParticipants()
                    self.subscribeToLocalParticipant()
                case .disconnected:
                    self.isConnected = false
                    self.isConnecting = false
                    self.statusMessage = "已断开连接"
                }
            }
        }
        
        participantToken = TgoRTC.shared.participantManager.addNewParticipantListener { _ in
            DispatchQueue.main.async {
                self.updateParticipants()
            }
        }
        
        // join 是非阻塞方法，调用后立即返回，连接在后台进行
        TgoRTC.shared.roomManager.join(
            roomInfo: roomInfo,
            micEnabled: true,
            cameraEnabled: true
        )
    }
    
    private func subscribeToLocalParticipant() {
        guard let local = localParticipant else { return }
        
        // 使用 Combine 订阅本地用户状态变化
        local.$isMicrophoneOn
            .receive(on: DispatchQueue.main)
            .sink { self.isMicEnabled = $0 }
            .store(in: &cancellables)
        
        local.$isCameraOn
            .receive(on: DispatchQueue.main)
            .sink { self.isCameraEnabled = $0 }
            .store(in: &cancellables)
    }
    
    private func updateParticipants() {
        DispatchQueue.main.async {
            self.participants = TgoRTC.shared.participantManager.getAllParticipants()
        }
    }
    
    private func toggleMicrophone() {
        guard let local = localParticipant else { return }
        Task {
            await local.setMicrophoneEnabled(!isMicEnabled)
        }
    }
    
    private func toggleCamera() {
        guard let local = localParticipant else { return }
        Task {
            await local.setCameraEnabled(!isCameraEnabled)
        }
    }
    
    private func hangUp() {
        leaveRoom()
        dismiss()
    }
    
    private func leaveRoom() {
        connectionStatusToken?.cancel()
        participantToken?.cancel()
        connectionStatusToken = nil
        participantToken = nil
        cancellables.removeAll()
        
        Task {
            let api = TgoRTCApi(baseUrl: serverUrl)
            await api.leaveRoom(roomId: roomResponse.roomId, uid: uid)
            await TgoRTC.shared.roomManager.leaveRoom()
        }
    }
}

struct ParticipantTile: View {
    @ObservedObject var participant: TgoParticipant
    
    var body: some View {
        ZStack {
            // 直接使用 @Published 属性，SwiftUI 自动订阅变化
            if participant.isCameraOn, participant.getVideoTrack(source: .camera) != nil {
                TgoTrackRenderer(participant: participant, source: .camera, fit: .fill)
            } else {
                Color(hex: "1A1A3E")
                VStack {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: participant.isLocal ? 
                                        [Color(hex: "6366F1"), Color(hex: "8B5CF6")] : 
                                        [Color(hex: "10B981"), Color(hex: "059669")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                        
                        Text(participant.uid.prefix(1).uppercased())
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            
            // Overlay
            VStack {
                HStack {
                    if participant.isLocal {
                        Text("本地")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color(hex: "6366F1"))
                            .cornerRadius(12)
                    }
                    Spacer()
                }
                .padding(12)
                
                Spacer()
                
                HStack {
                    Text(participant.isLocal ? "我" : formatUid(participant.uid))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // 直接使用 @Published 属性
                    if !participant.isMicrophoneOn {
                        Image(systemName: "mic.slash.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color(hex: "EF4444").opacity(0.8))
                            .cornerRadius(6)
                    }
                }
                .padding(12)
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .frame(minHeight: 150)
        .aspectRatio(1, contentMode: .fit)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(participant.isLocal ? Color(hex: "6366F1").opacity(0.5) : Color.white.opacity(0.1), lineWidth: 2)
        )
    }
    
    private func formatUid(_ uid: String) -> String {
        if uid.count > 10 {
            return "\(uid.prefix(10))..."
        }
        return uid
    }
}

struct ControlButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    var isDestructive: Bool = false
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            Button(action: action) {
                ZStack {
                    Circle()
                        .fill(isDestructive ? Color(hex: "EF4444") : (isActive ? Color.white.opacity(0.15) : Color.white.opacity(0.1)))
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(isDestructive || isActive ? .white : .white.opacity(0.6))
                }
                .overlay(
                    Circle()
                        .stroke(isDestructive ? Color.clear : (isActive ? Color(hex: "6366F1").opacity(0.5) : Color.white.opacity(0.1)), lineWidth: 2)
                )
                .shadow(color: isDestructive ? Color(hex: "EF4444").opacity(0.4) : .clear, radius: 20, x: 0, y: 8)
            }
            
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

#Preview {
    CallView(
        serverUrl: "http://47.117.96.203:8080",
        roomResponse: RoomResponse(
            sourceChannelId: "test",
            sourceChannelType: 0,
            roomId: "test-room",
            creator: "user1",
            token: "token",
            url: "url",
            status: 1,
            createdAt: "",
            maxParticipants: 9,
            timeout: 30,
            rtcType: 1,
            uids: ["user1"]
        ),
        uid: "user1"
    )
}
