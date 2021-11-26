//
//  CQCaptureManager.m
//  CQAVKit
//
//  Created by 刘超群 on 2021/10/29.
//

#import "CQCaptureManager.h"
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "NSFileManager+CQ.h"

static const NSString *CameraAdjustingExposureContext;

@interface CQCaptureManager ()<AVCaptureFileOutputRecordingDelegate>
@property (nonatomic, strong) dispatch_queue_t videoQueue; ///< 视频队列
@property (nonatomic, strong) AVCaptureSession *captureSession; ///< 捕捉会话
/// captureSession下活跃的视频输入,一个捕捉会话下会有很多，设置个成员变量方便拿
@property (nonatomic, strong) AVCaptureDeviceInput *videoDeviceInput;
@property (nonatomic, strong) AVCaptureStillImageOutput *imageOutput;  ///< 图片输出
@property (nonatomic, strong) AVCaptureMovieFileOutput *movieOutput;  ///< 电影输出
@property (nonatomic, strong) NSURL *outputURL;  ///< 输出URL
@end

@implementation CQCaptureManager

#pragma mark - Getter
- (NSUInteger)cameraCount {
    return [[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] count];
}

- (BOOL)isHasFlash {
    return [[self getActiveCamera] hasFlash];
}

- (BOOL)isHasTorch {
    return [[self getActiveCamera] hasTorch];
}

- (BOOL)isSupportTapFocus {
    return [self getActiveCamera].isFocusPointOfInterestSupported;
}

- (BOOL)isSupportTapExpose {
    return [self getActiveCamera].isExposurePointOfInterestSupported;
}

- (AVCaptureFlashMode)flashMode {
    return [[self getActiveCamera] flashMode];
}

- (AVCaptureTorchMode)torchMode {
    return [[self getActiveCamera] torchMode];
}

#pragma mark - Setter
- (void)setFlashMode:(AVCaptureFlashMode)flashMode {
    AVCaptureDevice *device = [self getActiveCamera];
    if (![device isFlashModeSupported:flashMode]) return;
    NSError *error;
    if ([device lockForConfiguration:&error]) {
        device.flashMode = flashMode;
        [device unlockForConfiguration];
    } else {
        if (self.delegate && [self.delegate respondsToSelector:@selector(deviceConfigurationFailedWithError:)]) {
            [self.delegate deviceConfigurationFailedWithError:error];
        }
    }
}

- (void)setTorchMode:(AVCaptureTorchMode)torchMode {
    AVCaptureDevice *device = [self getActiveCamera];
    if (![device isTorchModeSupported:torchMode]) return;
    NSError *error;
    if ([device lockForConfiguration:&error]) {
        device.torchMode = torchMode;
        [device unlockForConfiguration];
    } else {
        if (self.delegate && [self.delegate respondsToSelector:@selector(deviceConfigurationFailedWithError:)]) {
            [self.delegate deviceConfigurationFailedWithError:error];
        }
    }
}

