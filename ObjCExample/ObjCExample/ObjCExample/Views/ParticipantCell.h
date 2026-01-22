//
//  ParticipantCell.h
//  ObjCExample
//
//  Created by Cursor on 2026/01/22.
//

#import <UIKit/UIKit.h>

// Forward declaration - the actual import happens in the .m file
@class TgoParticipantBridge;

NS_ASSUME_NONNULL_BEGIN

@interface ParticipantCell : UICollectionViewCell

@property (nonatomic, copy) NSString *participantUid;

- (void)configureWithParticipant:(TgoParticipantBridge *)participant;
- (void)configureWithUid:(NSString *)uid;

@end

NS_ASSUME_NONNULL_END
