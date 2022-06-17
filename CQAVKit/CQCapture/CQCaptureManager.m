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

#define kasync_main_safe(block)\
if ([NSThread isMainThread]) {\
block();\
} else {\
dispatch_async(dispatch_get_main_queue(), block);\
}

static const NSString *CameraAdjustingExposureContext;

/**
 AVCaptureFileOutputRecordingDelegate 视频文件录制
 AVCaptureVideoDataOutputSampleBufferDelegate/AVCaptureAudioDataOutputSampleBufferDelegate  拿NALU数据 Buffer
 AVCaptureMetadataOutputObjectsDelegate 拿元数据，人脸识别
 */

@interface CQCaptureManager ()<AVCaptureFileOutputRecordingDelegate, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate, AVCaptureMetadataOutputObjectsDelegate>
/*********公共**********/
@property (nonatomic, strong) dispatch_queue_t captureQueue; ///< 捕捉队列
@property (nonatomic, strong) AVCaptureSession *captureSession; ///< 捕捉会话
/*********视频相关**********/
// captureSession下活跃的视频输入,一个捕捉会话下会有很多，设置个成员变量方便拿
@property (nonatomic, assign) BOOL isConfigSessionPreset;  ///< 是否配置过分辨率
@property (nonatomic, strong) AVCaptureDeviceInput *videoDeviceInput;  ///< 视频输入设备
@property (nonatomic, strong) AVCaptureStillImageOutput *stillImageOutput;  ///< 图片输出
@property (nonatomic, strong) AVCaptureMovieFileOutput *movieFileOutput;  ///< 电影输出
@property (nonatomic, strong) NSURL *movieFileOutputURL;  ///< 输出URL
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoDataOutput;  ///< 视频数据输出
/*********音频相关**********/
@property (nonatomic, strong) AVCaptureDeviceInput *audioDeviceInput;  ///< 音频输入设备
@property (nonatomic, strong) AVCaptureAudioDataOutput *audioDataOutput;  ///< 音频数据输出
/*********Metadata相关**********/
@property (nonatomic, strong) AVCaptureMetadataOutput *metadataOutput;  ///< 音频数据输出

@end

@implementation CQCaptureManager

#pragma mark - Init
- (instancetype)init {
    if (self = [super init]) {
        // 创建捕捉会话 AVCaptureSession 是捕捉场景的中心枢纽
        self.captureSession = [[AVCaptureSession alloc] init];
    }
    return self;
}

- (void)dealloc {
    NSLog(@"CQCaptureManager - dealloc !!!");
    [self destroyCaptureSession];
}

/// 销毁会话
- (void)destroyCaptureSession {
    if (self.captureSession) {
        if (self.audioDeviceInput) [self.captureSession removeInput:self.audioDeviceInput];
        if (self.videoDeviceInput) [self.captureSession removeInput:self.videoDeviceInput];
        if (self.stillImageOutput) [self.captureSession removeOutput:self.stillImageOutput];
        if (self.movieFileOutput) [self.captureSession removeOutput:self.movieFileOutput];
        if (self.videoDataOutput) [self.captureSession removeOutput:self.videoDataOutput];
        if (self.audioDataOutput) [self.captureSession removeOutput:self.audioDataOutput];
    }
    self.captureSession = nil;
}

#pragma mark - Public Func 参数配置
/// 配置捕捉会话的分辨率
- (void)configSessionPreset:(AVCaptureSessionPreset)sessionPreset {
    [self.captureSession beginConfiguration];
    if ([self.captureSession canSetSessionPreset:sessionPreset])  {
        self.captureSession.sessionPreset = sessionPreset;
    } else {
        self.captureSession.sessionPreset = AVCaptureSessionPresetMedium;
    }
    [self.captureSession commitConfiguration];
    self.isConfigSessionPreset = YES;
}

- (AVCaptureSessionPreset)videoSessionPreset {
    return self.captureSession.sessionPreset;
}

