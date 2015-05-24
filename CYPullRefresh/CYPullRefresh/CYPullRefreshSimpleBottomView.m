//
//  CYPullRefreshSimpleBottomView.m
//  zuimei
//
//  Created by jason on 15/5/23.
//  Copyright (c) 2015 chenyang. All rights reserved.
//

#import "CYPullRefreshSimpleBottomView.h"

#define BOTTOM_LOADVIEW_HEIGHT 50.f

@implementation CYPullRefreshSimpleBottomView

@synthesize pullState = _pullState;
@synthesize triggerLoadingStateBlock = _triggerLoadingStateBlock;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.backgroundColor = [UIColor clearColor];
        
        _stateLabel = [[UILabel alloc] init];
        _stateLabel.font = [UIFont systemFontOfSize:14];
        _stateLabel.textColor = [UIColor colorWithRed:181.0/255.0 green:181.0/255.0 blue:181.0/255.0 alpha:1.0];
        _stateLabel.textAlignment = NSTextAlignmentCenter;
        _stateLabel.backgroundColor = [UIColor clearColor];
        [self addSubview:_stateLabel];
    }
    return self;
}

- (void)setPullState:(CYPullState)pullState
{
    [self setPullState:pullState animated:YES];
}

- (void)setPullState:(CYPullState)pullstate animated:(BOOL)animated
{
    _pullState = pullstate;
    _stateLabel.frame = CGRectMake(0, 15, self.frame.size.width, 20);
    switch (self.pullState) {
        case CYPullStateHitTheEnd:
            _stateLabel.text = @"松开即可加载更多...";
            break;
        case CYPullStateNormal:
        case CYPullStatePulling:
            _stateLabel.text = @"上拉加载更多...";
            break;
        case CYPullStateLoading:{
            _stateLabel.text = @"努力加载中...";
            if (_triggerLoadingStateBlock) {
                _triggerLoadingStateBlock(self, animated);
            }
            break;
        }
        case CYPullStateNoMore:{
            _stateLabel.text = @"没有更多了...";
            break;
        }
        default:
            break;
    }
}

- (void)setTextColor:(UIColor*)color
{
    _stateLabel.textColor = color;
}

- (CGFloat)contentHeight
{
    return BOTTOM_LOADVIEW_HEIGHT;
}

@end