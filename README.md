# TgoRTCSDK

TgoRTCSDK 是一个基于 [LiveKit](https://livekit.io/) 封装的实时音视频通话 SDK，支持 Swift 和 Objective-C 项目。

## 功能特性

- 音视频通话
- 多人会议支持
- 麦克风/摄像头控制
- 前后摄像头切换
- 连接状态监听
- 参与者管理

## 系统要求

- iOS 14.0+
- Xcode 15.0+
- Swift 5.9+

---

## Swift 项目集成

### 步骤 1：添加 SPM 依赖

1. 在 Xcode 中打开你的项目
2. 选择 **File → Add Package Dependencies...**
3. 输入仓库地址：
   ```
   https://github.com/TgoRTC/TgoRTCiOS
   ```
4. 选择版本规则（推荐 **Branch: main**）
5. 点击 **Add Package**
6. 在弹出的窗口中勾选 **TgoRTCSDK**，点击 **Add Package**

### 步骤 2：导入并使用

```swift
import TgoRTCSDK

// 配置 SDK
TgoRTC.shared.configure(options: Options(
    mirror: true,      // 本地视频是否镜像
    logEnabled: true   // 是否开启日志
))

// 加入房间
let roomInfo = RoomInfo(
    url: "wss://your-livekit-server.com",
    token: "your-token",
    roomName: "room-name",
    loginUID: "user-id",
    rtcType: .video
)

await RoomManager.shared.join(
    roomInfo: roomInfo,
    micEnabled: true,
    cameraEnabled: true
)

// 获取本地参与者
let localParticipant = TgoRTC.shared.participantManager.localParticipant

// 控制麦克风/摄像头
await localParticipant?.setMicrophoneEnabled(false)
await localParticipant?.setCameraEnabled(false)

// 离开房间
await RoomManager.shared.leaveRoom()
```

### 步骤 3：显示视频

```swift
import SwiftUI
import TgoRTCSDK

struct VideoCallView: View {
    @ObservedObject var participant: TgoParticipant
    
    var body: some View {
        TgoTrackRenderer(participant: participant, source: .camera, fit: .fill)
    }
}
```

---

## Objective-C 项目集成

### 步骤 1：添加 SPM 依赖

与 Swift 项目相同：

1. 在 Xcode 中打开你的项目
2. 选择 **File → Add Package Dependencies...**
3. 输入仓库地址：
   ```
   https://github.com/TgoRTC/TgoRTCiOS
   ```
4. 选择版本规则（推荐 **Branch: main**）
5. 点击 **Add Package**
6. 勾选 **TgoRTCSDK**，点击 **Add Package**

### 步骤 2：创建 Swift 桥接文件

由于 SDK 是用 Swift 编写的，Objective-C 项目需要一个桥接文件来访问 SDK 类型。

1. 在项目中创建一个新的 Swift 文件，命名为 `TgoSDKBridge.swift`
2. 如果 Xcode 询问是否创建 Bridging Header，选择 **Create Bridging Header**
3. 将以下内容复制到 `TgoSDKBridge.swift`：

```swift
import Foundation
import TgoRTCSDK

// Re-export SDK types for Objective-C access
public typealias TgoRTCTypeObjC = TgoRTCSDK.TgoRTCTypeObjC
public typealias TgoConnectStatusObjC = TgoRTCSDK.TgoConnectStatusObjC
public typealias TgoCameraPositionObjC = TgoRTCSDK.TgoCameraPositionObjC
public typealias TgoConnectionQualityObjC = TgoRTCSDK.TgoConnectionQualityObjC
public typealias TgoRoomInfoObjC = TgoRTCSDK.TgoRoomInfoObjC
public typealias TgoVideoInfoObjC = TgoRTCSDK.TgoVideoInfoObjC
public typealias TgoOptionsObjC = TgoRTCSDK.TgoOptionsObjC
public typealias TgoRTCBridge = TgoRTCSDK.TgoRTCBridge
public typealias TgoRoomBridge = TgoRTCSDK.TgoRoomBridge
public typealias TgoParticipantBridge = TgoRTCSDK.TgoParticipantBridge
public typealias TgoAudioBridge = TgoRTCSDK.TgoAudioBridge
public typealias TgoVideoView = TgoRTCSDK.TgoVideoView
public typealias TgoVideoLayoutMode = TgoRTCSDK.TgoVideoLayoutMode
public typealias TgoVideoMirrorMode = TgoRTCSDK.TgoVideoMirrorMode

// Protocols for delegates
@objc public protocol TgoRoomDelegate: AnyObject {
    @objc optional func room(_ roomName: String, didChangeStatus status: TgoConnectStatusObjC)
    @objc optional func room(_ roomName: String, didUpdateVideoInfo info: TgoVideoInfoObjC)
}

@objc public protocol TgoParticipantDelegate: AnyObject {
    @objc optional func participant(_ participant: TgoParticipantBridge, didUpdateMicrophoneOn isOn: Bool)
    @objc optional func participant(_ participant: TgoParticipantBridge, didUpdateCameraOn isOn: Bool)
    @objc optional func participant(_ participant: TgoParticipantBridge, didUpdateSpeaking isSpeaking: Bool)
    @objc optional func participantDidJoin(_ participant: TgoParticipantBridge)
    @objc optional func participantDidLeave(_ participant: TgoParticipantBridge)
    @objc optional func participantDidTimeout(_ participant: TgoParticipantBridge)
}

// Helper class
@objc public class TgoSDKHelper: NSObject {
    @objc public static func getSharedBridge() -> TgoRTCBridge {
        return TgoRTCBridge.shared
    }
    
    @objc public static func createRoomInfo() -> TgoRoomInfoObjC {
        return TgoRoomInfoObjC()
    }
    
    @objc public static func createOptions() -> TgoOptionsObjC {
        return TgoOptionsObjC()
    }
}
```

### 步骤 3：配置 Build Settings

确保以下设置正确：

1. 选择项目 → **Build Settings**
2. 搜索 `Swift Language Version`，设置为 **Swift 5** 或更高
3. 搜索 `Defines Module`，设置为 **Yes**

### 步骤 4：导入并使用

在 Objective-C 文件中导入生成的 Swift 头文件：

```objc
#import "YourProjectName-Swift.h"
```

> 注意：将 `YourProjectName` 替换为你的项目名称

### 步骤 5：使用示例

```objc
// 加入房间
- (void)joinRoom {
    TgoRoomInfoObjC *roomInfo = [[TgoRoomInfoObjC alloc] init];
    roomInfo.url = @"wss://your-livekit-server.com";
    roomInfo.token = @"your-token";
    roomInfo.roomName = @"room-name";
    roomInfo.loginUID = @"user-id";
    roomInfo.rtcType = TgoRTCTypeObjCVideo;
    
    // 设置代理
    [TgoRTCBridge shared].room.delegate = self;
    [TgoRTCBridge shared].participantDelegate = self;
    
    // 加入房间
    [[TgoRTCBridge shared].room joinWithRoomInfo:roomInfo 
                                      micEnabled:YES 
                                   cameraEnabled:YES 
                                      completion:^(BOOL success) {
        if (success) {
            NSLog(@"加入房间成功");
        }
    }];
}

// 控制麦克风
- (void)toggleMic {
    TgoParticipantBridge *local = [[TgoRTCBridge shared] getLocalParticipant];
    [local setMicrophoneEnabled:!local.isMicrophoneOn completion:nil];
}

// 控制摄像头
- (void)toggleCamera {
    TgoParticipantBridge *local = [[TgoRTCBridge shared] getLocalParticipant];
    [local setCameraEnabled:!local.isCameraOn completion:nil];
}

// 离开房间
- (void)leaveRoom {
    [[TgoRTCBridge shared].room leaveRoomWithCompletion:^{
        NSLog(@"已离开房间");
    }];
}
```

### 步骤 6：显示视频

```objc
// 创建视频视图
@property (nonatomic, strong) TgoVideoView *videoView;

// 初始化视频视图
self.videoView = [[TgoVideoView alloc] initWithFrame:CGRectMake(0, 0, 200, 300)];
[self.videoView setLayoutMode:TgoVideoLayoutModeFill];
[self.videoView setMirrorMode:TgoVideoMirrorModeMirror]; // 本地视频建议镜像
[self.view addSubview:self.videoView];

// 附加参与者视频
TgoParticipantBridge *participant = [[TgoRTCBridge shared] getLocalParticipant];
[participant attachCameraTo:self.videoView];

// 分离视频
[self.videoView detach];
```

### 步骤 7：实现代理方法

```objc
@interface YourViewController () <TgoRoomDelegate, TgoParticipantDelegate>
@end

@implementation YourViewController

#pragma mark - TgoRoomDelegate

- (void)room:(NSString *)roomName didChangeStatus:(TgoConnectStatusObjC)status {
    switch (status) {
        case TgoConnectStatusObjCConnecting:
            NSLog(@"正在连接...");
            break;
        case TgoConnectStatusObjCConnected:
            NSLog(@"已连接");
            break;
        case TgoConnectStatusObjCDisconnected:
            NSLog(@"已断开");
            break;
    }
}

#pragma mark - TgoParticipantDelegate

- (void)participantDidJoin:(TgoParticipantBridge *)participant {
    NSLog(@"用户 %@ 加入", participant.uid);
}

- (void)participantDidLeave:(TgoParticipantBridge *)participant {
    NSLog(@"用户 %@ 离开", participant.uid);
}

- (void)participant:(TgoParticipantBridge *)participant didUpdateMicrophoneOn:(BOOL)isOn {
    NSLog(@"用户 %@ 麦克风状态: %@", participant.uid, isOn ? @"开" : @"关");
}

- (void)participant:(TgoParticipantBridge *)participant didUpdateCameraOn:(BOOL)isOn {
    NSLog(@"用户 %@ 摄像头状态: %@", participant.uid, isOn ? @"开" : @"关");
}

@end
```

---

## API 对照表

| Swift API | Objective-C API |
|-----------|-----------------|
| `TgoRTC.shared` | `[TgoRTCBridge shared]` |
| `RoomManager.shared` | `[TgoRTCBridge shared].room` |
| `AudioManager.shared` | `[TgoRTCBridge shared].audio` |
| `TgoParticipant` | `TgoParticipantBridge` |
| `RoomInfo` | `TgoRoomInfoObjC` |
| `Options` | `TgoOptionsObjC` |
| `RTCType` | `TgoRTCTypeObjC` |
| `ConnectStatus` | `TgoConnectStatusObjC` |
| `TgoTrackRenderer` (SwiftUI) | `TgoVideoView` (UIKit) |

---

## 权限配置

在 `Info.plist` 中添加以下权限：

```xml
<key>NSCameraUsageDescription</key>
<string>需要访问摄像头进行视频通话</string>
<key>NSMicrophoneUsageDescription</key>
<string>需要访问麦克风进行语音通话</string>
```

如果使用 HTTP 服务器（仅开发环境），还需添加：

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

---

## 示例项目

- **Swift 示例**：`TgoRTCIOS/` - SwiftUI 实现的完整示例
- **Objective-C 示例**：`ObjCExample/` - UIKit 实现的完整示例

---

## 许可证

MIT License
