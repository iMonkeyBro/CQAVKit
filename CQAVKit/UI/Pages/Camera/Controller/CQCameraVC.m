//
//  CQCameraVC.m
//  CQAVKit
//
//  Created by 刘超群 on 2021/11/27.
//

#import "CQCameraVC.h"
#import "CQAuthorizationTool.h"
#import "CQCapturePreviewView.h"
#import "CQCaptureManager.h"
#import "CQCameraStatusView.h"
#import "CQCameraOperateView.h"

@interface CQCameraVC ()<CQCapturePreviewViewDelegate, CQCaptureManagerDelegate>
@property (nonatomic, strong) CQCaptureManager *captureManager;  ///< 捕捉管理
@property (nonatomic, strong) CQCapturePreviewView *previewView;  ///< 预览视图
@property (nonatomic, strong) CQCameraStatusView *statusView;  ///< 上方状态视图
@property (nonatomic, strong) CQCameraOperateView *operateView;  ///< 下方操作视图
@property (nonatomic, assign) CQCameraMode cameraMode;  ///< 拍摄模式
@property (nonatomic, strong) dispatch_source_t timer;
@end

@implementation CQCameraVC

- (void)viewDidLoad {
    [super viewDidLoad];
    [CQAuthorizationTool checkCameraAuthorization:^(BOOL isAuthorization) {
        [CQAuthorizationTool checkMicrophoneAuthorization:^(BOOL isAuthorization) {
            if (isAuthorization) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self configUI];
                    [self bindUIEvent];
                    [self configCaptureSession];
                });
            }
        }];
    }];
}

#pragma mark - CQCaptureManagerDelegate
#pragma mark 配置回调
- (void)deviceConfigurationFailedWithError:(NSError *)error {
    
}

#pragma mark 相机操作回调
- (void)switchCameraSuccess {
    // 切换摄像头成功，重新赋值
    self.previewView.isFocusEnabled = self.captureManager.isSupportTapFocus;
    self.previewView.isExposeEnabled = self.captureManager.isSupportTapExpose;
    self.captureManager.flashMode = AVCaptureFlashModeAuto;
    self.statusView.flashMode = AVCaptureFlashModeAuto;
}

- (void)switchCameraFailed {
    
}

#pragma mark 静态图片捕捉
- (void)mediaCaptureImageFailedWithError:(NSError *)error {
    
}

- (void)mediaCaptureImageSuccess {
    [self.captureManager stopSessionAsync];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.captureManager stopSessionAsync];
    });
}

- (void)assetLibraryWriteImageFailedWithError:(NSError *)error {
    
}

- (void)assetLibraryWriteImageSuccessWithImage:(UIImage *)image {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.operateView.coverBtn setImage:image forState:UIControlStateNormal];
    });
}

#pragma mark 视频捕捉
- (void)mediaCaptureMovieFileSuccess {
    
}

- (void)mediaCaptureMovieFileFailedWithError:(NSError *)error {
    
}

- (void)assetLibraryWriteMovieFileFailedWithError:(NSError *)error {
    
}

- (void)assetLibraryWriteMovieFileSuccessWithCoverImage:(UIImage *)coverImage {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.operateView.coverBtn setImage:coverImage forState:UIControlStateNormal];
    });
}

#pragma mark - CQCapturePreviewViewDelegate
- (void)didTapFocusAtPoint:(CGPoint)point {
    [self.captureManager focusAtPoint:point];
}

- (void)didTapExposeAtPoint:(CGPoint)point {
    [self.captureManager exposeAtPoint:point];
}

- (void)didTapResetFocusAndExposure {
    [self.captureManager resetFocusAndExposureModes];
}

