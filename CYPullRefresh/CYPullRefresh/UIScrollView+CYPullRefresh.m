//
//  UIScrollView+CYPullRefresh.m
//  CYPullRefresh
//
//  Created by jason on 15/5/22.
//  Copyright (c) 2015年 chenyang. All rights reserved.
//

#import "UIScrollView+CYPullRefresh.h"
#import <objc/runtime.h>

#pragma mark - CYPullRefreshManager

#define CYPullRefreshManagerContext @"CYPullRefreshManagerContext"

@interface CYPullRefreshManager : NSObject

@property (nonatomic, weak, readonly) UIScrollView *scrollView;
@property (nonatomic, strong) UIView<CYPullRefreshViewProtocol> *upView;
@property (nonatomic, strong) UIView<CYPullRefreshViewProtocol> *downView;
@property (nonatomic, copy) CYPullRefreshBlock pullUpBlock;
@property (nonatomic, copy) CYPullRefreshBlock pullDownBlock;
@property (nonatomic, assign) BOOL hasMoreData;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) BOOL pullUpEnable;
@property (nonatomic, assign) BOOL pullDownEnable;

@end

@implementation CYPullRefreshManager

- (instancetype)initWithScrollView:(UIScrollView *)scrollView
{
    self = [super init];
    if (self) {
        NSAssert(scrollView != nil && [scrollView isKindOfClass:[UIScrollView class]], @"scroll view must not be nil");
        
        _scrollView = scrollView;
        
        [self setupObserver];
    }
    
    return self;
}

- (void)dealloc
{
    NSLog(@"%@ dealloc", NSStringFromClass([self class]));
}

#pragma mark - public

- (void)loadWithState:(LoadState)state
{
    if (state == PullUpLoadState) {
        CYPullRefreshBlock block = [self pullUpBlock];
        if (block) {
            block();
        }
    } else {
        CYPullRefreshBlock block = [self pullDownBlock];
        if (block) {
            block();
        }
    }
}

- (void)setPullUpEnable:(BOOL)pullUpEnable
{
    _pullUpEnable = pullUpEnable;
    _downView.hidden = !pullUpEnable;
}

- (void)setPullDownEnable:(BOOL)pullDownEnable
{
    _pullDownEnable = pullDownEnable;
    _upView.hidden = !pullDownEnable;
}

#pragma mark - observer

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == CYPullRefreshManagerContext) {
        if([keyPath isEqualToString:@"contentOffset"]) {
            [self cy_scrollViewDidScroll];
        } else if([keyPath isEqualToString:@"contentSize"]) {
            [_downView setFrame:CGRectMake(0, _scrollView.contentSize.height, _scrollView.frame.size.width, 300)];
        }
    }
}

- (void)gestureRecognizerUpdate:(UIPanGestureRecognizer *)gesture
{
    if (gesture.state == UIGestureRecognizerStateEnded) {
        [self cy_scrollViewDidEndDragging];
    }
}

#pragma mark - helper

- (void)setupObserver
{
    [_scrollView addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:CYPullRefreshManagerContext];
    [_scrollView addObserver:self forKeyPath:@"contentSize" options:NSKeyValueObservingOptionNew context:CYPullRefreshManagerContext];
    // dragging property is not KVO-compliant: http://stackoverflow.com/questions/14817047/how-to-detect-the-drag-end-event-of-an-uitableview/24358388#24358388
    [_scrollView.panGestureRecognizer addTarget:self action:@selector(gestureRecognizerUpdate:)];
}

