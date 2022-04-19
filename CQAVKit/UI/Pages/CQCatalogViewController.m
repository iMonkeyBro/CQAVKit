//
//  CQCatalogViewController.m
//  CQAVKit
//
//  Created by 刘超群 on 2021/10/25.
//

#import "CQCatalogViewController.h"
#import <CQAVKit-Swift.h>

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
    if ([self.dataList[indexPath.row][@"title"] isEqualToString:@"沙盒目录"]) {
        NSString *path = NSHomeDirectory();
        JXFileBrowserController *fileVC = [[JXFileBrowserController alloc] initWithPath:path];
        [self.navigationController pushViewController:fileVC animated:YES];
        return;
    }
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
        _dataList = @[@{@"title":@"相机捕捉(人脸识别)", @"vc":@"CQCameraVC"},
                      @{@"title":@"VideoToolBox 学习", @"vc":@"CQVTLearningVC"},
                      @{@"title":@"测试视频编解码", @"vc":@"CQTestVideoCoderVC"},
                      @{@"title":@"测试音频编解码", @"vc":@"CQTestAudioCoderVC"},
                      @{@"title":@"Test", @"vc":@"CQTestViewController"},
                      @{@"title":@"Test", @"vc":@"CQTestViewController"},
                      @{@"title":@"沙盒目录", @"vc":@"JXFileBrowserController"},];
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
