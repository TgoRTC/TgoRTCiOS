//
//  TgoRTCApi.swift
//  TgoRTCIOS
//
//  Created by Cursor on 2026/1/18.
//

import Foundation

public enum TgoRTCError: Error, LocalizedError {
    case invalidURL
    case networkError(String)
    case serverError(String)
    case decodeError
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的服务器地址"
        case .networkError(let msg): return "网络请求失败: \(msg)"
        case .serverError(let msg): return msg
        case .decodeError: return "数据解析失败"
        }
    }
}

public class TgoRTCApi {
    private let baseUrl: String
    
    public init(baseUrl: String) {
        var url = baseUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        while url.hasSuffix("/") {
            url.removeLast()
        }
        if !url.lowercased().hasPrefix("http://") && !url.lowercased().hasPrefix("https://") {
            url = "http://\(url)"
        }
        self.baseUrl = url
    }
    
    private func postRequest(path: String, body: [String: Any]) async throws -> Data {
        guard let url = URL(string: "\(baseUrl)\(path)") else {
            throw TgoRTCError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TgoRTCError.networkError("无效的响应")
        }
        
        if httpResponse.statusCode == 200 {
            return data
        } else {
            let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let message = errorJson?["message"] as? String ?? "服务器错误 (\(httpResponse.statusCode))"
            throw TgoRTCError.serverError(message)
        }
    }
    
    public func createRoom(roomId: String, uid: String, maxParticipants: Int = 9, rtcType: Int = 1) async throws -> RoomResponse {
        let body: [String: Any] = [
            "source_channel_id": "channel_ios",
            "source_channel_type": 0,
            "creator": uid,
            "room_id": roomId,
            "rtc_type": rtcType,
            "invite_on": 0,
            "max_participants": maxParticipants,
            "uids": [TgoRTCApi.generateUUID()],
            "device_type": "app"
        ]
        
        let data = try await postRequest(path: "/api/v1/rooms", body: body)
        let decoder = JSONDecoder()
        return try decoder.decode(RoomResponse.self, from: data)
    }
    
    public func joinRoom(roomId: String, uid: String) async throws -> RoomResponse {
        let body: [String: Any] = [
            "uid": uid,
            "device_type": "app"
        ]
        
        let data = try await postRequest(path: "/api/v1/rooms/\(roomId)/join", body: body)
        let decoder = JSONDecoder()
        return try decoder.decode(RoomResponse.self, from: data)
    }
    
    public func leaveRoom(roomId: String, uid: String) async {
        let body: [String: Any] = [
            "uid": uid
        ]
        
        do {
            _ = try await postRequest(path: "/api/v1/rooms/\(roomId)/leave", body: body)
        } catch {
            print("离开房间 API 调用失败: \(error)")
        }
    }
    
    public static func generateUUID() -> String {
        return UUID().uuidString.lowercased()
    }
    
    public static func generateUserId() -> String {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000) % 100000
        return "user_\(timestamp)"
    }
}
