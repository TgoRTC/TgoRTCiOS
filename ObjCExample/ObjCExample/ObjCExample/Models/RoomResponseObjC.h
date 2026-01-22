//
//  RoomResponseObjC.h
//  ObjCExample
//
//  Created by Cursor on 2026/01/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RoomResponseObjC : NSObject

@property (nonatomic, copy) NSString *roomId;
@property (nonatomic, copy) NSString *token;
@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *creator;
@property (nonatomic, assign) NSInteger maxParticipants;
@property (nonatomic, assign) NSInteger timeout;
@property (nonatomic, assign) NSInteger rtcType;
@property (nonatomic, strong) NSArray<NSString *> *uids;

+ (instancetype)fromJSON:(NSDictionary *)json;

@end

NS_ASSUME_NONNULL_END
