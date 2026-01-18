//
//  HomeView.swift
//  TgoRTCIOS
//
//  Created by Cursor on 2026/1/18.
//

import SwiftUI
import AVFoundation

struct HomeView: View {
    @State private var serverUrl: String = ""
    @State private var roomId: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showCallView: Bool = false
    @State private var roomResponse: RoomResponse?
    @State private var uid: String = TgoRTCApi.generateUserId()
    
    private let defaultServerUrl = "http://47.117.96.203:8080"
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background Gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color(hex: "0F0F23"), Color(hex: "1A1A3E"), Color(hex: "0F0F23")]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .onTapGesture {
                    hideKeyboard()
                }
                
                ScrollView {
                    VStack(spacing: 40) {
                        Spacer().frame(height: 40)
                        
                        // Logo Area
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                                .shadow(color: Color(hex: "6366F1").opacity(0.4), radius: 20, x: 0, y: 0)
                            
                            Image(systemName: "video.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.white)
                        }
                        
                        VStack(spacing: 8) {
                            Text("TgoRTC")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.white)
                                .tracking(2)
                            
                            Text("实时音视频通话")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.6))
                                .tracking(4)
                        }
                        
                        Spacer().frame(height: 20)
                        
                        // Input Fields
                        VStack(spacing: 20) {
                            InputField(
                                text: $serverUrl,
                                label: "TgoRTC 服务器地址",
                                hint: "默认: \(defaultServerUrl)",
                                icon: "dns"
                            )
                            
                            InputField(
                                text: $roomId,
                                label: "房间号",
                                hint: "输入房间名称",
                                icon: "meeting_room"
                            )
                        }
                        
                        // Buttons
                        HStack(spacing: 16) {
                            GradientButton(
                                label: "创建房间",
                                icon: "plus.circle",
                                colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")],
                                action: { handleRoom(isCreator: true) }
                            )
                            .disabled(isLoading)
                            
                            GradientButton(
                                label: "加入房间",
                                icon: "arrow.right.circle",
                                colors: [Color(hex: "10B981"), Color(hex: "059669")],
                                action: { handleRoom(isCreator: false) }
                            )
                            .disabled(isLoading)
                        }
                        
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "6366F1")))
                                .scaleEffect(1.5)
                                .padding(.top, 32)
                        }
                        
                        // User ID
                        Text("用户 ID: \(uid)")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.top, 32)
                    }
                    .padding(.horizontal, 24)
                }
                .scrollDismissesKeyboard(.interactively)
                .onTapGesture {
                    hideKeyboard()
                }
            }
            .navigationDestination(isPresented: $showCallView) {
                if let response = roomResponse {
                    CallView(
                        serverUrl: serverUrl.isEmpty ? defaultServerUrl : serverUrl,
                        roomResponse: response,
                        uid: uid
                    )
                }
            }
            .alert("提示", isPresented: Binding<Bool>(
                get: { errorMessage != nil },
                set: { _ in errorMessage = nil }
            )) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    private func handleRoom(isCreator: Bool) {
        hideKeyboard()
        
        if roomId.trimmingCharacters(in: .whitespaces).isEmpty {
            errorMessage = "请输入房间号"
            return
        }
        
        isLoading = true
        
        Task {
            do {
                try await requestPermissions()
                
                let baseUrl = serverUrl.trimmingCharacters(in: .whitespaces).isEmpty ? defaultServerUrl : serverUrl
                let api = TgoRTCApi(baseUrl: baseUrl)
                let response: RoomResponse
                
                if isCreator {
                    response = try await api.createRoom(
                        roomId: roomId.trimmingCharacters(in: .whitespaces),
                        uid: uid
                    )
                } else {
                    response = try await api.joinRoom(
                        roomId: roomId.trimmingCharacters(in: .whitespaces),
                        uid: uid
                    )
                }
                
                await MainActor.run {
                    self.roomResponse = response
                    self.showCallView = true
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func requestPermissions() async throws {
        let videoStatus = AVCaptureDevice.authorizationStatus(for: .video)
        if videoStatus == .notDetermined {
            await AVCaptureDevice.requestAccess(for: .video)
        }
        
        let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        if audioStatus == .notDetermined {
            await AVCaptureDevice.requestAccess(for: .audio)
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// UI Components
struct InputField: View {
    @Binding var text: String
    let label: String
    let hint: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
            
            HStack {
                Image(systemName: icon == "dns" ? "network" : "door.left.hand.closed")
                    .foregroundColor(Color(hex: "6366F1"))
                    .frame(width: 24)
                
                TextField("", text: $text, prompt: Text(hint).foregroundColor(.white.opacity(0.3)))
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

struct GradientButton: View {
    let label: String
    let icon: String
    let colors: [Color]
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(16)
            .shadow(color: colors.first?.opacity(0.4) ?? .clear, radius: 20, x: 0, y: 8)
        }
    }
}

// Helper for Hex Colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    HomeView()
}