#pragma mark - Event
- (void)bindUIEvent {
    @weakify(self);
    self.statusView.flashBtnCallbackBlock = ^{
        @strongify(self);
        if (self.statusView.flashMode < 2) {
            self.captureManager.flashMode++;
            self.statusView.flashMode++;
        } else {
            self.captureManager.flashMode = 0;
            self.statusView.flashMode = 0;
        }
    };
    self.statusView.switchCameraBtnCallbackBlock = ^{
        @strongify(self);
        [self.captureManager switchCamera];
    };
    self.operateView.shutterBtnCallbackBlock = ^{
        @strongify(self);
        if (self.cameraMode == CQCameraModePhoto) {
            [self.captureManager captureStillImage];
        } else if (self.cameraMode == CQCameraModeVideo) {
            if (![self.captureManager isRecordingMovieFile]) {
                [self.captureManager startRecordingMovieFile];
                [self startListeningRecording];
            } else {
                [self.captureManager stopRecordingMovieFile];
                [self stopListeningRecording];
            }
            
        }
    };
    self.operateView.coverBtnCallbackBlock = ^{
        float deviceVersion = [[[UIDevice currentDevice] systemVersion] floatValue];
        if (deviceVersion < 10) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"PHOTOS://"]];
        }else{
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"photos-redirect://"] options:@{@"jn":@"s"} completionHandler:nil];
        }
    };
    self.operateView.changeModeCallbackBlock = ^(CQCameraMode cameraMode) {
        @strongify(self);
        self.cameraMode = cameraMode;
        self.statusView.timeLabel.hidden = self.cameraMode == CQCameraModePhoto;
        if (self.cameraMode == CQCameraModeVideo) {
            [self.captureManager configVideoFps:60];
        }
    };
}

- (void)startListeningRecording {
    self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(self.timer, DISPATCH_TIME_NOW, 0.25 * NSEC_PER_SEC, 1 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(self.timer, ^{
        self.statusView.time = [self.captureManager movieFileRecordedDuration];
    });
    dispatch_resume(self.timer);
}

- (void)stopListeningRecording {
    if (self.timer) {
        dispatch_source_cancel(self.timer);
        self.statusView.time = kCMTimeZero;
    }
}

#pragma mark - CaptureSession
- (void)configCaptureSession {
    NSError *error;
    [self.captureManager configSessionPreset:AVCaptureSessionPreset1920x1080];
    if ([self.captureManager configVideoInput:&error]) {
        [self.captureManager configStillImageOutput];
        [self.captureManager configMovieFileOutput];
        self.previewView.session = self.captureManager.captureSession;
        [self.captureManager startSessionAsync];
    } else {
        CQLog(@"Error: %@", [error localizedDescription]);
    }
    self.previewView.isFocusEnabled = self.captureManager.isSupportTapFocus;
    self.previewView.isExposeEnabled = self.captureManager.isSupportTapExpose;
    self.captureManager.flashMode = AVCaptureFlashModeAuto;
    self.statusView.flashMode = AVCaptureFlashModeAuto;
}

#pragma mark - UI
- (void)configUI {
    [self.view addSubview:self.previewView];
    [self.view addSubview:self.statusView];
    [self.view addSubview:self.operateView];
    [self.previewView makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.right.bottom.equalTo(0);
    }];
    [self.statusView makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.right.equalTo(0);
        make.height.equalTo(45);
    }];
    [self.operateView makeConstraints:^(MASConstraintMaker *make) {
        make.bottom.left.right.equalTo(0);
        make.height.equalTo(85+[CQScreenTool safeAreaBottom]);
    }];
}

#pragma mark - Lazy Load
- (CQCaptureManager *)captureManager {
    if (!_captureManager) {
        _captureManager = CQCaptureManager.new;
        _captureManager.delegate = self;
    }
    return _captureManager;
}

- (CQCapturePreviewView *)previewView {
    if (!_previewView) {
        _previewView = [[CQCapturePreviewView alloc] initWithFrame:self.view.bounds];
        _previewView.delegate = self;
    }
    return _previewView;
}

- (CQCameraStatusView *)statusView {
    if (!_statusView) {
        _statusView = CQCameraStatusView.new;
    }
    return _statusView;
}

- (CQCameraOperateView *)operateView {
    if (!_operateView) {
        _operateView = CQCameraOperateView.new;
    }
    return _operateView;
}

@end
