//
//  CQCameraHandler.h
//  CQAVKit
//
//  Created by 刘超群 on 2021/10/29.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVCaptureDevice.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - CQCameraHandlerDelegate
@protocol CQCameraHandlerDelegate<NSObject>

/**
 设备配置错误
 @param error 错误信息
 */
- (void)deviceConfigurationFailedWithError:(NSError *)error;
/**
 媒体捕捉错误
 @param error 错误信息
 */
- (void)mediaCaptureFailedWithError:(NSError *)error;
/**
 资源库写入错误
 @param error 错误信息
 */
- (void)assetLibraryWriteFailedWithError:(NSError *)error;

@end

#pragma mark - CQCameraHandler
@interface CQCameraHandler : NSObject

@property (nonatomic, weak) id<CQCameraHandlerDelegate> delegate;

#pragma mark - Property Device Support
@property (nonatomic, assign, readonly) NSUInteger cameraCount;  ///< 摄像头数量
@property (nonatomic, assign, readonly) BOOL isHasTorch; ///< 相机是否有手电筒
@property (nonatomic, assign, readonly) BOOL isHasFlash; ///< 相机是否有闪光灯
@property (nonatomic, assign) AVCaptureTorchMode torchMode; ///< 手电筒模式
@property (nonatomic, assign) AVCaptureFlashMode flashMode; ///< 闪光灯模式
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