/// 配置FPS
- (void)configVideoFps:(NSUInteger)fps {
    AVCaptureDevice *device = [self getActiveCamera];
    //获取当前支持的最大fps
    float maxRate = [(AVFrameRateRange *)[device.activeFormat.videoSupportedFrameRateRanges objectAtIndex:0] maxFrameRate];
    //如果想要设置的fps小于或等于最大fps，就进行修改
    if (maxRate >= fps) {
        //实际修改fps的代码
        if ([device lockForConfiguration:NULL]) {
            device.activeVideoMinFrameDuration = CMTimeMake(10, (int)(fps * 10));
            device.activeVideoMaxFrameDuration = device.activeVideoMinFrameDuration;
            [device unlockForConfiguration];
        }
    }
}

#pragma mark - Func 视频输入输出配置
/// 配置视频输入
- (BOOL)configVideoInput:(NSError * _Nullable *)error {
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
        [self.captureSession beginConfiguration];
        [self.captureSession addInput:videoInput];
        [self.captureSession commitConfiguration];
        self.videoDeviceInput = videoInput;
        return YES;
    }else {
        return NO;
    }
}

/// 移除视频输入设备
- (void)removeVideoDeviceInput {
    if (self.videoDeviceInput) [self.captureSession removeInput:self.videoDeviceInput];
}

/// 配置静态图片输出
- (void)configStillImageOutput {
    // AVCaptureStillImageOutput 从摄像头捕捉静态图片
    self.stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    // 配置字典：希望捕捉到JPEG格式的图片
    self.stillImageOutput.outputSettings = @{AVVideoCodecKey:AVVideoCodecJPEG};
    // 输出连接 判断是否可用，可用则添加到输出连接中去
    [self.captureSession beginConfiguration];
    if ([self.captureSession canAddOutput:self.stillImageOutput]) {
        [self.captureSession addOutput:self.stillImageOutput];
    }
    [self.captureSession commitConfiguration];
}

/// 移除静态图片输出
- (void)removeStillImageOutput {
    if (self.stillImageOutput) [self.captureSession removeOutput:self.stillImageOutput];
}

/// 配置电影文件输出
- (void)configMovieFileOutput {
    // AVCaptureMovieFileOutput，将QuickTime视频录制到文件系统
    self.movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
    [self.captureSession beginConfiguration];
    if ([self.captureSession canAddOutput:self.movieFileOutput]) {
        [self.captureSession addOutput:self.movieFileOutput];
    }
    [self.captureSession commitConfiguration];
}

/// 移除电影文件输出
- (void)removeMovieFileOutput {
    if (self.movieFileOutput) [self.captureSession removeOutput:self.movieFileOutput];
}

/// 配置视频数据输出
- (void)configVideoDataOutput {
    // 视频Buffer输出
    self.videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    [self.videoDataOutput setSampleBufferDelegate:self queue:self.captureQueue];
    [self.videoDataOutput setAlwaysDiscardsLateVideoFrames:YES];
    //kCVPixelBufferPixelFormatTypeKey它指定像素的输出格式，这个参数直接影响到生成图像的成功与否
   // kCVPixelFormatType_420YpCbCr8BiPlanarFullRange  YUV420格式.
    [self.videoDataOutput setVideoSettings:@{(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)}];
    [self.captureSession beginConfiguration];
    if ([self.captureSession canAddOutput:self.videoDataOutput]) {
        [self.captureSession addOutput:self.videoDataOutput];
    }
    [self.captureSession commitConfiguration];
}

/// 移除视频数据输出
- (void)removeVideoDataOutput {
    if (self.videoDataOutput) [self.captureSession removeOutput:self.videoDataOutput];
}

