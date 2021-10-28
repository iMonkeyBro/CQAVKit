//
//  CQCameraHandler.m
//  CQAVKit
//
//  Created by 刘超群 on 2021/10/29.
//

#import "CQCameraHandler.h"
#import <AVFoundation/AVFoundation.h>

@implementation CQCameraHandler

#pragma mark - Func 设置会话
// 设置会话
- (BOOL)setupSession:(NSError * _Nullable *)error {
    return YES;
}

// 开始会话
- (void)startSession {
    
}

// 停止会话
- (void)stopSession {
    
}

#pragma mark - Func 镜头切换
// 切换摄像头
- (BOOL)switchCamera {
    return YES;
}

// 是否能切换摄像头
- (BOOL)canSwitchCamera {
    return YES;
}

#pragma mark - Func 对焦&曝光
// 设置对焦点
- (void)focusAtPoint:(CGPoint)point {
    
}

// 设置曝光点
- (void)exposeAtPoint:(CGPoint)point {
    
}

// 重置对焦和曝光
- (void)resetFocusAndExposureModes {
    
}

#pragma mark - Func 图片&视频捕捉
// 捕捉静态图片
- (void)captureStillImage {
    
}

// 开始录制视频
- (void)startRecordingVideo {
    
}

// 停止录制视频
- (void)stopRecordingVideo {
    
}

// 是否在录制视频
- (BOOL)isRecordingVideo {
    return YES;
}

// 录制视频的时间
- (CMTime)recordedDuration {
    return kCMTimeZero;
}

@end