#pragma mark - Public Func 设置会话
// 设置会话，设置分辨率，并将输入输出添加到会话中
- (BOOL)setupSession:(NSError * _Nullable *)error {
    // 创建捕捉会话 AVCaptureSession 是捕捉场景的中心枢纽
    self.captureSession = [[AVCaptureSession alloc] init];
    
    /*
     AVCaptureSessionPresetHigh
     AVCaptureSessionPresetMedium
     AVCaptureSessionPresetLow
     AVCaptureSessionPreset640x480
     AVCaptureSessionPreset1280x720
     AVCaptureSessionPresetPhoto
     */
    // 设置图像分辨率
    self.captureSession.sessionPreset = AVCaptureSessionPresetHigh;
    
    // 设置视频音频输入
    // 添加视频捕捉设备
    // 拿到默认视频捕捉设备 iOS默认后置摄像头
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    // 将捕捉设备转化为AVCaptureDeviceInput
    // 注意：会话不能直接使用AVCaptureDevice，必须将AVCaptureDevice封装成AVCaptureDeviceInput对象
    AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:error];
    // 将捕捉设备添加给会话
    // 使用前判断videoInput是否有效以及能否添加，因为摄像头是一个公共设备，不属于任何App，有可能别的App在使用，添加前应该先进行判断是否可以添加
    if (videoInput && [self.captureSession canAddInput:videoInput]) {
        // 将videoInput 添加到 captureSession中
        [self.captureSession addInput:videoInput];
        self.videoDeviceInput = videoInput;
    }else {
        return NO;
    }
    
    // 添加音频捕捉设备
    // 选择默认音频捕捉设备 即返回一个内置麦克风
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    AVCaptureDeviceInput *audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:error];
    if (audioInput && [self.captureSession canAddInput:audioInput]) {
        [self.captureSession addInput:audioInput];
    }else {
        return NO;
    }

    // 设置输出(图片/视频)
    // AVCaptureStillImageOutput 从摄像头捕捉静态图片
    self.imageOutput = [[AVCaptureStillImageOutput alloc] init];
    // 配置字典：希望捕捉到JPEG格式的图片
    self.imageOutput.outputSettings = @{AVVideoCodecKey:AVVideoCodecJPEG};
    // 输出连接 判断是否可用，可用则添加到输出连接中去
    if ([self.captureSession canAddOutput:self.imageOutput]) {
        [self.captureSession addOutput:self.imageOutput];
    }
    // AVCaptureMovieFileOutput，将QuickTime视频录制到文件系统
    self.movieOutput = [[AVCaptureMovieFileOutput alloc] init];
    if ([self.captureSession canAddOutput:self.movieOutput]) {
        [self.captureSession addOutput:self.movieOutput];
    }
    
    return YES;
}

// 开始会话
- (void)startSession {
    // 检查是否处于运行状态
    if (![self.captureSession isRunning]) {
        // 使用同步调用会损耗一定的时间，则用异步的方式处理
        dispatch_async(self.videoQueue, ^{
            [self.captureSession startRunning];
        });
    }
}

// 停止会话
- (void)stopSession {
    // 检查是否处于运行状态
    if ([self.captureSession isRunning]) {
        dispatch_async(self.videoQueue, ^{
            [self.captureSession stopRunning];
        });
    }
}

#pragma mark - Public Func 镜头切换
/// 根据position拿到摄像头
- (AVCaptureDevice *)getCameraWithPosition:(AVCaptureDevicePosition)position {
    NSArray<AVCaptureDevice *> *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if (device.position == position) {
            return device;
        }
    }
    return nil;
}

/// 获取当前活跃的摄像头
- (AVCaptureDevice *)getActiveCamera {
    return self.videoDeviceInput.device;
}

/// 获取未激活的摄像头
- (AVCaptureDevice *)getInactiveCamera {
    // 通过查找当前激活摄像头的反向摄像头获得，如果设备只有1个摄像头，则返回nil
    AVCaptureDevice *device = nil;
    if (self.cameraCount > 1) {
        if ([self getActiveCamera].position == AVCaptureDevicePositionBack) {
            device = [self getCameraWithPosition:AVCaptureDevicePositionFront];
        } else {
            device = [self getCameraWithPosition:AVCaptureDevicePositionBack];
        }
    }
    return device; 
}

