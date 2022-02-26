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

#pragma mark - Set
- (void)setFlashMode:(NSInteger)flashMode {
    _flashMode = flashMode;
    if (flashMode == 0 ) {
        [self.flashBtn setTitle:@"OFF" forState:UIControlStateNormal];
    } else if (flashMode == 1 ) {
        [self.flashBtn setTitle:@"ON" forState:UIControlStateNormal];
    } else if (flashMode == 2 ) {
        [self.flashBtn setTitle:@"AUTO" forState:UIControlStateNormal];
    }
}

- (void)setTime:(CMTime)time {
    _time = time;
    int seconds = floor(CMTimeGetSeconds(time));
    if (seconds < 10) {
        self.timeLabel.text = [NSString stringWithFormat:@"00:0%d",seconds];
    } else if (seconds < 60) {
        self.timeLabel.text = [NSString stringWithFormat:@"00:%d",seconds];
    } else {
        int currentMin = ceilf(seconds / 60);
        int currentSec = seconds - currentMin * 60;
        
        NSString *minStr;
        if (currentMin < 10) {
            minStr = [NSString stringWithFormat:@"0%d",currentMin];
        } else {
            minStr = [NSString stringWithFormat:@"%d",currentMin];
        }
        NSString *secStr;
        if (currentSec < 10) {
            secStr = [NSString stringWithFormat:@"0%d",currentSec];
        } else {
            secStr = [NSString stringWithFormat:@"%d",currentSec];
        }
        self.timeLabel.text = [NSString stringWithFormat:@"%@:%@",minStr,secStr];
    }
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
    [self addSubview:self.timeLabel];
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
    [self.timeLabel makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.centerY.equalTo(self);
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

- (UILabel *)timeLabel {
    if (!_timeLabel) {
        _timeLabel = [[UILabel alloc] init];
        _timeLabel.textColor = UIColor.whiteColor;
    }
    return _timeLabel;
}

@end