#pragma mark - Func 音频输入输出配置
/// 配置音频输入
- (BOOL)configAudioInput:(NSError * _Nullable *)error {
    // 添加音频捕捉设备 ，如果只是拍摄静态图片，可以不用设置
    // 选择默认音频捕捉设备 即返回一个内置麦克风
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    self.audioDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:error];
    if (self.audioDeviceInput && [self.captureSession canAddInput:self.audioDeviceInput]) {
        [self.captureSession beginConfiguration];
        [self.captureSession addInput:self.audioDeviceInput];
        [self.captureSession commitConfiguration];
        return YES;
    }else {
        return NO;
    }
}

/// 移除音频输入设备
- (void)removeAudioDeviceInput {
    if (self.audioDeviceInput) [self.captureSession removeInput:self.audioDeviceInput];
}

/// 配置音频数据输出
- (BOOL)configAudioDataOutput {
    self.audioDataOutput = [[AVCaptureAudioDataOutput alloc] init];
    [self.audioDataOutput setSampleBufferDelegate:self queue:self.captureQueue];
    if([self.captureSession canAddOutput:self.audioDataOutput]){
        [self.captureSession beginConfiguration];
        [self.captureSession addOutput:self.audioDataOutput];
        [self.captureSession commitConfiguration];
        return YES;
    } else {
        return NO;
    }
}

/// 移除音频数据输出
- (void)removeAudioDataOutput {
    if (self.audioDataOutput) [self.captureSession removeOutput:self.audioDataOutput];
}

#pragma mark - Func 元数据输入输出配置
- (BOOL)configMetadataOutputWithType:(NSArray<AVMetadataObjectType> *)metadatObjectTypes {
    self.metadataOutput = [[AVCaptureMetadataOutput alloc] init];
    // 人脸检测使用了硬件加速器，所以任务需要在主线程执行
    if ([self.captureSession canAddOutput:self.metadataOutput]) {
        [self.captureSession beginConfiguration];
        [self.captureSession addOutput:self.metadataOutput];
        // 限制检查到元数据类型集合的做法是一种优化处理方法。可以减少我们实际感兴趣的对象数量
        self.metadataOutput.metadataObjectTypes = metadatObjectTypes;
        [self.metadataOutput setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
        [self.captureSession commitConfiguration];
        return YES;
    } else {
        return NO;
    }
}

- (void)removeMetadataOutput {
    if (self.metadataOutput) [self.captureSession removeOutput:self.metadataOutput];
}

#pragma mark - AVCaptureMetadataOutputObjectsDelegate
// 捕获到元数据回调
- (void)captureOutput:(AVCaptureOutput *)output didOutputMetadataObjects:(NSArray<__kindof AVMetadataObject *> *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
    if (self.delegate && [self.delegate respondsToSelector:@selector(mediaCaptureMetadataSuccessWithMetadataObjects:)]) {
        [self.delegate mediaCaptureMetadataSuccessWithMetadataObjects:metadataObjects];
    }
}

#pragma mark - Func 会话
// 同步开始会话
- (void)startSessionSync {
    // 检查是否处于运行状态
    if (![self.captureSession isRunning]) {
        // 使用同步调用会损耗一定的时间，则用异步的方式处理
        dispatch_sync(self.captureQueue, ^{
            [self.captureSession startRunning];
        });
    }
}

// 同步停止会话
- (void)stopSessionSync {
    // 检查是否处于运行状态
    if ([self.captureSession isRunning]) {
        dispatch_sync(self.captureQueue, ^{
            [self.captureSession stopRunning];
        });
    }
}

// 异步开始会话
- (void)startSessionAsync {
    // 检查是否处于运行状态
    if (![self.captureSession isRunning]) {
        // 使用同步调用会损耗一定的时间，则用异步的方式处理
        dispatch_async(self.captureQueue, ^{
            [self.captureSession startRunning];
        });
    }
}

// 异步停止会话
- (void)stopSessionAsync {
    // 检查是否处于运行状态
    if ([self.captureSession isRunning]) {
        dispatch_async(self.captureQueue, ^{
            [self.captureSession stopRunning];
        });
    }
}

#pragma mark - 静态图片捕捉
#pragma mark Public Func 静态图片捕捉
// 捕捉静态图片
- (void)captureStillImage {
    if (!self.isConfigSessionPreset) [self configSessionPreset:AVCaptureSessionPresetMedium];
    if (!self.videoDeviceInput) {
        NSError *configError;
        BOOL configResult = [self configVideoInput:&configError];
        if (!configResult) return;
    }
    if (!self.stillImageOutput) [self configStillImageOutput];
    [self startSessionSync];
    
    // 获取图片输出连接
    AVCaptureConnection *connection = [self.stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
    // 即使程序只支持纵向，但是如果用户横向拍照时，需要调整结果照片的方向
    // 判断是否支持设置视频方向， 支持则根据设备方向设置输出方向值
    if (connection.isVideoOrientationSupported) {
        connection.videoOrientation = [self getCurrentVideoOrientation];
    }
    
    [self.stillImageOutput captureStillImageAsynchronouslyFromConnection:connection completionHandler:^(CMSampleBufferRef  _Nullable imageDataSampleBuffer, NSError * _Nullable error) {
        if (imageDataSampleBuffer != NULL) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.delegate && [self.delegate respondsToSelector:@selector(mediaCaptureImageFileSuccess)]) {
                    [self.delegate mediaCaptureImageFileSuccess];
                }
            });
            // CMSampleBufferRef转UIImage 并写入相册
            NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
            UIImage *image = [[UIImage alloc] initWithData:imageData];
            
            [self writeImageToAssetsLibrary:image];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.delegate && [self.delegate respondsToSelector:@selector(mediaCaptureImageFailedWithError:)]) {
                    [self.delegate mediaCaptureImageFailedWithError:error];
                }
            });
            NSLog(@"NULL sampleBuffer:%@",[error localizedDescription]);
        }
    }];
}

