//
//  CQCameraOperationalView.m
//  CQAVKit
//
//  Created by 刘超群 on 2021/11/27.
//

#import "CQCameraOperateView.h"
#import "CQCameraShutterButton.h"

@interface CQCameraOperateView ()
@property (nonatomic, strong) CQCameraShutterButton *shutterBtn;  ///< 快门按钮


@end

@implementation CQCameraOperateView

- (instancetype)init {
    self = [super init];
    if (self) {
        [self configUI];
    }
    return self;
}

#pragma mark - Event
- (void)shutterBtnAction {
    self.shutterBtn.selected = YES;
    !self.shutterBtnCallbackBlock ?: self.shutterBtnCallbackBlock();
    self.shutterBtn.selected = NO;
}

#pragma mark - UI
- (void)configUI {
    // 调整self.layer.backgroundColor的透明度会使子视图透明度都改变
    self.layer.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.5f].CGColor;
    [self addSubview:self.shutterBtn];
    [self.shutterBtn makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.centerX.equalTo(self);
        make.size.equalTo(CGSizeMake(68, 68));
    }];

}

#pragma mark - Lazy
- (UIButton *)shutterBtn {
    if (!_shutterBtn) {
        _shutterBtn = [CQCameraShutterButton shutterButton];
        [_shutterBtn addTarget:self action:@selector(shutterBtnAction) forControlEvents:UIControlEventTouchUpInside];
    }
    return _shutterBtn;
}

@end
