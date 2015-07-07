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
@property (nonatomic, assign) CGFloat topContentInset;
@property (nonatomic, assign) BOOL adjustInstForSectionHeader;

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

#pragma mark - scroll

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
    [self cy_pullDownScrollViewDidScroll];
    [self cy_pullUpScrollViewDidScroll];
}

- (void)cy_scrollViewDidEndDragging
{
    [self cy_pullDownScrollViewDidEndDragging];
    [self cy_pullUpScrollViewDidEndDragging];
}

#pragma mark - pull up

- (void)cy_pullUpScrollViewDidScroll
{
    BOOL isLoading = (self.currentLoadState != CYLoadStateNone);
    CGFloat topInset = _scrollView.contentInset.top;
    CGFloat bottomInset = _scrollView.contentInset.bottom;
    
    if (self.pullUpEnable && _downView.pullState != CYPullStateNoMore && !isLoading) {
        if (_scrollView.dragging && _scrollView.contentSize.height < _scrollView.frame.size.height) {
            CGFloat viewOffset = _scrollView.contentOffset.y + topInset - _downView.contentHeight;
            if (viewOffset >= 0) {
                [_downView setPullState:CYPullStateHitTheEnd];
            } else {
                [_downView setPullState:CYPullStatePulling];
            }
        } else if (_scrollView.contentSize.height >= _scrollView.frame.size.height) {
            CGFloat viewOffset = _scrollView.contentOffset.y + _scrollView.frame.size.height - _scrollView.contentSize.height - (bottomInset - _downView.contentHeight);
            if (viewOffset > 0 && _downView.pullState != CYPullStateLoading) {
                if (viewOffset > _downView.contentHeight) {
                    if (!_scrollView.tracking) {
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
}

- (void)cy_pullUpScrollViewDidEndDragging
{
    BOOL isLoading = (self.currentLoadState != CYLoadStateNone);
    CGFloat topInset = _scrollView.contentInset.top;
    
    if (self.pullUpEnable && _downView.pullState != CYPullStateNoMore && !isLoading) {
        CGFloat viewOffset = _scrollView.contentOffset.y + topInset - _downView.contentHeight;
        if (viewOffset >= 0 && _downView.pullState == CYPullStateHitTheEnd) {
            [_downView setPullState:CYPullStateLoading];
        }
    }
}

#pragma mark - pull down

- (void)cy_pullDownScrollViewDidScroll
{
    BOOL isLoading = (self.currentLoadState != CYLoadStateNone);
    CGFloat topInset = _scrollView.contentInset.top;
    
    if (self.pullDownEnable && !isLoading) {
        CGFloat viewOffset = _scrollView.contentOffset.y;
        if (viewOffset < - _upView.contentHeight - topInset  && _scrollView.dragging) {
            [_upView setPullState:CYPullStateHitTheEnd];
        } else if (viewOffset > - _upView.contentHeight - topInset && viewOffset < 0 && _scrollView.dragging) {
            [_upView setPullState:CYPullStatePulling];
        }
    } else if (isLoading && self.pullDownEnable && self.adjustInstForSectionHeader) {
        // fix problem:
        // http://stackoverflow.com/questions/5466097/section-headers-in-uitableview-when-inset-of-tableview-is-changed
        // http://stackoverflow.com/questions/4365297/issue-scrolling-table-view-with-content-inset
        if (_scrollView.contentOffset.y > - self.upView.contentHeight && _scrollView.contentOffset.y < 0.0) {
            [self updateTopContentInset:MIN(-_scrollView.contentOffset.y, self.upView.contentHeight)];
        } else if (_scrollView.contentOffset.y >= 0.0) {
            [self updateTopContentInset:0];
        }
    }
}

- (void)cy_pullDownScrollViewDidEndDragging
{
    BOOL isLoading = (self.currentLoadState != CYLoadStateNone);
    CGFloat topInset = _scrollView.contentInset.top;
    
    if (self.pullDownEnable && !isLoading) {
        CGFloat viewOffset = _scrollView.contentOffset.y;
        if (viewOffset < - _upView.contentHeight - topInset) {
            [_upView setPullState:CYPullStateLoading];
            [self setTopContentInsetWithLoading:YES];
        } else if (!isLoading) {
            [_upView setPullState:CYPullStateNormal];
        }
    }
}

- (void)updateTopContentInset:(CGFloat)topContentInset
{
    if (fabs(topContentInset - _topContentInset) < 0.01) {
        return;
    }
    
    CGFloat originTopInset = _topContentInset;
    _topContentInset = topContentInset;
    
    UIEdgeInsets insets = _scrollView.contentInset;
    insets = UIEdgeInsetsMake(insets.top - originTopInset + topContentInset, 0, insets.bottom, 0);
    [_scrollView setContentInset:insets];
}

- (void)setTopContentInsetWithLoading:(BOOL)isLoading
{
    if (isLoading) {
        [UIView animateWithDuration:0.2f animations:^(){
            [self updateTopContentInset:self.upView.contentHeight];
        }];
    } else {
        [UIView animateWithDuration:0.4f animations:^{
            [self updateTopContentInset:0];
        }];
    }
}

@end

#pragma mark - UIScrollView+WMPullLoad -

@interface UIScrollView (CYPullRefreshInner)

@property (nonatomic, strong) CYPullRefreshManager *cy_pullRefreshManager;

@end

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
        [self.cy_pullRefreshManager setTopContentInsetWithLoading:NO];
        
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
        [self.cy_pullRefreshManager.upView setPullState:CYPullStateLoading animated:NO];
        self.contentOffset = CGPointMake(0, - self.contentInset.top - self.cy_pullRefreshManager.upView.contentHeight);
        [self.cy_pullRefreshManager setTopContentInsetWithLoading:YES];
    } else if (state == CYLoadStatePullUp && [self.cy_pullRefreshManager pullUpEnable]) {
        [self.cy_pullRefreshManager.downView setPullState:CYPullStateLoading animated:NO];
        self.contentOffset = CGPointMake(0, self.contentInset.bottom + self.contentSize.height);
    }
}

- (CYLoadState)cy_getLoadState
{
    return self.cy_pullRefreshManager.currentLoadState;
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

- (void)cy_setAdjustInsetForSectionHeader:(BOOL)adjust
{
    self.cy_pullRefreshManager.adjustInstForSectionHeader = adjust;
}

- (BOOL)cy_adjustInstForSectionHeader
{
    return self.cy_pullRefreshManager.adjustInstForSectionHeader;
}

@end