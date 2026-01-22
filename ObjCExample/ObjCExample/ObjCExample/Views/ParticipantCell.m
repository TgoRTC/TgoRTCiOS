//
//  ParticipantCell.m
//  ObjCExample
//
//  Created by Cursor on 2026/01/22.
//

#import "ParticipantCell.h"
#import "ObjCExample-Swift.h"

@interface ParticipantCell ()
@property (nonatomic, strong) UILabel *uidLabel;
@property (nonatomic, strong) UIView *videoContainer;
@end

@implementation ParticipantCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.05];
        self.layer.cornerRadius = 12;
        self.clipsToBounds = YES;
        
        _videoContainer = [[UIView alloc] initWithFrame:self.bounds];
        _videoContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.contentView addSubview:_videoContainer];
        
        _uidLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, self.bounds.size.height - 30, self.bounds.size.width - 20, 20)];
        _uidLabel.textColor = [UIColor whiteColor];
        _uidLabel.font = [UIFont systemFontOfSize:12];
        _uidLabel.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
        [self.contentView addSubview:_uidLabel];
    }
    return self;
}

- (void)configureWithParticipant:(TgoParticipantBridge *)participant {
    self.participantUid = participant.uid;
    self.uidLabel.text = participant.uid;
    // Video rendering would happen here using RTCMTLVideoView or UIHostingController
}

- (void)configureWithUid:(NSString *)uid {
    self.participantUid = uid;
    self.uidLabel.text = uid;
}

@end
