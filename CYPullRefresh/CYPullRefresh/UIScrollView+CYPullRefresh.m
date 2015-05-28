//
//  UIScrollView+CYPullRefresh.m
//  CYPullRefresh
//
//  Created by jason on 15/5/22.
//  Copyright (c) 2015 chenyang. All rights reserved.
//

#import "UIScrollView+CYPullRefresh.h"
#import <objc/runtime.h>

#pragma mark - CYPullRefreshManager

#define CYPullRefreshManagerContext @"CYPullRefreshManagerContext"

@interface CYPullRefreshManager : UIView {
    BOOL _isObserving;
}

@property (nonatomic, weak, readonly) UIScrollView *scrollView;
@property (nonatomic, strong) UIView<CYPullRefreshViewProtocol> *upView;
@property (nonatomic, strong) UIView<CYPullRefreshViewProtocol> *downView;
@property (nonatomic, copy) CYPullRefreshBlock pullUpBlock;
@property (nonatomic, copy) CYPullRefreshBlock pullDownBlock;
@property (nonatomic, assign) BOOL hasMoreData;
@property (nonatomic, assign) BOOL pullUpEnable;
@property (nonatomic, assign) BOOL pullDownEnable;
@property (nonatomic, assign) CYLoadState currentLoadState;

@end

@implementation CYPullRefreshManager

- (instancetype)initWithScrollView:(UIScrollView *)scrollView
{
    self = [super init];
    if (self) {
        NSAssert(scrollView != nil && [scrollView isKindOfClass:[UIScrollView class]], @"scroll view must not be nil");
        [scrollView addSubview:self];
        
        _scrollView = scrollView;
        _currentLoadState = CYLoadStateNone;
        
        [self setupObserver];
    }
    
    return self;
}

- (void)dealloc
{
    NSLog(@"%@ dealloc", NSStringFromClass([self class]));
}

#pragma mark - public

