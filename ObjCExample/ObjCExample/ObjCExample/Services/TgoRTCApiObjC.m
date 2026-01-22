//
//  TgoRTCApiObjC.m
//  ObjCExample
//
//  Created by Cursor on 2026/01/22.
//

#import "TgoRTCApiObjC.h"

@interface TgoRTCApiObjC ()
@property (nonatomic, copy) NSString *baseUrl;
@end

@implementation TgoRTCApiObjC

- (instancetype)initWithBaseUrl:(NSString *)baseUrl {
    self = [super init];
    if (self) {
        NSString *url = [baseUrl stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        while ([url hasSuffix:@"/"]) {
            url = [url substringToIndex:url.length - 1];
        }
        if (![[url lowercaseString] hasPrefix:@"http://"] && ![[url lowercaseString] hasPrefix:@"https://"]) {
            url = [NSString stringWithFormat:@"http://%@", url];
        }
        _baseUrl = url;
    }
    return self;
}

- (void)postRequestWithPath:(NSString *)path body:(NSDictionary *)body completion:(void(^)(NSData * _Nullable data, NSError * _Nullable error))completion {
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", self.baseUrl, path]];
    if (!url) {
        completion(nil, [NSError errorWithDomain:@"TgoRTCError" code:400 userInfo:@{NSLocalizedDescriptionKey: @"无效的服务器地址"}]);
        return;
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:(NSJSONWritingOptions)0 error:nil];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            completion(nil, error);
            return;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode == 200) {
            completion(data, nil);
        } else {
            NSDictionary *errorJson = [NSJSONSerialization JSONObjectWithData:data options:(NSJSONReadingOptions)0 error:nil];
            NSString *message = errorJson[@"message"] ?: [NSString stringWithFormat:@"服务器错误 (%ld)", (long)httpResponse.statusCode];
            completion(nil, [NSError errorWithDomain:@"TgoRTCError" code:httpResponse.statusCode userInfo:@{NSLocalizedDescriptionKey: message}]);
        }
    }] resume];
}

- (void)createRoomWithRoomId:(NSString *)roomId uid:(NSString *)uid completion:(void (^)(RoomResponseObjC * _Nullable, NSError * _Nullable))completion {
    NSDictionary *body = @{
        @"source_channel_id": @"channel_ios",
        @"source_channel_type": @0,
        @"creator": uid,
        @"room_id": roomId,
        @"rtc_type": @1,
        @"invite_on": @0,
        @"max_participants": @9,
        @"uids": @[[[NSUUID UUID] UUIDString].lowercaseString],
        @"device_type": @"app"
    };
    
    [self postRequestWithPath:@"/api/v1/rooms" body:body completion:^(NSData * _Nullable data, NSError * _Nullable error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
            return;
        }
        
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:(NSJSONReadingOptions)0 error:nil];
        RoomResponseObjC *response = [RoomResponseObjC fromJSON:json];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(response, nil);
        });
    }];
}

- (void)joinRoomWithRoomId:(NSString *)roomId uid:(NSString *)uid completion:(void (^)(RoomResponseObjC * _Nullable, NSError * _Nullable))completion {
    NSDictionary *body = @{
        @"uid": uid,
        @"device_type": @"app"
    };
    
    [self postRequestWithPath:[NSString stringWithFormat:@"/api/v1/rooms/%@/join", roomId] body:body completion:^(NSData * _Nullable data, NSError * _Nullable error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
            return;
        }
        
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:(NSJSONReadingOptions)0 error:nil];
        RoomResponseObjC *response = [RoomResponseObjC fromJSON:json];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(response, nil);
        });
    }];
}

- (void)leaveRoomWithRoomId:(NSString *)roomId uid:(NSString *)uid {
    NSDictionary *body = @{@"uid": uid};
    [self postRequestWithPath:[NSString stringWithFormat:@"/api/v1/rooms/%@/leave", roomId] body:body completion:^(NSData * _Nullable data, NSError * _Nullable error) {
        if (error) {
            NSLog(@"离开房间 API 调用失败: %@", error);
        }
    }];
}

+ (NSString *)generateUserId {
    NSInteger timestamp = (NSInteger)([[NSDate date] timeIntervalSince1970] * 1000) % 100000;
    return [NSString stringWithFormat:@"user_%ld", (long)timestamp];
}

@end
