//
//  CallViewController.m
//  ObjCExample
//
//  Created by Cursor on 2026/01/22.
//

#import "CallViewController.h"
#import "TgoRTCApiObjC.h"

// Import Swift classes from the project (includes TgoRTCSDK types via TgoSDKBridge.swift)
#import "ObjCExample-Swift.h"

@interface CallViewController () <TgoRoomDelegate, TgoParticipantDelegate>

@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *participantCountLabel;
@property (nonatomic, strong) UIButton *micButton;
@property (nonatomic, strong) UIButton *cameraButton;
@property (nonatomic, strong) UIButton *hangupButton;
@property (nonatomic, strong) TgoRTCApiObjC *api;

// Video grid
@property (nonatomic, strong) UIScrollView *videoScrollView;
@property (nonatomic, strong) UIView *videoContainerView;
@property (nonatomic, strong) NSMutableDictionary<NSString *, UIView *> *participantViews; // uid -> container view
@property (nonatomic, strong) NSMutableDictionary<NSString *, TgoVideoView *> *videoViews; // uid -> video view

@end

@implementation CallViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:15/255.0 green:15/255.0 blue:35/255.0 alpha:1.0];
    self.api = [[TgoRTCApiObjC alloc] initWithBaseUrl:self.serverUrl];
    self.participantViews = [NSMutableDictionary dictionary];
    self.videoViews = [NSMutableDictionary dictionary];
    
    [self setupUI];
    [self joinRoom];
}

- (void)setupUI {
    CGFloat screenWidth = self.view.bounds.size.width;
    CGFloat screenHeight = self.view.bounds.size.height;
    CGFloat safeTop = 60;
    CGFloat bottomHeight = 140;
    
    // Status label at top
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, safeTop, screenWidth - 40, 24)];
    self.statusLabel.textColor = [UIColor whiteColor];
    self.statusLabel.font = [UIFont boldSystemFontOfSize:16];
    self.statusLabel.text = @"正在连接...";
    [self.view addSubview:self.statusLabel];
    
    // Participant count label
    self.participantCountLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, safeTop + 28, screenWidth - 40, 20)];
    self.participantCountLabel.textColor = [UIColor lightGrayColor];
    self.participantCountLabel.font = [UIFont systemFontOfSize:14];
    self.participantCountLabel.text = @"0 人在房间";
    [self.view addSubview:self.participantCountLabel];
    
    // Video scroll view (for grid layout)
    CGFloat videoAreaTop = safeTop + 60;
    CGFloat videoAreaHeight = screenHeight - videoAreaTop - bottomHeight;
    self.videoScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, videoAreaTop, screenWidth, videoAreaHeight)];
    self.videoScrollView.showsVerticalScrollIndicator = YES;
    self.videoScrollView.showsHorizontalScrollIndicator = NO;
    self.videoScrollView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.videoScrollView];
    
    // Container view inside scroll view
    self.videoContainerView = [[UIView alloc] initWithFrame:self.videoScrollView.bounds];
    [self.videoScrollView addSubview:self.videoContainerView];
    
    // Bottom buttons (3 buttons: Mic, Camera, Hangup)
    CGFloat buttonSize = 70;
    CGFloat buttonSpacing = 40;
    CGFloat totalButtonsWidth = buttonSize * 3 + buttonSpacing * 2;
    CGFloat startX = (screenWidth - totalButtonsWidth) / 2;
    CGFloat buttonY = screenHeight - 110;
    
    // Mic button (initially on)
    self.micButton = [self createCircleButtonWithFrame:CGRectMake(startX, buttonY, buttonSize, buttonSize)
                                                 title:@"关闭\n麦克风"
                                               bgColor:[UIColor colorWithWhite:0.3 alpha:0.8]];
    [self.micButton addTarget:self action:@selector(toggleMic) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.micButton];
    
    // Camera button (initially on)
    self.cameraButton = [self createCircleButtonWithFrame:CGRectMake(startX + buttonSize + buttonSpacing, buttonY, buttonSize, buttonSize)
                                                    title:@"关闭\n摄像头"
                                                  bgColor:[UIColor colorWithWhite:0.3 alpha:0.8]];
    [self.cameraButton addTarget:self action:@selector(toggleCamera) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.cameraButton];
    
    // Hangup button
    self.hangupButton = [self createCircleButtonWithFrame:CGRectMake(startX + (buttonSize + buttonSpacing) * 2, buttonY, buttonSize, buttonSize)
                                                    title:@"挂断"
                                                  bgColor:[UIColor redColor]];
    [self.hangupButton addTarget:self action:@selector(hangup) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.hangupButton];
}

- (UIButton *)createCircleButtonWithFrame:(CGRect)frame title:(NSString *)title bgColor:(UIColor *)bgColor {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = frame;
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:11];
    button.titleLabel.numberOfLines = 2;
    button.titleLabel.textAlignment = NSTextAlignmentCenter;
    button.backgroundColor = bgColor;
    button.layer.cornerRadius = frame.size.width / 2;
    button.clipsToBounds = YES;
    return button;
}

