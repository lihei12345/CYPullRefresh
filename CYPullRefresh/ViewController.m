//
//  ViewController.m
//  CYPullRefresh
//
//  Created by jason on 15/5/22.
//  Copyright (c) 2015年 chenyang. All rights reserved.
//

#import "ViewController.h"
#import "UIScrollView+CYPullRefresh.h"
#import "CYPullRefreshSimpleBottomView.h"
#import "CYPullRefreshSimpleTopView.h"

@interface ViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *theTableView;
@property (nonatomic, strong) NSMutableArray *dataArray;
@property (nonatomic, assign) NSInteger startIndex;
@property (nonatomic, assign) NSInteger limitNum;

@end

@implementation ViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.title = @"CYPullRefresh";
    
    _dataArray = [NSMutableArray new];
    _startIndex = 0;
    _limitNum = 10;
    
    CYPullRefreshSimpleBottomView *bottomView = [[CYPullRefreshSimpleBottomView alloc] init];
    CYPullRefreshSimpleTopView *topView = [[CYPullRefreshSimpleTopView alloc] init];
    
    __weak typeof(&*self) weakself = self;
    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
    tableView.backgroundView = nil;
    tableView.delegate = self;
    tableView.dataSource = self;
    [tableView cy_addPullDownHanlder:^{
        [weakself reloadData];
    } topView:topView];
    [tableView cy_addPullUpHandler:^{
        [weakself loadMore];
    } bottomView:bottomView];
    [tableView cy_setPullUpEnable:NO];
    [self.view addSubview:tableView];
    _theTableView = tableView;
    
    [_theTableView cy_triggerLoadWithState:CYLoadStatePullDown];
}

- (void)dealloc
{
    NSLog(@"ViewController dealloc");
    [_theTableView cy_clearPullLoad];
}

#pragma mark - network

- (void)doneReload
{
    [_dataArray removeAllObjects];
    for (NSInteger i = 0; i < _limitNum; i ++) {
        NSString *str = [@(i) stringValue];
        [_dataArray addObject:str];
    }
    _startIndex = [_dataArray count];
    
    [_theTableView reloadData];
    [_theTableView cy_stopLoad];
    [_theTableView cy_setHasMoreData:_dataArray.count >= _limitNum ? YES : NO];
    [_theTableView cy_setPullUpEnable:YES];
}

- (void)reloadData
{
    _startIndex = 0;
    [self performSelector:@selector(doneReload) withObject:nil afterDelay:1.5];
}

- (void)doneLoadMore
{
    NSMutableArray *dataArray = [NSMutableArray new];
    NSInteger next = _limitNum + _startIndex;
    if (_startIndex > 50) {
        next = _startIndex + 1;
    }
    for (NSInteger i = _startIndex; i < next; i ++) {
        NSString *str = [@(i) stringValue];
        [dataArray addObject:str];
    }
    [_dataArray addObjectsFromArray:dataArray];
    _startIndex += [dataArray count];
    
    [_theTableView reloadData];
    [_theTableView cy_stopLoad];
    [_theTableView cy_setHasMoreData:dataArray.count >= _limitNum ? YES : NO];
}

- (void)loadMore
{
    [self performSelector:@selector(doneLoadMore) withObject:nil afterDelay:1.5];
}

#pragma mark - UITableViewDataSource & UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 40.f;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _dataArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
    }
    [cell.textLabel setText:_dataArray[indexPath.row]];
    return cell;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
//    NSLog(@"offset : %@", @(scrollView.contentOffset.y));
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    ViewController *viewController = [[ViewController alloc] init];
    [self.navigationController pushViewController:viewController animated:YES];
}

@end
