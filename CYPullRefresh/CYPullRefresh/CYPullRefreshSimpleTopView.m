//
//  CYPullRefreshSimpleTopView.m
//  zuimei
//
//  Created by jason on 15/5/23.
//  Copyright (c) 2015 chenyang. All rights reserved.
//

#import "CYPullRefreshSimpleTopView.h"


#define TOP_LOADVIEW_HEIGHT 60.0f
#define FLIP_ANIMATION_DURATION 0.18f

@interface CYPullRefreshSimpleTopView ()

@property (nonatomic, strong) UIImageView *arrowImage;
@property (nonatomic, strong) UIActivityIndicatorView *activityView;

@end

@implementation CYPullRefreshSimpleTopView

@synthesize pullState = _pullState;
@synthesize triggerLoadingStateBlock = _triggerLoadingStateBlock;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.backgroundColor = [UIColor clearColor];
        
        _stateLabel = [[UILabel alloc] init ];
        _stateLabel.font = [UIFont systemFontOfSize:14.f];
        _stateLabel.textColor = [UIColor colorWithRed:181.0/255.0 green:181.0/255.0 blue:181.0/255.0 alpha:1.0];
        _stateLabel.textAlignment = NSTextAlignmentLeft;
        _stateLabel.backgroundColor = [UIColor clearColor];
        [self addSubview:_stateLabel];
        
        _arrowImage = [[UIImageView alloc] init];
        _arrowImage.image = [UIImage imageNamed:@"cy_pull_refresh_arrow"];
        [self addSubview:_arrowImage];
        
        UIActivityIndicatorView *view = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        view.frame = CGRectMake(25.0f, frame.size.height - 38.0f, 20.0f, 20.0f);
        [self addSubview:view];
        _activityView = view;
        
        [self setPullState:CYPullStateNormal];
    }
    return self;
}

- (void)setPullState:(CYPullState)pullState
{
    [self setPullState:pullState animated:YES];
}

- (void)setPullState:(CYPullState)pullstate animated:(BOOL)animated
{
    _arrowImage.frame = CGRectMake(self.bounds.size.width / 2 - 60, self.bounds.size.height - (self.contentHeight - 22)/2.f - 22, 22, 22);
    _activityView.frame = _arrowImage.frame;
    _stateLabel.frame = CGRectMake(_arrowImage.frame.origin.x + _arrowImage.frame.size.width + 8, self.bounds.size.height - (self.contentHeight - 15)/2.f - 15, self.frame.size.width, 15);
    
    switch (pullstate) {
        case CYPullStateHitTheEnd: {
            _stateLabel.text = @"松开即可更新...";
            [UIView animateWithDuration:FLIP_ANIMATION_DURATION animations:^{
                _arrowImage.layer.transform = CATransform3DMakeRotation((M_PI / 180.0) * 180.0f, 0.0f, 0.0f, 1.0f);
            }];
            break;
        }
        case CYPullStateNormal:
        case CYPullStatePulling: {
            _stateLabel.text = @"下拉刷新...";
            [_activityView stopAnimating];
            [UIView animateWithDuration:FLIP_ANIMATION_DURATION animations:^{
                _arrowImage.hidden = NO;
                _arrowImage.layer.transform = CATransform3DIdentity;
            }];
            break;
        }
        case CYPullStateLoading : {
            _stateLabel.text = @"加载中...";
            [_activityView startAnimating];
            [UIView animateWithDuration:FLIP_ANIMATION_DURATION animations:^{
                _arrowImage.hidden = YES;
            }];
            _triggerLoadingStateBlock(self, animated);
            break;
        }
        default:
            break;
    }
    
    _pullState = pullstate;
}

- (CGFloat)contentHeight
{
    return TOP_LOADVIEW_HEIGHT;
}

@end