#pragma mark Private Func 静态图片捕捉
/**
 Assets Library 框架
 用来让开发者通过代码方式访问iOS photo
 注意：会访问到相册，需要修改plist 权限。否则会导致项目崩溃
 */

/// 将UIImage写入到用户相册
- (void)writeImageToAssetsLibrary:(UIImage *)image {
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    // 参数1 图片， 参数2 方向， 参数3 回调
    [library writeImageToSavedPhotosAlbum:image.CGImage orientation:(NSUInteger)image.imageOrientation completionBlock:^(NSURL *assetURL, NSError *error) {
        if (!error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.delegate && [self.delegate respondsToSelector:@selector(assetLibraryWriteImageSuccessWithImage:)]) {
                    [self.delegate assetLibraryWriteImageSuccessWithImage:image];
                }
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.delegate && [self.delegate respondsToSelector:@selector(assetLibraryWriteImageFailedWithError:)]) {
                    [self.delegate assetLibraryWriteImageFailedWithError:error];
                }
            });
        }
    }];
}

#pragma mark - 视频文件捕捉
#pragma mark Public Func 视频文件捕捉
// 开始录制电影文件
- (void)startRecordingMovieFile {
    if (!self.isConfigSessionPreset) [self configSessionPreset:AVCaptureSessionPresetMedium];
    if (!self.videoDeviceInput) {
        NSError *configError;
        BOOL configResult = [self configVideoInput:&configError];
        if (!configResult) return;
    }
    if (!self.movieFileOutput) [self configMovieFileOutput];
    [self startSessionSync];
    
    if ([self isRecordingMovieFile]) return;
    AVCaptureConnection *videoConnection = [self.movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
    // 设置输出方向
    // 即使程序只支持纵向，但是如果用户横向拍照时，需要调整结果照片的方向
    // 判断是否支持设置视频方向， 支持则根据设备方向设置输出方向值
    if (videoConnection.isVideoOrientationSupported) {
        videoConnection.videoOrientation = [self getCurrentVideoOrientation];
    }
    // 设置视频帧稳定
    // 判断是否支持视频稳定 可以显著提高视频的质量。只会在录制视频文件涉及
//    if (videoConnection.isVideoStabilizationSupported) {
//        videoConnection.enablesVideoStabilizationWhenAvailable = YES;
//    }
    
    videoConnection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;

    // 设置对焦
    AVCaptureDevice *device = [self getActiveCamera];
    // 摄像头可以进行平滑对焦模式操作。即减慢摄像头镜头对焦速度。当用户移动拍摄时摄像头会尝试快速自动对焦。
    if (device.isSmoothAutoFocusEnabled) {
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            device.smoothAutoFocusEnabled = YES;
            [device unlockForConfiguration];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.delegate && [self.delegate respondsToSelector:@selector(deviceConfigurationFailedWithError:)]) {
                    [self.delegate deviceConfigurationFailedWithError:error];
                }
            });
        }
    }
    
    self.movieFileOutputURL = [self getVideoTempPathURL];
    // 开始录制 参数1:录制保存路径  参数2:代理
    [self.movieFileOutput startRecordingToOutputFileURL:self.movieFileOutputURL recordingDelegate:self];
}

