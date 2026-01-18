//
//  Const.swift
//  TgoRTCIOS
//
//  Created by Slun on 2026/1/16.
//

public enum RTCType {
    case audio
    case video
}

public enum ConnectStatus {
    // Attempting to connect to the room.
    case connecting
    
    // Successfully connected to the room.
    case  connected
    
    // Disconnected from the room.
    case disconnected
}


// Camera position (front or back).
public enum TgoCameraPosition {
    // Front-facing camera.
    case front
    
    // Back-facing camera.
    case back
}

// Connection quality indicator.
public enum TgoConnectionQuality {
    // Unknown connection quality.
    case unknown
    
    // Excellent connection quality.
    case excellent
    
    // Good connection quality.
    case good
    
    // Poor connection quality.
    case poor
    
    // Connection lost.
    case lost
}