- (void)cy_scrollViewDidScroll
{
    BOOL isLoading = self.isLoading;
    CGFloat topInset = _scrollView.contentInset.top;
    
    // 处理上拉
    if (self.pullUpEnable && _downView.pullState != CYPullStateNoMore) {
        if (_scrollView.dragging && _scrollView.contentSize.height < _scrollView.frame.size.height) {
            CGFloat viewOffset = _scrollView.contentOffset.y + topInset - _downView.contentHeight;
            if (viewOffset >= 0) {
                [_downView setPullState:CYPullStateHitTheEnd];
            } else {
                [_downView setPullState:CYPullStatePulling];
            }
        } else if (_scrollView.contentSize.height >= _scrollView.frame.size.height) {
            CGFloat viewOffset = _scrollView.contentOffset.y + _scrollView.frame.size.height - _scrollView.contentInset.bottom - 5 - _scrollView.contentSize.height;
            if (viewOffset > 0 && _downView.pullState != CYPullStateLoading) {
                [_downView setPullState:CYPullStateLoading];
                [self loadWithState:PullUpLoadState];
            }
        }
    }
    
    // 处理下拉
    if (self.pullDownEnable && !isLoading) {
        CGFloat viewOffset = _scrollView.contentOffset.y;
        if (viewOffset < - _upView.contentHeight - topInset  && _scrollView.dragging) {
            [_upView setPullState:CYPullStateHitTheEnd];
        } else if (viewOffset > - _upView.contentHeight - topInset && viewOffset < 0 && _scrollView.dragging) {
            [_upView setPullState:CYPullStatePulling];
        }
    }
}

- (void)cy_scrollViewDidEndDragging
{
    BOOL isLoading = self.isLoading;
    CGFloat topInset = _scrollView.contentInset.top;
    
    // 处理上拉
    if (self.pullUpEnable && _downView.pullState != CYPullStateNoMore) {
        CGFloat viewOffset = _scrollView.contentOffset.y + topInset - _downView.contentHeight;
        if (viewOffset >= 0 && _downView.pullState == CYPullStateHitTheEnd && !isLoading) {
            [_downView setPullState:CYPullStateLoading];
            [self loadWithState:PullUpLoadState];
        }
    }
    
    // 处理下拉
    if (self.pullDownEnable) {
        CGFloat viewOffset = _scrollView.contentOffset.y;
        if (viewOffset < - _upView.contentHeight - topInset && !isLoading) {
            [_upView setPullState:CYPullStateLoading];
            [self loadWithState:PullDownLoadState];
        } else if (!isLoading) {
            [_upView setPullState:CYPullStateNormal];
        }
    }
}

@end

#pragma mark - UIScrollView+WMPullLoad -

static const char *cy_pullRefreshManagerKey = "cy_pullRefreshManagerKey";

@implementation UIScrollView (CYPullRefresh)

#pragma mark - helper