- (void)loadWithState:(CYLoadState)state
{
    self.currentLoadState = state;
    if (state == CYLoadStatePullUp) {
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

- (void)willMoveToSuperview:(UIView *)newSuperview
{
    if (newSuperview == nil) {
        [self removeAllObservers];
    }
    
    [super willMoveToSuperview:newSuperview];
}

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
    if (!_isObserving) {
        _isObserving = YES;
        
        [_scrollView addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:CYPullRefreshManagerContext];
        [_scrollView addObserver:self forKeyPath:@"contentSize" options:NSKeyValueObservingOptionNew context:CYPullRefreshManagerContext];
        // dragging property is not KVO-compliant: http://stackoverflow.com/questions/14817047/how-to-detect-the-drag-end-event-of-an-uitableview/24358388#24358388
        [_scrollView.panGestureRecognizer addTarget:self action:@selector(gestureRecognizerUpdate:)];
    }
}

- (void)removeAllObservers
{
    if (_isObserving) {
        // cannot user _scrollView here, becauser it's weak property
        UIScrollView *scrollView = (UIScrollView *)self.superview;
        [scrollView removeObserver:self forKeyPath:@"contentOffset" context:CYPullRefreshManagerContext];
        [scrollView removeObserver:self forKeyPath:@"contentSize" context:CYPullRefreshManagerContext];
        _isObserving = NO;
    }
}

- (void)cy_scrollViewDidScroll
{
    BOOL isLoading = (self.currentLoadState != CYLoadStateNone);
    CGFloat topInset = _scrollView.contentInset.top;
    
    // handle pull up event
    if (self.pullUpEnable && _downView.pullState != CYPullStateNoMore && !isLoading) {
        if (_scrollView.dragging && _scrollView.contentSize.height < _scrollView.frame.size.height) {
            CGFloat viewOffset = _scrollView.contentOffset.y + topInset - _downView.contentHeight;
            if (viewOffset >= 0) {
                [_downView setPullState:CYPullStateHitTheEnd];
            } else {
                [_downView setPullState:CYPullStatePulling];
            }
        } else if (_scrollView.contentSize.height >= _scrollView.frame.size.height) {
            CGFloat viewOffset = _scrollView.contentOffset.y + topInset + _scrollView.frame.size.height - _scrollView.contentSize.height;
            if (viewOffset > 0 && _downView.pullState != CYPullStateLoading) {
                if (viewOffset > _downView.contentHeight) {
                    if (!_scrollView.isDragging) {
                        [_downView setPullState:CYPullStateLoading];
                    } else {
                        [_downView setPullState:CYPullStateHitTheEnd];
                    }
                } else {
                    [_downView setPullState:CYPullStateNormal];
                }
            }
        }
    }
    
    // handle pull down event
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
    BOOL isLoading = (self.currentLoadState != CYLoadStateNone);
    CGFloat topInset = _scrollView.contentInset.top;
    
    // handle pull up event
    if (self.pullUpEnable && _downView.pullState != CYPullStateNoMore && !isLoading) {
        CGFloat viewOffset = _scrollView.contentOffset.y + topInset - _downView.contentHeight;
        if (viewOffset >= 0 && _downView.pullState == CYPullStateHitTheEnd) {
            [_downView setPullState:CYPullStateLoading];
        }
    }
    
    // handle pull down event
    if (self.pullDownEnable && !isLoading) {
        CGFloat viewOffset = _scrollView.contentOffset.y;
        if (viewOffset < - _upView.contentHeight - topInset) {
            [_upView setPullState:CYPullStateLoading];
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

- (CYPullRefreshManager *)cy_getAssociatedPullRefreshManager
{
    return objc_getAssociatedObject(self, &cy_pullRefreshManagerKey);
}

- (void)cy_setPullRefreshManager:(CYPullRefreshManager *)pullRefreshManager
{
    objc_setAssociatedObject(self, &cy_pullRefreshManagerKey, pullRefreshManager, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (CYPullRefreshManager *)cy_pullRefreshManager
{
    CYPullRefreshManager *manager = [self cy_getAssociatedPullRefreshManager];
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
    __weak typeof(&*self) weakself = self;
    [topView setTriggerLoadingStateBlock:^(UIView<CYPullRefreshViewProtocol> *topView, BOOL animated) {
        [weakself.cy_pullRefreshManager loadWithState:CYLoadStatePullDown];
        void (^block)() = ^{
            UIEdgeInsets insets = weakself.contentInset;
            insets = UIEdgeInsetsMake(insets.top + weakself.cy_pullRefreshManager.upView.contentHeight, 0, insets.bottom, 0);
            [weakself setContentInset:insets];
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
    
    __weak typeof(&*self) weakself = self;
    [bottomView setTriggerLoadingStateBlock:^(UIView<CYPullRefreshViewProtocol> *bottomView, BOOL animated) {
        [weakself.cy_pullRefreshManager loadWithState:CYLoadStatePullUp];
    }];
    self.cy_pullRefreshManager.downView = bottomView;
    [self addSubview:self.cy_pullRefreshManager.downView];
    
    [self cy_setPullUpEnable:YES];
    [self.cy_pullRefreshManager setPullUpBlock:handler];
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

- (void)cy_stopLoad
{
    if (self.cy_pullRefreshManager.currentLoadState == CYLoadStatePullDown && self.cy_pullRefreshManager.upView.pullState == CYPullStateLoading) {
        [UIView animateWithDuration:0.2 animations:^{
            UIEdgeInsets insets = self.contentInset;
            insets = UIEdgeInsetsMake(insets.top - self.cy_pullRefreshManager.upView.contentHeight, 0, insets.bottom, 0);
            [self setContentInset:insets];
        }];
        
        [self.cy_pullRefreshManager.upView setPullState:CYPullStateNormal];
        [self.cy_pullRefreshManager setCurrentLoadState:CYLoadStateNone];
    } else if (self.cy_pullRefreshManager.currentLoadState == CYLoadStatePullUp && self.cy_pullRefreshManager.downView.pullState == CYPullStateLoading) {
        if (self.cy_pullRefreshManager.downView.pullState != CYPullStateNoMore) {
            if (self.contentSize.height >= self.frame.size.height) {
                CGFloat y = self.contentSize.height - self.frame.size.height - self.contentInset.top;
                if (y <= self.contentOffset.y) {
                    [self setContentOffset:CGPointMake(0, y) animated:NO];
                }
            }
            if (self.cy_pullRefreshManager.downView.pullState != CYPullStateNoMore) {
                [self.cy_pullRefreshManager.downView setPullState:CYPullStateNormal];
            }
            [self.cy_pullRefreshManager setCurrentLoadState:CYLoadStateNone];
        } else {
            [self.cy_pullRefreshManager setCurrentLoadState:CYLoadStateNone];
        }
    }
}

- (void)cy_triggerLoadWithState:(CYLoadState)state
{
    if (self.cy_pullRefreshManager.currentLoadState != CYLoadStateNone) {
        [self cy_stopLoad];
    }
    
    if (state == CYLoadStatePullDown && [self.cy_pullRefreshManager pullDownEnable]) {
        [UIView animateWithDuration:0.2 animations:^{
            self.contentOffset = CGPointMake(0, - self.contentInset.top);
        }];
        [self.cy_pullRefreshManager.upView setPullState:CYPullStateLoading animated:NO];
    } else if (state == CYLoadStatePullUp && [self.cy_pullRefreshManager pullUpEnable]) {
        [UIView animateWithDuration:0.2 animations:^{
            self.contentOffset = CGPointMake(0, self.contentInset.bottom + self.contentSize.height);
        }];
        [self.cy_pullRefreshManager.downView setPullState:CYPullStateLoading animated:NO];
    }
}

- (void)cy_setPullUpEnable:(BOOL)enable
{
    if (self.cy_pullRefreshManager.pullUpEnable != enable) {
        if (enable) {
            UIEdgeInsets insets = self.contentInset;
            insets = UIEdgeInsetsMake(insets.top, 0, insets.bottom + self.cy_pullRefreshManager.downView.contentHeight, 0);
            [self setContentInset:insets];
        } else {
            UIEdgeInsets insets = self.contentInset;
            insets = UIEdgeInsetsMake(insets.top, 0, insets.bottom - self.cy_pullRefreshManager.downView.contentHeight, 0);
            [self setContentInset:insets];
        }
    }
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