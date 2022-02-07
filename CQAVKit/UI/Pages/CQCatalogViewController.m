//
//  CQCatalogViewController.m
//  CQAVKit
//
//  Created by 刘超群 on 2021/10/25.
//

#import "CQCatalogViewController.h"


static NSString *identifier = @"CQCatalogViewControllerCell";

@interface CQCatalogViewController ()<UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *mainTableView;  ///< 页面主列表
@property (nonatomic, strong) NSArray *dataList;  ///< 数据
@end

@implementation CQCatalogViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"CQAVKit";
    [self.view addSubview:self.mainTableView];
}

#pragma mark - UITableViewDelegate, UITableViewDataSource
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    UIViewController *vc = [NSClassFromString(self.dataList[indexPath.row][@"vc"]) new];
    vc.title = self.dataList[indexPath.row][@"title"];
    [self.navigationController pushViewController:vc animated:YES];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    cell.textLabel.text = self.dataList[indexPath.row][@"title"];
    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.dataList.count;
}

#pragma mark - Lazy Load
- (NSArray *)dataList {
    if (!_dataList) {
        _dataList = @[@{@"title":@"相机捕捉", @"vc":@"CQCameraVC"},
                      @{@"title":@"相机高级捕捉", @"vc":@"CQTestCaptureViewController"},
                      @{@"title":@"VideoToolBox 学习", @"vc":@"CQVTLearningVC"},
                      @{@"title":@"视频解码", @"vc":@"CQTestCaptureViewController"},
                      @{@"title":@"视频渲染", @"vc":@"CQTestCaptureViewController"},
                      @{@"title":@"音频编码", @"vc":@"CQTestCaptureViewController"},
                      @{@"title":@"音频解码", @"vc":@"CQTestCaptureViewController"},];
    }
    return _dataList;
}

- (UITableView *)mainTableView {
    if (!_mainTableView) {
        _mainTableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
        _mainTableView.delegate = self;
        _mainTableView.dataSource = self;
        [_mainTableView registerClass:UITableViewCell.class forCellReuseIdentifier:identifier];
    }
    return _mainTableView;
}


@end
