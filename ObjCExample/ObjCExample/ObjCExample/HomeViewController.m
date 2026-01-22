//
//  HomeViewController.m
//  ObjCExample
//
//  Created by Cursor on 2026/01/22.
//

#import "HomeViewController.h"
#import "TgoRTCApiObjC.h"
#import "CallViewController.h"
#import <AVFoundation/AVFoundation.h>

@interface HomeViewController ()

@property (nonatomic, strong) UITextField *serverUrlField;
@property (nonatomic, strong) UITextField *roomIdField;
@property (nonatomic, strong) UILabel *userIdLabel;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, copy) NSString *uid;
@property (nonatomic, strong) TgoRTCApiObjC *api;

@end

@implementation HomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:15/255.0 green:15/255.0 blue:35/255.0 alpha:1.0];
    self.uid = [TgoRTCApiObjC generateUserId];
    
    [self setupUI];
}

- (void)setupUI {
    CGFloat width = self.view.bounds.size.width - 40;
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 100, width, 40)];
    titleLabel.text = @"TgoRTC ObjC Example";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:24];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:titleLabel];
    
    self.serverUrlField = [[UITextField alloc] initWithFrame:CGRectMake(20, 180, width, 50)];
    self.serverUrlField.placeholder = @"服务器地址";
    self.serverUrlField.text = @"http://47.117.96.203:8080";
    self.serverUrlField.borderStyle = UITextBorderStyleRoundedRect;
    [self.view addSubview:self.serverUrlField];
    
    self.roomIdField = [[UITextField alloc] initWithFrame:CGRectMake(20, 250, width, 50)];
    self.roomIdField.placeholder = @"房间号";
    self.roomIdField.borderStyle = UITextBorderStyleRoundedRect;
    [self.view addSubview:self.roomIdField];
    
    UIButton *createBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    createBtn.frame = CGRectMake(20, 330, (width - 20) / 2, 50);
    [createBtn setTitle:@"创建房间" forState:UIControlStateNormal];
    createBtn.backgroundColor = [UIColor systemBlueColor];
    [createBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    createBtn.layer.cornerRadius = 8;
    [createBtn addTarget:self action:@selector(createRoom) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:createBtn];
    
    UIButton *joinBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    joinBtn.frame = CGRectMake(20 + (width - 20) / 2 + 20, 330, (width - 20) / 2, 50);
    [joinBtn setTitle:@"加入房间" forState:UIControlStateNormal];
    joinBtn.backgroundColor = [UIColor systemGreenColor];
    [joinBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    joinBtn.layer.cornerRadius = 8;
    [joinBtn addTarget:self action:@selector(joinRoom) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:joinBtn];
    
    self.userIdLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 400, width, 30)];
    self.userIdLabel.text = [NSString stringWithFormat:@"用户 ID: %@", self.uid];
    self.userIdLabel.textColor = [UIColor lightGrayColor];
    self.userIdLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.userIdLabel];
    
    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    self.loadingIndicator.center = self.view.center;
    [self.view addSubview:self.loadingIndicator];
}

- (void)createRoom {
    [self handleRoomWithIsCreator:YES];
}

- (void)joinRoom {
    [self handleRoomWithIsCreator:NO];
}

- (void)handleRoomWithIsCreator:(BOOL)isCreator {
    NSString *roomId = [self.roomIdField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (roomId.length == 0) {
        return;
    }
    
    [self.loadingIndicator startAnimating];
    
    self.api = [[TgoRTCApiObjC alloc] initWithBaseUrl:self.serverUrlField.text];
    
    void(^completion)(RoomResponseObjC *, NSError *) = ^(RoomResponseObjC *response, NSError *error) {
        [self.loadingIndicator stopAnimating];
        if (error) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"错误" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
            return;
        }
        
        CallViewController *callVC = [[CallViewController alloc] init];
        callVC.roomResponse = response;
        callVC.serverUrl = self.serverUrlField.text;
        callVC.uid = self.uid;
        callVC.modalPresentationStyle = UIModalPresentationFullScreen;
        [self presentViewController:callVC animated:YES completion:nil];
    };
    
    if (isCreator) {
        [self.api createRoomWithRoomId:roomId uid:self.uid completion:completion];
    } else {
        [self.api joinRoomWithRoomId:roomId uid:self.uid completion:completion];
    }
}

@end