// 停止录制电影文件
- (void)stopRecordingMovieFile {
    if ([self isRecordingMovieFile]) {
        [self.movieFileOutput stopRecording];
    }
}

// 是否在录制电影文件
- (BOOL)isRecordingMovieFile {
    return self.movieFileOutput.isRecording;
}

// 录制电影文件的时间
- (CMTime)movieFileRecordedDuration {
    return self.movieFileOutput.recordedDuration;
}

#pragma mark AVCaptureFileOutputRecordingDelegate
/// 捕捉电影文件成功的回调
- (void)captureOutput:(AVCaptureFileOutput *)output didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray<AVCaptureConnection *> *)connections error:(NSError *)error {
    if (error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.delegate && [self.delegate respondsToSelector:@selector(mediaCaptureMovieFileFailedWithError:)]) {
                [self.delegate mediaCaptureMovieFileFailedWithError:error];
            }
        });
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.delegate && [self.delegate respondsToSelector:@selector(mediaCaptureMovieFileSuccess)]) {
                [self.delegate mediaCaptureMovieFileSuccess];
            }
        });
        // copy一个副本再置为nil
        // 将文件写入相册
        [self writeVideoToAssetsLibrary:self.movieFileOutputURL.copy];
        self.movieFileOutputURL = nil;
    }
}


#pragma mark Private Func 电影文件捕捉
/// 创建视频文件临时路径URL
- (NSURL *)getVideoTempPathURL {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *tempPath = [fileManager temporaryDirectoryWithTemplateString:@"video.XXXXXX"];
    if (tempPath) {
        NSString *filePath = [tempPath stringByAppendingPathComponent:@"temp_video.mov"];
        return [NSURL fileURLWithPath:filePath];
    }
    return nil;
}

/// 将视频文件写入到用户相册
- (void)writeVideoToAssetsLibrary:(NSURL *)videoURL {
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    // 和图片不同，视频的写入更耗时，所以写入之前应该判断是否能写入
    if (![library videoAtPathIsCompatibleWithSavedPhotosAlbum:videoURL]) return;
    [library writeVideoAtPathToSavedPhotosAlbum:videoURL completionBlock:^(NSURL *assetURL, NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.delegate && [self.delegate respondsToSelector:@selector(assetLibraryWriteMovieFileFailedWithError:)]) {
                    [self.delegate assetLibraryWriteMovieFileFailedWithError:error];
                }
            });
        } else {
            // 写入成功 回调封面图
            [self getVideoCoverImageWithVideoURL:videoURL callBlock:^(UIImage *coverImage) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (self.delegate && [self.delegate respondsToSelector:@selector(assetLibraryWriteMovieFileSuccessWithCoverImage:)]) {
                        [self.delegate assetLibraryWriteMovieFileSuccessWithCoverImage:coverImage];
                    }
                });
            }];
        }
    }];
}

