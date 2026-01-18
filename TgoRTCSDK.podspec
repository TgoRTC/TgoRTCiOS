Pod::Spec.new do |spec|
  spec.name         = "TgoRTCSDK"
  spec.version      = "1.0.0"
  spec.summary      = "TgoRTC SDK for iOS - Real-time Communication SDK"
  spec.description  = <<-DESC
    TgoRTCSDK 是一个基于 LiveKit 封装的实时音视频通信 SDK，
    提供简单易用的 API 用于房间管理、参与者管理和音频控制。
  DESC

  spec.homepage     = "https://github.com/your-org/TgoRTCIOS"
  spec.license      = { :type => "MIT", :file => "LICENSE" }
  spec.author       = { "Your Name" => "your.email@example.com" }
  
  spec.platform     = :ios, "14.0"
  spec.swift_version = "5.9"
  
  spec.source       = { :git => "https://github.com/your-org/TgoRTCIOS.git", :tag => "#{spec.version}" }
  spec.source_files = "TgoRTCSDK/**/*.swift"
  
  # LiveKit 依赖
  spec.dependency "LiveKit", "~> 2.11"
end