// 切换摄像头
- (BOOL)switchCamera {
    if (![self canSwitchCamera]) return NO;
    
    // 获取当前设备的反向设备
    AVCaptureDevice *inactiveCamera = [self getInactiveCamera];
    // 将输入设备封装成AVCaptureDeviceInput
    NSError *error;
    AVCaptureDeviceInput *newVideoInput = [AVCaptureDeviceInput deviceInputWithDevice:inactiveCamera error:&error];
    
    if (newVideoInput != nil) {
        // 开始配置 标注原始配置要发生改变
        [self.captureSession beginConfiguration];
        // TODO: 是不是移除了才能加新的？
        // FIXME: 是不是移除了才能加新的？
        // 将捕捉会话中，原本的捕捉输入设备移除
        [self.captureSession removeInput:self.videoDeviceInput];
        if ([self.captureSession canAddInput:newVideoInput]) {
            [self.captureSession addInput:newVideoInput];
            self.videoDeviceInput = newVideoInput;
        } else {
            // !!!: 是不是要给个回调？
            // ???: 是不是要给个回调？
            // 已经移除了，还是无法添加新设备，则将原本的视频捕捉设备重新加入到捕捉会话中
            [self.captureSession addInput:self.videoDeviceInput];
        }
        // 提交配置，AVCaptureSession commitConfiguration 会分批的将所有变更整合在一起。
        [self.captureSession commitConfiguration];
        return YES;
    } else {
        // 创建AVCaptureDeviceInput 出现错误，回调该错误
        if (self.delegate && [self.delegate respondsToSelector:@selector(deviceConfigurationFailedWithError:)]) {
            [self.delegate deviceConfigurationFailedWithError:error];
        }
        return NO;
    }
}

// 是否能切换摄像头
- (BOOL)canSwitchCamera {
    return self.cameraCount > 1;
}


#pragma mark - Public Func 对焦&曝光

/**
 AVCaptureDevice定义了很多方法，让开发者控制ios设备上的摄像头。可以独立调整和锁定摄像头的焦距、曝光、白平衡。对焦和曝光可以基于特定的兴趣点进行设置，使其在应用中实现点击对焦、点击曝光的功能。
 还可以让你控制设备的LED作为拍照的闪光灯或手电筒的使用。
 每当修改摄像头设备时，一定要先测试修改动作是否能被设备支持。并不是所有的摄像头都支持所有功能，例如部分设备前置摄像头就不支持对焦操作，因为它和目标距离一般在一臂之长的距离。但大部分后置摄像头是可以支持全尺寸对焦。尝试应用一个不被支持的动作，会导致异常崩溃。所以修改摄像头设备前，需要判断是否支持
 */

- (BOOL)isSupportsExposeWithCamera:(AVCaptureDevice *)camera {
    // 摄像头是否支持兴趣点曝光
    return camera.isExposurePointOfInterestSupported;
}