/// 获取视频文件封面图
- (void)getVideoCoverImageWithVideoURL:(NSURL *)videoURL callBlock:(void(^)(UIImage *))callBlock {
    dispatch_async(self.captureQueue, ^{
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

#pragma mark - 视频数据捕捉
/// 捕捉视频数据
- (void)startCaptureVideoData {
    if (!self.isConfigSessionPreset) [self configSessionPreset:AVCaptureSessionPresetMedium];
    if (!self.videoDeviceInput) {
        NSError *configError;
        BOOL configResult = [self configVideoInput:&configError];
        if (!configResult) return;
    }
    if (!self.videoDataOutput) [self configVideoDataOutput];
    if (!self.audioDeviceInput) {
        NSError *configError;
        BOOL configResult = [self configAudioInput:&configError];
        if (!configResult) return;
    }
    if (!self.audioDataOutput) [self configAudioDataOutput];
    [self startSessionSync];
}

- (void)stopCaptureVideoData {
    [self stopSessionSync];
}

/// 捕捉视频数据
- (void)startCaptureMuteVideoData {
    if (!self.isConfigSessionPreset) [self configSessionPreset:AVCaptureSessionPresetMedium];
    if (!self.videoDeviceInput) {
        NSError *configError;
        BOOL configResult = [self configVideoInput:&configError];
        if (!configResult) return;
    }
    if (!self.movieFileOutput) [self configMovieFileOutput];
    [self startSessionSync];
}

- (void)stopCaptureMuteVideoData {
    [self stopSessionSync];
}

#pragma mark - 音频数据捕捉
/// 捕捉音频数据
- (void)startCaptureAudioData {
    if (!self.audioDeviceInput) {
        NSError *configError;
        BOOL configResult = [self configAudioInput:&configError];
        if (!configResult) return;
    }
    if (!self.audioDataOutput) [self configAudioDataOutput];
    [self startSessionSync];
}

- (void)stopCaptureAudioData {
    [self stopSessionSync];
}

#pragma mark AVCaptureVideo/AudioDataOutputSampleBufferDelegate
-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    // 注意，视频/音频通过AV采集，都会走这里，需要对音频/视频做区分
    // 直接判断output 是videoDataOutput/Audio
    if ([captureOutput isKindOfClass:AVCaptureVideoDataOutput.class]) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(captureVideoSampleBuffer:)]) {
            [_delegate captureVideoSampleBuffer:sampleBuffer];
        }
    }
    if ([captureOutput isKindOfClass:AVCaptureAudioDataOutput.class]) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(captureAudioSampleBuffer:)]) {
            [_delegate captureAudioSampleBuffer:sampleBuffer];
        }
    }
}

#pragma mark - Getter
/**
 获取当前活跃的设备，简单二次封装
 */

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
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.delegate && [self.delegate respondsToSelector:@selector(deviceConfigurationFailedWithError:)]) {
                [self.delegate deviceConfigurationFailedWithError:error];
            }
        });
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
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.delegate && [self.delegate respondsToSelector:@selector(deviceConfigurationFailedWithError:)]) {
                [self.delegate deviceConfigurationFailedWithError:error];
            }
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
        // 将捕捉会话中，原本的捕捉输入设备移除，不移除不能添加新的
        [self.captureSession removeInput:self.videoDeviceInput];
        if ([self.captureSession canAddInput:newVideoInput]) {
            [self.captureSession addInput:newVideoInput];
            self.videoDeviceInput = newVideoInput;
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.delegate && [self.delegate respondsToSelector:@selector(switchCameraSuccess)]) {
                    [self.delegate switchCameraSuccess];
                }
            });
        } else {
            // 已经移除了，还是无法添加新设备，则将原本的视频捕捉设备重新加入到捕捉会话中
            [self.captureSession addInput:self.videoDeviceInput];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.delegate && [self.delegate respondsToSelector:@selector(switchCameraFailed)]) {
                    [self.delegate switchCameraFailed];
                }
            });
        }
        // 提交配置，AVCaptureSession commitConfiguration 会分批的将所有变更整合在一起。
        [self.captureSession commitConfiguration];
        return YES;
    } else {
        // 创建AVCaptureDeviceInput 出现错误，回调该错误
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.delegate && [self.delegate respondsToSelector:@selector(deviceConfigurationFailedWithError:)]) {
                [self.delegate deviceConfigurationFailedWithError:error];
            }
        });
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