- (void)cy_setPullRefreshManager:(CYPullRefreshManager *)pullRefreshManager
{
    objc_setAssociatedObject(self, &cy_pullRefreshManagerKey, pullRefreshManager, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (CYPullRefreshManager *)cy_pullRefreshManager
{
    CYPullRefreshManager *manager = objc_getAssociatedObject(self, &cy_pullRefreshManagerKey);
    if (!manager) {
        manager = [[CYPullRefreshManager alloc] initWithScrollView:self];
        [self cy_setPullRefreshManager:manager];
    }
    return manager;
}

#pragma mark - public

- (void)cy_addPullDownHanlder:(CYPullRefreshBlock)handler topView:(UIView<CYPullRefreshViewProtocol> *)topView
{
    NSAssert(topView != nil, @"top view must not be nil!");
    if (self.cy_pullRefreshManager.upView) {
        [self.cy_pullRefreshManager.upView removeFromSuperview];
        self.cy_pullRefreshManager.upView = nil;
    }
    
    topView.frame = CGRectMake(0, -300, self.frame.size.width, 300);
    [topView setTriggerLoadingStateBlock:^(UIView<CYPullRefreshViewProtocol> *topView, BOOL animated) {
        [self.cy_pullRefreshManager setIsLoading:YES];
        
        void (^block)() = ^{
            UIEdgeInsets insets = self.contentInset;
            insets = UIEdgeInsetsMake(insets.top + self.cy_pullRefreshManager.upView.contentHeight, 0, insets.bottom, 0);
            [self setContentInset:insets];
        };
        if (animated) {
            [UIView animateWithDuration:0.2f animations:block];
        } else {
            block();
        }
    }];
    self.cy_pullRefreshManager.upView = topView;
    [self addSubview:self.cy_pullRefreshManager.upView];
    
    [self.cy_pullRefreshManager setPullDownBlock:handler];
    [self.cy_pullRefreshManager setPullDownEnable:YES];
}

- (void)cy_addPullUpHandler:(CYPullRefreshBlock)handler bottomView:(UIView <CYPullRefreshViewProtocol> *)bottomView
{
    NSAssert(bottomView != nil, @"bottom view must not be nil!");
    if (self.cy_pullRefreshManager.downView) {
        [self.cy_pullRefreshManager.downView removeFromSuperview];
        self.cy_pullRefreshManager.downView = nil;
    }
    
    [bottomView setTriggerLoadingStateBlock:^(UIView<CYPullRefreshViewProtocol> *bottomView, BOOL animated) {
        [self.cy_pullRefreshManager setIsLoading:YES];
        
        void (^block)() = ^{
            UIEdgeInsets insets = self.contentInset;
            insets = UIEdgeInsetsMake(insets.top, 0, insets.bottom + bottomView.contentHeight, 0);
            [self setContentInset:insets];
        };
        if (animated) {
            [UIView animateWithDuration:0.2f animations:block];
        } else {
            block();
        }
    }];
    self.cy_pullRefreshManager.downView = bottomView;
    [self addSubview:self.cy_pullRefreshManager.downView];
    
    [self.cy_pullRefreshManager setPullUpBlock:handler];
    [self.cy_pullRefreshManager setPullUpEnable:YES];
}

- (BOOL)cy_hasMoreData
{
    return [self.cy_pullRefreshManager hasMoreData];
}

- (void)cy_setHasMoreData:(BOOL)hasMore
{
    [self.cy_pullRefreshManager setHasMoreData:hasMore];
    if (hasMore) {
        [self.cy_pullRefreshManager.downView setPullState:CYPullStateNormal];
    } else {
        [self.cy_pullRefreshManager.downView setPullState:CYPullStateNoMore];
    }
}

- (void)cy_stopLoadWithState:(LoadState)state
{
    [self.cy_pullRefreshManager setIsLoading:NO];
    
    if (state == PullDownLoadState && self.cy_pullRefreshManager.upView.pullState == CYPullStateLoading) {
        [UIView animateWithDuration:0.2 animations:^{
            UIEdgeInsets insets = self.contentInset;
            insets = UIEdgeInsetsMake(insets.top - self.cy_pullRefreshManager.upView.contentHeight, 0, insets.bottom, 0);
            [self setContentInset:insets];
        }];
        [self.cy_pullRefreshManager.upView setPullState:CYPullStateNormal];;
    } else if (state == PullUpLoadState && self.cy_pullRefreshManager.downView.pullState == CYPullStateLoading) {
        [UIView animateWithDuration:0.2 animations:^{
            UIEdgeInsets insets = self.contentInset;
            insets = UIEdgeInsetsMake(insets.top, 0, insets.bottom - self.cy_pullRefreshManager.downView.contentHeight, 0);
            [self setContentInset:insets];
        }];
        [self.cy_pullRefreshManager.downView setPullState:CYPullStateNormal];
    }
}

- (void)cy_triggerLoadWithState:(LoadState)state
{
    if (state == PullDownLoadState && [self.cy_pullRefreshManager pullDownEnable]) {
        [UIView animateWithDuration:0.2 animations:^{
            [self.cy_pullRefreshManager.upView setPullState:CYPullStateLoading animated:NO];
            self.contentOffset = CGPointMake(0, - self.contentInset.top);
        }];
        [self.cy_pullRefreshManager loadWithState:PullDownLoadState];
    } else if (state == PullUpLoadState && [self.cy_pullRefreshManager pullUpEnable]) {
        [UIView animateWithDuration:0.2 animations:^{
            [self.cy_pullRefreshManager.downView setPullState:CYPullStateLoading animated:NO];
            self.contentOffset = CGPointMake(0, self.contentInset.bottom + self.contentSize.height);
        }];
        if (self.cy_pullRefreshManager.downView) {
            [self.cy_pullRefreshManager.downView setFrame:CGRectMake(0, self.contentSize.height, self.frame.size.width, 300)];
        }
    }
}

- (void)cy_setPullUpEnable:(BOOL)enable
{
    self.cy_pullRefreshManager.pullUpEnable = enable;
}

- (BOOL)cy_getPullUpEnable
{
    return self.cy_pullRefreshManager.pullUpEnable;
}

- (void)cy_setPullDownEnable:(BOOL)enable
{
    self.cy_pullRefreshManager.pullDownEnable = enable;
}

- (BOOL)cy_getPullDownEnable
{
    return self.cy_pullRefreshManager.pullDownEnable;
}

@end