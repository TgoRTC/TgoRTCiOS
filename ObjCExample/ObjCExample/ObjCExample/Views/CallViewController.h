//
//  CallViewController.h
//  ObjCExample
//
//  Created by Cursor on 2026/01/22.
//

#import <UIKit/UIKit.h>
#import "RoomResponseObjC.h"

NS_ASSUME_NONNULL_BEGIN

@interface CallViewController : UIViewController

@property (nonatomic, strong) RoomResponseObjC *roomResponse;
@property (nonatomic, copy) NSString *serverUrl;
@property (nonatomic, copy) NSString *uid;

@end

NS_ASSUME_NONNULL_END
