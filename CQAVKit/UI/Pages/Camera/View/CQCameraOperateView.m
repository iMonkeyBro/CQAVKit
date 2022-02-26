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
@property (nonatomic, strong) UIButton *modeButton;  ///< 模式按键
@property (nonatomic, assign) CQCameraMode cameraMode;  ///< 相机模式
@end

@implementation CQCameraOperateView

- (instancetype)init {
    self = [super init];
    if (self) {
        [self configUI];
        self.cameraMode = CQCameraModePhoto;
    }
    return self;
}

#pragma mark - Event
- (void)shutterBtnAction {
    !self.shutterBtnCallbackBlock ?: self.shutterBtnCallbackBlock();
    if (self.cameraMode == CQCameraModeVideo) {
        self.shutterBtn.selected = !self.shutterBtn.selected;
    }
}

- (void)coverBtnAction {
    !self.coverBtnCallbackBlock ?: self.coverBtnCallbackBlock();
}

- (void)modeBtnAction {
    if (self.cameraMode == CQCameraModePhoto) {
        self.cameraMode = CQCameraModeVideo;
    } else if (self.cameraMode  == CQCameraModeVideo) {
        self.cameraMode = CQCameraModePhoto;
    }
}

- (void)setCameraMode:(CQCameraMode)cameraMode {
    _cameraMode = cameraMode;
    if (cameraMode == CQCameraModePhoto) {
        [self.modeButton setTitle:@"Photo" forState:UIControlStateNormal];
        self.shutterBtn.mode = CQCameraShutterButtonModePhoto;
    } else if (cameraMode == CQCameraModeVideo) {
        [self.modeButton setTitle:@"Video" forState:UIControlStateNormal];
        self.shutterBtn.mode = CQCameraShutterButtonModeVideo;
    }
    !self.changeModeCallbackBlock ?: self.changeModeCallbackBlock(self.cameraMode);
}

#pragma mark - UI
- (void)configUI {
    // 调整self.layer.backgroundColor的透明度会使子视图透明度都改变
    self.layer.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.5f].CGColor;
    [self addSubview:self.shutterBtn];
    [self addSubview:self.coverBtn];
    [self addSubview:self.modeButton];
    [self.shutterBtn makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.centerX.equalTo(self);
        make.size.equalTo(CGSizeMake(68, 68));
    }];
    [self.coverBtn makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(10);
        make.centerY.equalTo(self);
        make.size.equalTo(CGSizeMake(68, 68));
    }];
    [self.modeButton makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(-10);
        make.centerY.equalTo(self);
        make.size.equalTo(CGSizeMake(68, 68));
    }];
}

#pragma mark - Lazy
- (CQCameraShutterButton *)shutterBtn {
    if (!_shutterBtn) {
        _shutterBtn = [CQCameraShutterButton shutterButton];
        [_shutterBtn addTarget:self action:@selector(shutterBtnAction) forControlEvents:UIControlEventTouchUpInside];
    }
    return _shutterBtn;
}

- (UIButton *)coverBtn {
    if (!_coverBtn) {
        _coverBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_coverBtn setImage:[UIImage imageNamed:@"icon_photo"] forState:UIControlStateNormal];
        [_coverBtn addTarget:self action:@selector(coverBtnAction) forControlEvents:UIControlEventTouchUpInside];
    }
    return _coverBtn;
}

- (UIButton *)modeButton {
    if (!_modeButton) {
        _modeButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_modeButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        [_modeButton setTitle:@"photo" forState:UIControlStateNormal];
        [_modeButton addTarget:self action:@selector(modeBtnAction) forControlEvents:UIControlEventTouchUpInside];
    }
    return _modeButton;
}

@end
