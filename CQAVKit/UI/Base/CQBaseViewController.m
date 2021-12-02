//
//  CQBaseViewController.m
//  CQAVKit
//
//  Created by 刘超群 on 2021/10/25.
//

#import "CQBaseViewController.h"

@interface CQBaseViewController ()

@end

@implementation CQBaseViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    self.edgesForExtendedLayout = 0;
}

- (void)dealloc {
    CQLog(@"dealloc --- %@", NSStringFromClass(self.class));
}


@end
