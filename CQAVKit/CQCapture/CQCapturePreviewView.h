//
//  CQCapturePreviewView.h
//  CQAVKit
//
//  Created by 刘超群 on 2021/10/28.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol CQCapturePreviewViewDelegate<NSObject>
/// 点击对焦
- (void)tapFocusAtPoint:(CGPoint)point;
/// 点击曝光
- (void)tapExposeAtPoint:(CGPoint)point;
/// 点击重置聚焦&曝光
- (void)tapResetFocusAndExposure;
@end

@interface CQCapturePreviewView : UIView

@property (nonatomic, weak) id<CQCapturePreviewViewDelegate> delegate;

//session用来关联AVCaptureVideoPreviewLayer 和 激活AVCaptureSession
@property (nonatomic, strong, readonly) AVCaptureSession *session;

@property (nonatomic, assign) BOOL isFocusEnabled;  ///< 是否聚焦
@property (nonatomic, assign) BOOL isExposeEnabled;  ///< 是否曝光

@end

NS_ASSUME_NONNULL_END