// 设置对焦点
- (void)focusAtPoint:(CGPoint)point {
    AVCaptureDevice *device = [self getActiveCamera];
    // 摄像头是否支持兴趣点对焦 & 是否支持自动对焦模式 ,不支持不操作，玩手动对焦的需求另说
    if (!device.isFocusPointOfInterestSupported || ![device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) return;
    NSError *error;
    // 锁定设备准备配置
    if ([device lockForConfiguration:&error]) {
        // 设置对焦点
        device.focusPointOfInterest = point;
        // 对焦模式设置为自动对焦
        device.focusMode = AVCaptureFocusModeAutoFocus;
        // 释放锁定
        [device unlockForConfiguration];
    } else {
        // 锁定错误时，回调错误处理代理
        if (self.delegate && [self.delegate respondsToSelector:@selector(deviceConfigurationFailedWithError:)]) {
            [self.delegate deviceConfigurationFailedWithError:error];
        }
    }
}


// 设置曝光点
- (void)exposeAtPoint:(CGPoint)point {
    AVCaptureDevice *device = [self getActiveCamera];
    // 摄像头是否支持兴趣点曝光 & 是否支持自动曝光模式 ,不支持不操作，玩手动曝光的需求另说
    if (!device.isExposurePointOfInterestSupported || ![device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) return;
    NSError *error;
    // 锁定设备准备配置
    if ([device lockForConfiguration:&error]) {
        // 设置曝光点
        device.exposurePointOfInterest = point;
        // 曝光模式设置为自动曝光
        device.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
        //判断设备是否支持锁定曝光的模式。
        if ([device isExposureModeSupported:AVCaptureExposureModeLocked]) {
            // 支持，则使用kvo确定设备的adjustingExposure属性的状态。
            [device addObserver:self forKeyPath:@"adjustingExposure" options:NSKeyValueObservingOptionNew context:&CameraAdjustingExposureContext];
        }
        // 释放锁定
        [device unlockForConfiguration];
    } else {
        // 锁定错误时，回调错误处理代理
        if (self.delegate && [self.delegate respondsToSelector:@selector(deviceConfigurationFailedWithError:)]) {
            [self.delegate deviceConfigurationFailedWithError:error];
        }
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (context == &CameraAdjustingExposureContext) {
        //获取device
        AVCaptureDevice *device = (AVCaptureDevice *)object;
        // 设备不再调整曝光等级，说明自动调节曝光结束，并且支持设置为AVCaptureExposureModeLocked
        if(!device.isAdjustingExposure && [device isExposureModeSupported:AVCaptureExposureModeLocked]) {
            // 使用一次监听，立即移除通知
            [object removeObserver:self forKeyPath:@"adjustingExposure" context:&CameraAdjustingExposureContext];
            dispatch_async(dispatch_get_main_queue(), ^{
                NSError *error;
                if ([device lockForConfiguration:&error]) {
                    // 锁定曝光
                    device.exposureMode = AVCaptureExposureModeLocked;
                    [device unlockForConfiguration];
                } else {
                    if (self.delegate && [self.delegate respondsToSelector:@selector(deviceConfigurationFailedWithError:)]) {
                        [self.delegate deviceConfigurationFailedWithError:error];
                    }
                }
            });
        }
    }
}

// 重置对焦和曝光
- (void)resetFocusAndExposureModes {
    AVCaptureDevice *device = [self getActiveCamera];
    // 摄像头是否支持兴趣点对焦 & 是否支持自动对焦模式 ,不支持不操作，玩手动对焦的需求另说
    BOOL canResetFocus = device.isFocusPointOfInterestSupported && [device isFocusModeSupported:AVCaptureFocusModeAutoFocus];
    // 摄像头是否支持兴趣点曝光 & 是否支持自动曝光模式 ,不支持不操作，玩手动曝光的需求另说
    BOOL canResetExposure = device.isExposurePointOfInterestSupported && [device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure];
    // 捕捉设备空间左上角（0，0），右下角（1，1） 中心点则（0.5，0.5）
    CGPoint centerPoint = CGPointMake(0.5f, 0.5f);
    NSError *error;
    //锁定设备，准备配置
    if ([device lockForConfiguration:&error]) {
        // 将对焦点和曝光点设为中心，并将对焦和曝光模式设为自动
        if (canResetFocus) {
            device.focusMode = AVCaptureFocusModeContinuousAutoFocus;
            device.focusPointOfInterest = centerPoint;
        }
        if (canResetExposure) {
            device.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
            device.exposurePointOfInterest = centerPoint;
        }
        //释放锁定
        [device unlockForConfiguration];
    } else {
        if (self.delegate && [self.delegate respondsToSelector:@selector(deviceConfigurationFailedWithError:)]) {
            [self.delegate deviceConfigurationFailedWithError:error];
        }
    }
}

#pragma mark - Public Func 图片捕捉
// 捕捉静态图片
- (void)captureStillImage {
    // 获取图片输出连接
    AVCaptureConnection *connection = [self.imageOutput connectionWithMediaType:AVMediaTypeVideo];
    // 即使程序只支持纵向，但是如果用户横向拍照时，需要调整结果照片的方向
    // 判断是否支持设置视频方向， 支持则根据设备方向设置输出方向值
    if (connection.isVideoOrientationSupported) {
        connection.videoOrientation = [self getCurrentVideoOrientation];
    }
    [self.imageOutput captureStillImageAsynchronouslyFromConnection:connection completionHandler:^(CMSampleBufferRef  _Nullable imageDataSampleBuffer, NSError * _Nullable error) {
        if (imageDataSampleBuffer != NULL) {
            // CMSampleBufferRef转UIImage 并写入相册
            NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
            UIImage *image = [[UIImage alloc] initWithData:imageData];
            [self writeImageToAssetsLibrary:image];
        } else {
            if (self.delegate && [self.delegate respondsToSelector:@selector(mediaCaptureFailedWithError:)]) {
                [self.delegate mediaCaptureFailedWithError:error];
            }
            NSLog(@"NULL sampleBuffer:%@",[error localizedDescription]);
        }
    }];
}

#pragma mark - Private Func 图片捕捉
/// 根据设备方向获取图像方向
- (AVCaptureVideoOrientation)getCurrentVideoOrientation {
    AVCaptureVideoOrientation orientation ;
    switch ([UIDevice currentDevice].orientation) {
        case UIDeviceOrientationPortrait:
            orientation = AVCaptureVideoOrientationPortrait;
            break;
        case UIDeviceOrientationLandscapeRight:
            orientation = AVCaptureVideoOrientationLandscapeLeft;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            orientation = AVCaptureVideoOrientationPortraitUpsideDown;
            break;
        default:
            orientation = AVCaptureVideoOrientationLandscapeRight;
            break;
    }
    return orientation;
}

/**
 Assets Library 框架
 用来让开发者通过代码方式访问iOS photo
 注意：会访问到相册，需要修改plist 权限。否则会导致项目崩溃
 */

/// 将UIImage写入到用户相册
- (void)writeImageToAssetsLibrary:(UIImage *)image {
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    [library writeImageToSavedPhotosAlbum:image.CGImage orientation:(NSUInteger)image.imageOrientation completionBlock:^(NSURL *assetURL, NSError *error) {
        if (!error) {
            // 写入成功，回调
            if (self.delegate && [self.delegate respondsToSelector:@selector(writeImageSuccessWithImage:)]) {
                [self.delegate writeImageSuccessWithImage:image];
            }
        } else {
            if (self.delegate && [self.delegate respondsToSelector:@selector(assetLibraryWriteFailedWithError:)]) {
                [self.delegate assetLibraryWriteFailedWithError:error];
            }
        }
    }];
}

#pragma mark - Public Func 视频捕捉
// 开始录制视频
- (void)startRecordingVideo {
    if ([self isRecordingVideo]) return;
    AVCaptureConnection *videoConnection = [self.movieOutput connectionWithMediaType:AVMediaTypeVideo];
    // 即使程序只支持纵向，但是如果用户横向拍照时，需要调整结果照片的方向
    // 判断是否支持设置视频方向， 支持则根据设备方向设置输出方向值
    if (videoConnection.isVideoOrientationSupported) {
        videoConnection.videoOrientation = [self getCurrentVideoOrientation];
    }
    // 判断是否支持视频稳定 可以显著提高视频的质量。只会在录制视频文件涉及
    if (videoConnection.isVideoStabilizationSupported) {
        videoConnection.enablesVideoStabilizationWhenAvailable = YES;
    }
    AVCaptureDevice *device = [self getActiveCamera];
    // 摄像头可以进行平滑对焦模式操作。即减慢摄像头镜头对焦速度。当用户移动拍摄时摄像头会尝试快速自动对焦。
    if (device.isSmoothAutoFocusEnabled) {
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            device.smoothAutoFocusEnabled = YES;
            [device unlockForConfiguration];
        } else {
            if (self.delegate && [self.delegate respondsToSelector:@selector(deviceConfigurationFailedWithError:)]) {
                [self.delegate deviceConfigurationFailedWithError:error];
            }
        }
    }
    self.outputURL = [self getTempPathURL];
    // 开始录制 参数1:录制保存路径  参数2:代理
    [self.movieOutput startRecordingToOutputFileURL:self.outputURL recordingDelegate:self];
}

// 停止录制视频
- (void)stopRecordingVideo {
    if ([self isRecordingVideo]) {
        [self.movieOutput stopRecording];
    }
}

// 是否在录制视频
- (BOOL)isRecordingVideo {
    return self.movieOutput.isRecording;
}

// 录制视频的时间
- (CMTime)recordedDuration {
    return self.movieOutput.recordedDuration;
}

#pragma mark - Private Func 视频捕捉
// 临时路径URL
- (NSURL *)getTempPathURL {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *tempPath = [fileManager temporaryDirectoryWithTemplateString:@"video.XXXXXXXXXX"];
    if (tempPath) {
        NSString *filePath = [tempPath stringByAppendingPathComponent:@"temp_video.mov"];
        return [NSURL URLWithString:filePath];
    }
    return nil;
}

/// 将视频写入到用户相册
- (void)writeVideoToAssetsLibrary:(NSURL *)videoURL {
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    // 和图片不同，视频的写入更耗时，所以写入之前应该判断是否能写入
    if (![library videoAtPathIsCompatibleWithSavedPhotosAlbum:videoURL]) return;
    [library writeVideoAtPathToSavedPhotosAlbum:videoURL completionBlock:^(NSURL *assetURL, NSError *error) {
        if (error) {
            if (self.delegate && [self.delegate respondsToSelector:@selector(assetLibraryWriteFailedWithError:)]) {
                [self.delegate assetLibraryWriteFailedWithError:error];
            }
        } else {
            // 写入成功 回调封面图
            [self getVideoCoverImageWithVideoURL:videoURL callBlock:^(UIImage *coverImage) {
                if (self.delegate && [self.delegate respondsToSelector:@selector(writeVideoSuccessWithCoverImage:)]) {
                    [self.delegate writeVideoSuccessWithCoverImage:coverImage];
                }
            }];
        }
    }];
}

/// 获取封面图
- (void)getVideoCoverImageWithVideoURL:(NSURL *)videoURL callBlock:(void(^)(UIImage *))callBlock {
    dispatch_async(self.videoQueue, ^{
        AVAsset *asset = [AVAsset assetWithURL:videoURL];
        AVAssetImageGenerator *imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
        // 设置maximumSize 宽为100，高为0 根据视频的宽高比来计算图片的高度
        imageGenerator.maximumSize = CGSizeMake(100.0f, 0.0f);
        // 捕捉视频缩略图会考虑视频的变化（如视频的方向变化），如果不设置，缩略图的方向可能出错
        imageGenerator.appliesPreferredTrackTransform = YES;
        CGImageRef imageRef = [imageGenerator copyCGImageAtTime:kCMTimeZero actualTime:NULL error:nil];
        UIImage *image = [UIImage imageWithCGImage:imageRef];
        CGImageRelease(imageRef);
        dispatch_async(dispatch_get_main_queue(), ^{
            !callBlock ?: callBlock(image);
        });
    });
}

#pragma mark - AVCaptureFileOutputRecordingDelegate
- (void)captureOutput:(AVCaptureFileOutput *)output didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray<AVCaptureConnection *> *)connections error:(NSError *)error {
    if (!error) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(mediaCaptureFailedWithError:)]) {
            [self.delegate mediaCaptureFailedWithError:error];
        }
    } else {
        // copy一个副本再置为nil
        [self writeVideoToAssetsLibrary:self.outputURL.copy];
        self.outputURL = nil;
    }
}

#pragma mark - Lazy Load
- (dispatch_queue_t)videoQueue {
    if (!_videoQueue) {
        _videoQueue = dispatch_queue_create("CQ_VideoQueue", NULL);
    }
    return _videoQueue;
}

@end
