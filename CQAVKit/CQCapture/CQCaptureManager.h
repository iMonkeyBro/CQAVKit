//
//  CQCaptureManager.h
//  CQAVKit
//
//  Created by 刘超群 on 2021/10/29.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVCaptureDevice.h>
#import <AVFoundation/AVMetadataObject.h>
#import <UIKit/UIKit.h>
#import <CoreMedia/CMSampleBuffer.h>

@class AVCaptureSession;

typedef NS_ENUM(NSUInteger, CQCaptureType) {
    CQCaptureTypeAll = 0,
    CQCaptureTypeVideo = 1,
    CQCaptureTypeAudio = 2,
};

NS_ASSUME_NONNULL_BEGIN

#pragma mark - CQCaptureManagerDelegate
@protocol CQCaptureManagerDelegate<NSObject>
@optional

/**
 当捕捉到视频信号时
 @param sampleBuffer 捕捉到的buffer
 */
- (void)captureVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer;

/**
 当捕捉到音频信号时
 @param sampleBuffer 捕捉到的buffer
 */
- (void)captureAudioSampleBuffer:(CMSampleBufferRef)sampleBuffer;

#pragma mark - 配置回调
/**
 设备配置错误，创建AVCaptureDeviceInput出错 / lockForConfiguration出错
 @param error 错误信息
 */
- (void)deviceConfigurationFailedWithError:(NSError *)error;

#pragma mark - 相机操作回调
/**
 切换相机成功
 */
- (void)switchCameraSuccess;
/**
 切换相机失败
 */
- (void)switchCameraFailed;

#pragma mark - 静态图片捕捉回调
/**
 媒体捕捉图片文件成功，AVCaptureStillImageOutput成功
 */
- (void)mediaCaptureImageFileSuccess;
/**
 媒体捕捉照片时出现错误，AVCaptureStillImageOutput错误
 @param error 错误信息
 */
- (void)mediaCaptureImageFailedWithError:(NSError *)error;
/**
 资源库写入图片错误，将图片写入相册时出现错误
 @param error 错误信息
 */
- (void)assetLibraryWriteImageFailedWithError:(NSError *)error;
/**
 资源库写入图片成功
 @param image 被写入的图片
 */
- (void)assetLibraryWriteImageSuccessWithImage:(UIImage *)image;

#pragma mark - 电影文件捕捉回调
/**
 媒体捕捉电影文件成功，AVCaptureMovieFileOutput成功
 */
- (void)mediaCaptureMovieFileSuccess;
/**
 媒体捕捉电影文件时出现错误，AVCaptureMovieFileOutput错误
 @param error 错误信息
 */
- (void)mediaCaptureMovieFileFailedWithError:(NSError *)error;
/**
 资源库写入电影文件错误，将视频写入相册时出现错误
 @param error 错误信息
 */
- (void)assetLibraryWriteMovieFileFailedWithError:(NSError *)error;
/**
 资源库写入电影文件成功
 @param coverImage 视频封面图片
 */
- (void)assetLibraryWriteMovieFileSuccessWithCoverImage:(UIImage *)coverImage;

#pragma mark - 元数据捕捉回调
- (void)mediaCaptureMetadataSuccessWithMetadataObjects:(NSArray<__kindof AVMetadataObject *> *)metadataObjects;

@end

#pragma mark - CQCaptureManager
@interface CQCaptureManager : NSObject

- (instancetype)init;
- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_UNAVAILABLE;


@property (nonatomic, weak) id<CQCaptureManagerDelegate> delegate;

@property (nonatomic, strong, readonly) AVCaptureSession *captureSession; ///< 捕捉会话

@property (nonatomic, assign) AVCaptureSessionPreset videoSessionPreset;  ///< 捕获视频的分辨率

#pragma mark - Property Device Support
@property (nonatomic, assign, readonly) NSUInteger cameraCount;  ///< 摄像头数量
@property (nonatomic, assign, readonly) BOOL isHasTorch; ///< 相机是否有手电筒
@property (nonatomic, assign, readonly) BOOL isHasFlash; ///< 相机是否有闪光灯
@property (nonatomic, assign) AVCaptureTorchMode torchMode; ///< 手电筒模式,0关 1开，立即生效
@property (nonatomic, assign) AVCaptureFlashMode flashMode; ///< 闪光灯模式,0关 1开 2自动，仅按下快门时有效
@property (nonatomic, assign, readonly) BOOL isSupportTapFocus;  ///< 相机是否支持点击聚焦，例如一些设备的前置是不支持的
@property (nonatomic, assign, readonly) BOOL isSupportTapExpose; ///< 相机是否支持点击曝光