#pragma mark - Video Grid Management

- (void)addParticipantView:(TgoParticipantBridge *)participant {
    NSString *uid = participant.uid;
    
    // Skip if already exists
    if (self.participantViews[uid]) {
        return;
    }
    
    // Create container view for this participant
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    container.layer.cornerRadius = 12;
    container.clipsToBounds = YES;
    
    // Create video view
    TgoVideoView *videoView = [[TgoVideoView alloc] initWithFrame:CGRectZero];
    [videoView setLayoutMode:TgoVideoLayoutModeFill];
    if (participant.isLocal) {
        [videoView setMirrorMode:TgoVideoMirrorModeMirror];
    }
    [container addSubview:videoView];
    
    // Create label for UID
    UILabel *uidLabel = [[UILabel alloc] init];
    uidLabel.text = participant.isLocal ? [NSString stringWithFormat:@"%@ (我)", uid] : uid;
    uidLabel.textColor = [UIColor whiteColor];
    uidLabel.font = [UIFont systemFontOfSize:12];
    uidLabel.textAlignment = NSTextAlignmentCenter;
    uidLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
    uidLabel.tag = 100; // Tag for finding later
    [container addSubview:uidLabel];
    
    // Create mic indicator
    UIView *micIndicator = [[UIView alloc] init];
    micIndicator.backgroundColor = participant.isMicrophoneOn ? [UIColor greenColor] : [UIColor redColor];
    micIndicator.layer.cornerRadius = 6;
    micIndicator.tag = 101;
    [container addSubview:micIndicator];
    
    // Store references
    self.participantViews[uid] = container;
    self.videoViews[uid] = videoView;
    
    [self.videoContainerView addSubview:container];
    
    // Attach video
    [participant attachCameraTo:videoView];
    
    // Relayout grid
    [self layoutVideoGrid];
}

- (void)removeParticipantView:(NSString *)uid {
    UIView *container = self.participantViews[uid];
    TgoVideoView *videoView = self.videoViews[uid];
    
    if (container) {
        [container removeFromSuperview];
        [self.participantViews removeObjectForKey:uid];
    }
    
    if (videoView) {
        [videoView detach];
        [self.videoViews removeObjectForKey:uid];
    }
    
    [self layoutVideoGrid];
}

- (void)layoutVideoGrid {
    NSArray *uids = self.participantViews.allKeys;
    NSInteger count = uids.count;
    
    if (count == 0) {
        self.participantCountLabel.text = @"0 人在房间";
        return;
    }
    
    self.participantCountLabel.text = [NSString stringWithFormat:@"%ld 人在房间", (long)count];
    
    CGFloat screenWidth = self.view.bounds.size.width;
    CGFloat padding = 12;
    CGFloat spacing = 8;
    
    // Calculate grid dimensions based on count
    NSInteger columns;
    if (count == 1) {
        columns = 1;
    } else if (count <= 4) {
        columns = 2;
    } else {
        columns = 3;
    }
    
    CGFloat itemWidth = (screenWidth - padding * 2 - spacing * (columns - 1)) / columns;
    CGFloat itemHeight = itemWidth * 4 / 3; // 4:3 aspect ratio
    
    NSInteger rows = (count + columns - 1) / columns;
    CGFloat totalHeight = rows * itemHeight + (rows - 1) * spacing + padding * 2;
    
    // Update container and scroll view
    self.videoContainerView.frame = CGRectMake(0, 0, screenWidth, totalHeight);
    self.videoScrollView.contentSize = CGSizeMake(screenWidth, totalHeight);
    
    // Sort UIDs to keep local first
    NSArray *sortedUIDs = [uids sortedArrayUsingComparator:^NSComparisonResult(NSString *uid1, NSString *uid2) {
        TgoParticipantBridge *p1 = [[TgoRTCBridge shared] getLocalParticipant];
        if ([uid1 isEqualToString:p1.uid]) return NSOrderedAscending;
        if ([uid2 isEqualToString:p1.uid]) return NSOrderedDescending;
        return [uid1 compare:uid2];
    }];
    
    // Layout each participant
    for (NSInteger i = 0; i < sortedUIDs.count; i++) {
        NSString *uid = sortedUIDs[i];
        UIView *container = self.participantViews[uid];
        TgoVideoView *videoView = self.videoViews[uid];
        
        NSInteger row = i / columns;
        NSInteger col = i % columns;
        
        CGFloat x = padding + col * (itemWidth + spacing);
        CGFloat y = padding + row * (itemHeight + spacing);
        
        container.frame = CGRectMake(x, y, itemWidth, itemHeight);
        videoView.frame = container.bounds;
        
        // Layout UID label at bottom
        UILabel *uidLabel = [container viewWithTag:100];
        uidLabel.frame = CGRectMake(0, itemHeight - 24, itemWidth, 24);
        
        // Layout mic indicator
        UIView *micIndicator = [container viewWithTag:101];
        micIndicator.frame = CGRectMake(8, 8, 12, 12);
    }
}

