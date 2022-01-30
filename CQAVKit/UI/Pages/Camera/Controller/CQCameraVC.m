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
- (void)switchCameraSuccess {
    self.previewView.isFocusEnabled = self.captureManager.isSupportTapFocus;
    self.previewView.isExposeEnabled = self.captureManager.isSupportTapExpose;
    self.captureManager.flashMode = AVCaptureFlashModeAuto;
    self.statusView.flashMode = AVCaptureFlashModeAuto;
}

- (void)switchCameraFailed {
    
}

- (void)deviceConfigurationFailedWithError:(NSError *)error {
    
}

- (void)mediaCaptureFailedWithError:(NSError *)error {
    
}

- (void)mediaCaptureImageSuccess {
    [self.captureManager stopSessionAsync];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.captureManager stopSessionAsync];
    });
}

- (void)mediaCaptureVideoSuccess {
    
}

- (void)assetLibraryWriteFailedWithError:(NSError *)error {
    
}

- (void)assetLibraryWriteImageSuccessWithImage:(UIImage *)image {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.operateView.coverBtn setImage:image forState:UIControlStateNormal];
    });
}

- (void)assetLibraryWriteMovieFileSuccessWithCoverImage:(UIImage *)coverImage {
    
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
        [self.captureManager captureStillImage];
    };
    self.operateView.coverBtnCallbackBlock = ^{
        float deviceVersion = [[[UIDevice currentDevice] systemVersion] floatValue];
        if (deviceVersion < 10) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"PHOTOS://"]];
        }else{
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"photos-redirect://"] options:@{@"jn":@"s"} completionHandler:nil];
        }
    };
}

#pragma mark - CaptureSession
- (void)configCaptureSession {
    NSError *error;
    [self.captureManager configSessionPreset:AVCaptureSessionPreset3840x2160];
    if ([self.captureManager configVideoInput:&error]) {
        [self.captureManager configStillImageOutput];
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
