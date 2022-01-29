//
//  CQCaptureManager.h
//  CQAVKit
//
//  Created by 刘超群 on 2021/10/29.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVCaptureDevice.h>
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
 当捕捉到信号时
 @param sampleBuffer 捕捉到的buffer
 @param type 捕捉类型
 */
- (void)captureSampleBuffer:(CMSampleBufferRef)sampleBuffer type:(CQCaptureType)type;

/**
 设备配置错误，创建AVCaptureDeviceInput出错 / lockForConfiguration出错
 @param error 错误信息
 */
- (void)deviceConfigurationFailedWithError:(NSError *)error;
/**
 切换相机成功
 */
- (void)switchCameraSuccess;
/**
 切换相机失败
 */
- (void)switchCameraFailed;
/**
 媒体捕捉错误，捕捉照片或视频时出现错误
 @param error 错误信息
 */
- (void)mediaCaptureFailedWithError:(NSError *)error;
/**
 媒体捕捉图片成功
 */
- (void)mediaCaptureImageSuccess;
/**
 媒体捕捉视频成功
 */
- (void)mediaCaptureVideoSuccess;
/**
 资源库写入错误，将图片或视频写入相册时出现错误
 @param error 错误信息
 */
- (void)assetLibraryWriteFailedWithError:(NSError *)error;
/**
 资源库写入图片成功
 @param image 被写入的图片
 */
- (void)assetLibraryWriteImageSuccessWithImage:(UIImage *)image;
/**
 资源库写入视频成功
 @param coverImage 视频封面图片
 */
- (void)assetLibraryWriteVideoSuccessWithCoverImage:(UIImage *)coverImage;

@end

#pragma mark - CQCaptureManager
@interface CQCaptureManager : NSObject

//- (instancetype)initWithType:(CCSystemCaptureType)type;
//- (instancetype)init UNAVAILABLE_ATTRIBUTE;

/**捕获视频的宽*/
@property (nonatomic, assign, readonly) NSUInteger witdh;
/**捕获视频的高*/
@property (nonatomic, assign, readonly) NSUInteger height;

@property (nonatomic, weak) id<CQCaptureManagerDelegate> delegate;

@property (nonatomic, strong, readonly) AVCaptureSession *captureSession; ///< 捕捉会话

#pragma mark - Property Device Support
@property (nonatomic, assign, readonly) NSUInteger cameraCount;  ///< 摄像头数量
@property (nonatomic, assign, readonly) BOOL isHasTorch; ///< 相机是否有手电筒
@property (nonatomic, assign, readonly) BOOL isHasFlash; ///< 相机是否有闪光灯
@property (nonatomic, assign) AVCaptureTorchMode torchMode; ///< 手电筒模式,0关 1开，立即生效
@property (nonatomic, assign) AVCaptureFlashMode flashMode; ///< 闪光灯模式,0关 1开 2自动，仅按下快门时有效
@property (nonatomic, assign, readonly) BOOL isSupportTapFocus;  ///< 相机是否支持点击聚焦，例如一些设备的前置是不支持的
@property (nonatomic, assign, readonly) BOOL isSupportTapExpose; ///< 相机是否支持点击曝光

#pragma mark - Func 设置会话
/**
 设置会话
 @param error 接收错误信息
 */
- (BOOL)setupSession:(NSError * _Nullable *)error;
/**
 开始会话
 */
- (void)startSession;
/**
 停止会话
 */
- (void)stopSession;

#pragma mark - Func 镜头切换
/**
 切换摄像头
 @return 切换是否成功
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

#pragma mark - Func 图片&视频捕捉
/**
 捕捉静态图片
 */
- (void)captureStillImage;

/**
 开始录制视频
 */
- (void)startRecordingVideo;
/**
 停止录制视频
 */
- (void)stopRecordingVideo;
/**
 是否在录制视频
 @return 是否在录制视频
 */
- (BOOL)isRecordingVideo;
/**
 录制视频的时间
 @return 录制视频的时间
 */
- (CMTime)recordedDuration;

@end

NS_ASSUME_NONNULL_END
