//
//  AppDelegate+Init.m
//  CQAVKit
//
//  Created by 刘超群 on 2021/10/25.
//

#import "AppDelegate+Init.h"
#import "CQNavigationController.h"

@implementation AppDelegate (Init)

/// 初始化rootVC
- (void)initRootVC {
    [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleLightContent;//状态栏
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    if (@available(iOS 13.0, *)) {
        self.window.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;//锁定白天
    }
    self.window.backgroundColor = UIColor.whiteColor;
    UIViewController *vc = [[NSClassFromString(@"CQCatalogViewController") alloc] init];
    self.window.rootViewController = [[CQNavigationController alloc] initWithRootViewController:vc];
    [self.window makeKeyAndVisible];
}

@end
