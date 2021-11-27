//
//  CQCameraVC.m
//  CQAVKit
//
//  Created by 刘超群 on 2021/11/27.
//

#import "CQCameraVC.h"
#import "CQCapturePreviewView.h"
#import "CQCaptureManager.h"

@interface CQCameraVC ()<CQCapturePreviewViewDelegate, CQCaptureManagerDelegate>
@property (nonatomic, strong) CQCaptureManager *captureManager;  ///< 捕捉管理
@property (nonatomic, strong) CQCapturePreviewView *previewView;  ///< 预览视图
@end

@implementation CQCameraVC

- (void)viewDidLoad {
    [super viewDidLoad];
    [self configUI];
    [self configCaptureSession];
}

#pragma mark - CQCaptureManagerDelegate
- (void)deviceConfigurationFailedWithError:(NSError *)error {
    
}

- (void)mediaCaptureFailedWithError:(NSError *)error {
    
}

- (void)assetLibraryWriteFailedWithError:(NSError *)error {
    
}

- (void)writeImageSuccessWithImage:(UIImage *)image {
    
}

- (void)writeVideoSuccessWithCoverImage:(UIImage *)coverImage {
    
}

#pragma mark - CQCapturePreviewViewDelegate
- (void)didTapFocusAtPoint:(CGPoint)point {
    
}

- (void)didTapExposeAtPoint:(CGPoint)point {
    
}

- (void)didTapResetFocusAndExposure {
    
}

#pragma mark - CaptureSession
- (void)configCaptureSession {
    NSError *error;
    if ([self.captureManager setupSession:&error]) {
        self.previewView.session = self.captureManager.captureSession;
        [self.captureManager startSession];
    } else {
        CQLog(@"Error: %@", [error localizedDescription]);
    }
}

#pragma mark - UI
- (void)configUI {
    [self.view addSubview:self.previewView];
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

@end
