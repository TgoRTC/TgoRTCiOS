//
//  VideoInfo.swift
//  TgoRTCIOS
//
//  Created by Cursor on 2026/1/18.
//

import Foundation

public struct VideoInfo: Equatable {
    public let width: Int
    public let height: Int
    public let bitrate: Int
    public let frameRate: Double
    public let layerId: String?
    public let qualityLimitationReason: String?
    
    public init(width: Int, height: Int, bitrate: Int, frameRate: Double, layerId: String? = nil, qualityLimitationReason: String? = nil) {
        self.width = width
        self.height = height
        self.bitrate = bitrate
        self.frameRate = frameRate
        self.layerId = layerId
        self.qualityLimitationReason = qualityLimitationReason
    }
    
    public static let empty = VideoInfo(width: 0, height: 0, bitrate: 0, frameRate: 0)
    
    public var isValid: Bool {
        return width > 0 && height > 0
    }
    
    public var resolutionString: String {
        return "\(width)x\(height)"
    }
    
    public var bitrateString: String {
        if bitrate >= 1000000 {
            return String(format: "%.1f Mbps", Double(bitrate) / 1000000.0)
        } else if bitrate >= 1000 {
            return "\(bitrate / 1000) Kbps"
        }
        return "\(bitrate) bps"
    }
}