#pragma mark - Func 会话
/**
 开始会话
 注意:同步开启会话是耗时操作
 */
- (void)startSessionSync;
/**
 停止会话
 注意:同步关闭会话是耗时操作
 */
- (void)stopSessionSync;

/**
 开始会话
 注意:捕捉静态图片、捕捉视频文件必须在开启会话之后，否则会崩溃，异步开启会话一定要注意开启之后再捕捉
 */
- (void)startSessionAsync;
/**
 停止会话
 */
- (void)stopSessionAsync;

#pragma mark - Func 参数配置
/// 配置捕捉会话的分辨率，视频/图像类捕捉前应设置，未设置默认为AVCaptureSessionPresetMedium
- (void)configSessionPreset:(AVCaptureSessionPreset)sessionPreset;

/// 配置FPS
- (void)configVideoFps:(NSUInteger)fps;

#pragma mark - Func 视频输入配置
/// 配置视频输入
- (BOOL)configVideoInput:(NSError * _Nullable *)error;

/// 移除视频输入设备
- (void)removeVideoDeviceInput;

#pragma mark - Func 视频输出配置
/// 配置静态图片输出
- (void)configStillImageOutput;

/// 移除静态图片输出
- (void)removeStillImageOutput;

/// 配置电影文件输出
- (void)configMovieFileOutput;

/// 移除电影文件输出
- (void)removeMovieFileOutput;

/// 配置视频数据输出
- (void)configVideoDataOutput;

/// 移除视频数据输出
- (void)removeVideoDataOutput;

#pragma mark - Func 音频输入配置
/// 配置音频输入
- (BOOL)configAudioInput:(NSError * _Nullable *)error;

/// 移除音频输入设备
- (void)removeAudioDeviceInput;

#pragma mark - Func 音频输出配置
/// 配置音频数据输出
- (BOOL)configAudioDataOutput;

/// 移除音频数据输出
- (void)removeAudioDataOutput;

#pragma mark - Func 元数据输入输出配置
/**
 配置元数据输出
 @param metadatObjectTypes 元数据范围(人脸数据，二维码数据，一维码数据等)
 */
- (BOOL)configMetadataOutputWithType:(NSArray<AVMetadataObjectType> *)metadatObjectTypes;

/// 移除元数据输出
- (void)removeMetadataOutput;

#pragma mark - 静态图片捕捉
/**
 捕捉静态图片
 应先configSessionPreset/configVideoInput/configStillImageOutput,未配置将默认配置，startSession
 */
- (void)captureStillImage;

#pragma mark - 电影文件文件捕捉
/**
 开始录制电影文件
 应先configSessionPreset/configVideoInput/configMovieFileOutput,未配置将默认配置，startSession
 */
- (void)startRecordingMovieFile;
/**
 停止录制电影文件
 */
- (void)stopRecordingMovieFile;
/**
 是否在录制电影文件
 @return 是否在录制视频
 */
- (BOOL)isRecordingMovieFile;
/**
 录制电影文件的时间
 @return 录制视频的时间
 */
- (CMTime)movieFileRecordedDuration;

#pragma mark - 视频数据捕捉
/// 开始捕捉视频数据(包括音频视频),configSessionPreset/configVideoInput/configStillImageOutput,未配置将默认配置
- (void)startCaptureVideoData;
/// 停止捕捉视频数据
- (void)stopCaptureVideoData;
/// 开始捕捉视频数据(不包括音频),configSessionPreset/configVideoInput/configStillImageOutput,未配置将默认配置
- (void)startCaptureMuteVideoData;
/// 停止捕捉视频数据
- (void)stopCaptureMuteVideoData;

#pragma mark - 音频数据捕捉
/// 开始捕捉音频数据
- (void)startCaptureAudioData;
/// 停止捕捉音频数据
- (void)stopCaptureAudioData;

#pragma mark - Func 镜头切换
/**
 切换摄像头
 @return 切换是否成功，return NO一定失败，return YES还需要看代理回调
 */
- (BOOL)switchCamera;
/**
 是否能切换摄像头
 @return 是否可以切换
 */
- (BOOL)canSwitchCamera;

#pragma mark - Func 对焦&曝光
/**
 设置对焦点
 @param point 对焦点
 */
- (void)focusAtPoint:(CGPoint)point;
/**
 设置曝光点
 @param point 曝光点
 */
- (void)exposeAtPoint:(CGPoint)point;
/**
 重置对焦和曝光,将对焦点和曝光点设为中心，并将对焦和曝光模式设为自动
 */
- (void)resetFocusAndExposureModes;

@end

NS_ASSUME_NONNULL_END
