//
//  RoomResponseObjC.m
//  ObjCExample
//
//  Created by Cursor on 2026/01/22.
//

#import "RoomResponseObjC.h"

@implementation RoomResponseObjC

+ (instancetype)fromJSON:(NSDictionary *)json {
    RoomResponseObjC *response = [[RoomResponseObjC alloc] init];
    response.roomId = json[@"room_id"] ?: @"";
    response.token = json[@"token"] ?: @"";
    response.url = json[@"url"] ?: @"";
    response.creator = json[@"creator"] ?: @"";
    response.maxParticipants = [json[@"max_participants"] integerValue];
    response.timeout = [json[@"timeout"] integerValue];
    response.rtcType = [json[@"rtc_type"] integerValue];
    response.uids = json[@"uids"] ?: @[];
    return response;
}

@end
