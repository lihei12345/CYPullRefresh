//
//  UIScrollView+CYPullRefresh.h
//  CYPullRefresh
//
//  Created by jason on 15/5/22.
//  Copyright (c) 2015 chenyang. All rights reserved.
//

#import <UIKit/UIKit.h>

#pragma mark - CYPullRefreshViewProtocol -

typedef NS_ENUM (NSUInteger, CYPullState) {
    CYPullStateNormal,
    CYPullStatePulling,
    CYPullStateHitTheEnd,
    CYPullStateLoading,
    CYPullStateNoMore
};


@protocol CYPullRefreshViewProtocol <NSObject>

@required
@property (nonatomic, assign) CYPullState pullState;
@property (nonatomic, copy) void (^triggerLoadingStateBlock)(UIView<CYPullRefreshViewProtocol> *view, BOOL animated);

- (void)setPullState:(CYPullState)pullstate animated:(BOOL)animated;
- (CGFloat)contentHeight;

@end

#pragma mark - UIScrollView+CYPullRefresh -

typedef NS_ENUM(NSUInteger, CYLoadState) {
    CYLoadStateNone,
    CYLoadStatePullUp,
    CYLoadStatePullDown,
};

typedef void (^CYPullRefreshBlock)();

@interface UIScrollView (CYPullRefresh)

- (void)cy_addPullDownHanlder:(CYPullRefreshBlock)handler topView:(UIView<CYPullRefreshViewProtocol> *)topView;
- (void)cy_addPullUpHandler:(CYPullRefreshBlock)handler bottomView:(UIView<CYPullRefreshViewProtocol> *)bottomView;

- (void)cy_stopLoad;
- (void)cy_triggerLoadWithState:(CYLoadState)state;
- (CYLoadState)cy_getLoadState;

- (void)cy_setHasMoreData:(BOOL)hasMore;
- (BOOL)cy_hasMoreData;

- (void)cy_setPullUpEnable:(BOOL)enable;
- (BOOL)cy_getPullUpEnable;

- (void)cy_setPullDownEnable:(BOOL)enable;
- (BOOL)cy_getPullDownEnable;

- (void)cy_setAdjustInsetForSectionHeader:(BOOL)adjust;
- (BOOL)cy_adjustInstForSectionHeader;

@end