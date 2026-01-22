//
//  TgoRTCApiObjC.h
//  ObjCExample
//
//  Created by Cursor on 2026/01/22.
//

#import <Foundation/Foundation.h>
#import "RoomResponseObjC.h"

NS_ASSUME_NONNULL_BEGIN

@interface TgoRTCApiObjC : NSObject

- (instancetype)initWithBaseUrl:(NSString *)baseUrl;

- (void)createRoomWithRoomId:(NSString *)roomId
                         uid:(NSString *)uid
                  completion:(void(^)(RoomResponseObjC * _Nullable response, NSError * _Nullable error))completion;

- (void)joinRoomWithRoomId:(NSString *)roomId
                       uid:(NSString *)uid
                completion:(void(^)(RoomResponseObjC * _Nullable response, NSError * _Nullable error))completion;

- (void)leaveRoomWithRoomId:(NSString *)roomId uid:(NSString *)uid;

+ (NSString *)generateUserId;

@end

NS_ASSUME_NONNULL_END