// 设置对焦点
- (void)focusAtPoint:(CGPoint)point {
    AVCaptureDevice *device = [self getActiveCamera];
    // 摄像头是否支持兴趣点对焦 & 是否支持自动对焦模式 ,不支持不操作，玩手动对焦的需求另说
    if (!device.isFocusPointOfInterestSupported || ![device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) return;
    NSError *error;
    // 锁定设备准备配置，因为配置时不能让多个地方对同一个设备更改，所以需要加锁
    if ([device lockForConfiguration:&error]) {
        // 设置对焦点
        device.focusPointOfInterest = point;
        // 对焦模式设置为自动对焦
        device.focusMode = AVCaptureFocusModeAutoFocus;
        // 释放锁定
        [device unlockForConfiguration];
    } else {
        // 锁定错误时，回调错误
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.delegate && [self.delegate respondsToSelector:@selector(deviceConfigurationFailedWithError:)]) {
                [self.delegate deviceConfigurationFailedWithError:error];
            }
        });
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
        // 设置曝光点，针对该点进行自动曝光
        device.exposurePointOfInterest = point;
        // 曝光模式设置为自动曝光
        device.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
        // 判断设备是否支持锁定曝光的模式。
        if ([device isExposureModeSupported:AVCaptureExposureModeLocked]) {
            // 支持，则使用kvo监听设备的曝光调节状态。
            [device addObserver:self forKeyPath:@"adjustingExposure" options:NSKeyValueObservingOptionNew context:&CameraAdjustingExposureContext];
        }
        // 释放锁定
        [device unlockForConfiguration];
    } else {
        // 锁定错误时，回调错误处理代理
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.delegate && [self.delegate respondsToSelector:@selector(deviceConfigurationFailedWithError:)]) {
                [self.delegate deviceConfigurationFailedWithError:error];
            }
        });
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (context == &CameraAdjustingExposureContext) {
        //获取device
        AVCaptureDevice *device = (AVCaptureDevice *)object;
        // 设备不再调整曝光等级，说明自动调节曝光结束，并且支持设置为AVCaptureExposureModeLocked
        // TODO: -测试监听次数
        if(!device.isAdjustingExposure && [device isExposureModeSupported:AVCaptureExposureModeLocked] && device.isExposurePointOfInterestSupported) {
            // 使用一次监听，立即移除通知
            [object removeObserver:self forKeyPath:@"adjustingExposure" context:&CameraAdjustingExposureContext];
            dispatch_async(dispatch_get_main_queue(), ^{
                NSError *error;
                if ([device lockForConfiguration:&error]) {
                    // 锁定曝光
                    device.exposureMode = AVCaptureExposureModeLocked;
                    [device unlockForConfiguration];
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (self.delegate && [self.delegate respondsToSelector:@selector(deviceConfigurationFailedWithError:)]) {
                            [self.delegate deviceConfigurationFailedWithError:error];
                        }
                    });
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
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.delegate && [self.delegate respondsToSelector:@selector(deviceConfigurationFailedWithError:)]) {
                [self.delegate deviceConfigurationFailedWithError:error];
            }
        });
    }
}

#pragma mark - 获取设备方向
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

#pragma mark - Lazy Load
- (dispatch_queue_t)captureQueue {
    if (!_captureQueue) {
        _captureQueue = dispatch_queue_create("CQ_VideoQueue", NULL);
    }
    return _captureQueue;
}

@end