- (void)updateMicIndicator:(NSString *)uid isOn:(BOOL)isOn {
    UIView *container = self.participantViews[uid];
    if (container) {
        UIView *micIndicator = [container viewWithTag:101];
        micIndicator.backgroundColor = isOn ? [UIColor greenColor] : [UIColor redColor];
    }
}

#pragma mark - Room Actions

- (void)joinRoom {
    TgoRoomInfoObjC *roomInfo = [[TgoRoomInfoObjC alloc] init];
    roomInfo.roomName = self.roomResponse.roomId;
    roomInfo.token = self.roomResponse.token;
    roomInfo.url = self.roomResponse.url;
    roomInfo.loginUID = self.uid;
    roomInfo.rtcType = (self.roomResponse.rtcType == 1) ? TgoRTCTypeObjCVideo : TgoRTCTypeObjCAudio;
    
    [TgoRTCBridge shared].room.delegate = self;
    [TgoRTCBridge shared].participantDelegate = self;
    
    __weak typeof(self) weakSelf = self;
    [[TgoRTCBridge shared].room joinWithRoomInfo:roomInfo micEnabled:YES cameraEnabled:YES completion:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            
            if (success) {
                self.statusLabel.text = @"已连接";
                // Add local participant view
                TgoParticipantBridge *local = [[TgoRTCBridge shared] getLocalParticipant];
                if (local) {
                    [self addParticipantView:local];
                }
            } else {
                self.statusLabel.text = @"连接失败";
            }
        });
    }];
}

- (void)toggleMic {
    TgoParticipantBridge *local = [[TgoRTCBridge shared] getLocalParticipant];
    [local setMicrophoneEnabled:!local.isMicrophoneOn completion:nil];
}

- (void)toggleCamera {
    TgoParticipantBridge *local = [[TgoRTCBridge shared] getLocalParticipant];
    [local setCameraEnabled:!local.isCameraOn completion:nil];
}

- (void)hangup {
    // Clear all video views
    for (NSString *uid in self.videoViews.allKeys) {
        [self.videoViews[uid] detach];
    }
    [self.participantViews removeAllObjects];
    [self.videoViews removeAllObjects];
    
    [self.api leaveRoomWithRoomId:self.roomResponse.roomId uid:self.uid];
    [[TgoRTCBridge shared].room leaveRoomWithCompletion:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self dismissViewControllerAnimated:YES completion:nil];
        });
    }];
}

#pragma mark - TgoRoomDelegate

- (void)room:(NSString *)roomName didChangeStatus:(TgoConnectStatusObjC)status {
    dispatch_async(dispatch_get_main_queue(), ^{
        switch (status) {
            case TgoConnectStatusObjCConnecting:
                self.statusLabel.text = @"正在连接...";
                break;
            case TgoConnectStatusObjCConnected:
                self.statusLabel.text = @"已连接";
                break;
            case TgoConnectStatusObjCDisconnected:
                self.statusLabel.text = @"已断开";
                break;
        }
    });
}

#pragma mark - TgoParticipantDelegate

- (void)participantDidJoin:(TgoParticipantBridge *)participant {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusLabel.text = [NSString stringWithFormat:@"用户 %@ 加入", participant.uid];
        [self addParticipantView:participant];
    });
}

- (void)participantDidLeave:(TgoParticipantBridge *)participant {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusLabel.text = [NSString stringWithFormat:@"用户 %@ 离开", participant.uid];
        [self removeParticipantView:participant.uid];
    });
}

- (void)participant:(TgoParticipantBridge *)participant didUpdateCameraOn:(BOOL)isOn {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (participant.isLocal) {
            // Update button title and style based on state
            NSString *title = isOn ? @"关闭\n摄像头" : @"开启\n摄像头";
            [self.cameraButton setTitle:title forState:UIControlStateNormal];
            self.cameraButton.backgroundColor = isOn ? [UIColor colorWithWhite:0.3 alpha:0.8] : [UIColor darkGrayColor];
        }
        
        // Re-attach video if turned on
        TgoVideoView *videoView = self.videoViews[participant.uid];
        if (videoView && isOn) {
            [participant attachCameraTo:videoView];
        }
    });
}

- (void)participant:(TgoParticipantBridge *)participant didUpdateMicrophoneOn:(BOOL)isOn {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (participant.isLocal) {
            // Update button title and style based on state
            NSString *title = isOn ? @"关闭\n麦克风" : @"开启\n麦克风";
            [self.micButton setTitle:title forState:UIControlStateNormal];
            self.micButton.backgroundColor = isOn ? [UIColor colorWithWhite:0.3 alpha:0.8] : [UIColor darkGrayColor];
        }
        
        // Update mic indicator
        [self updateMicIndicator:participant.uid isOn:isOn];
    });
}

@end
