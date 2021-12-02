//
//  CQCameraStatusView.m
//  CQAVKit
//
//  Created by 刘超群 on 2021/11/27.
//

#import "CQCameraStatusView.h"

@interface CQCameraStatusView ()
@property (nonatomic, strong) UIButton *flashBtn;  ///< 闪光灯按钮
@property (nonatomic, strong) UILabel *timeLabel;  ///< 时间label
@property (nonatomic, strong) UIButton *switchCameraBtn;  ///< 切换相机按钮

@end

@implementation CQCameraStatusView

- (instancetype)init {
    self = [super init];
    if (self) {
        [self configUI];
        
    }
    return self;
}

#pragma mark - Event
- (void)flashAction {
    !self.flashBtnCallbackBlock ?: self.flashBtnCallbackBlock();
}

- (void)switchCameraAction {
    !self.switchCameraBtnCallbackBlock ?: self.switchCameraBtnCallbackBlock();
}

#pragma mark - UI
- (void)configUI {
    self.layer.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.5f].CGColor;
    [self addSubview:self.flashBtn];
    [self addSubview:self.switchCameraBtn];
    [self.flashBtn makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self);
        make.left.equalTo(7);
        make.size.equalTo(CGSizeMake(65, 35));
    }];
    [self.switchCameraBtn makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self);
        make.right.equalTo(-7);
        make.size.equalTo(CGSizeMake(35, 35));
    }];
}

#pragma mark - Lazy
- (UIButton *)flashBtn {
    if (!_flashBtn) {
        _flashBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_flashBtn setImage:[UIImage imageNamed:@"icon_flash"] forState:UIControlStateNormal];
        [_flashBtn setTitle:@"AUTO" forState:UIControlStateNormal];
        _flashBtn.titleLabel.font = KFONT_Medium(14);
        [_flashBtn cq_setStyle:CQBtnStyleImgLeft padding:2];
        [_flashBtn addTarget:self action:@selector(flashAction) forControlEvents:UIControlEventTouchUpInside];
    }
    return _flashBtn;
}

- (UIButton *)switchCameraBtn {
    if (!_switchCameraBtn) {
        _switchCameraBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_switchCameraBtn setImage:[UIImage imageNamed:@"icon_switchCamera"] forState:UIControlStateNormal];
        _switchCameraBtn.titleLabel.font = KFONT_Medium(14);
        [_switchCameraBtn addTarget:self action:@selector(switchCameraAction) forControlEvents:UIControlEventTouchUpInside];
    }
    return _switchCameraBtn;
}

@end
