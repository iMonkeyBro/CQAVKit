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
@optional
/// 当点击对焦
- (void)didTapFocusAtPoint:(CGPoint)point;
/// 当点击曝光
- (void)didTapExposeAtPoint:(CGPoint)point;
/// 当点击重置聚焦&曝光
- (void)didTapResetFocusAndExposure;
@end

@interface CQCapturePreviewView : UIView

@property (nonatomic, weak) id<CQCapturePreviewViewDelegate> delegate;

/// session用来关联AVCaptureVideoPreviewLayer 和 激活AVCaptureSession
@property (nonatomic, strong) AVCaptureSession *session;

@property (nonatomic, assign) AVLayerVideoGravity videoGravity;

@property (nonatomic, assign) BOOL isFocusEnabled;  ///< 是否能点击聚焦，禁用将禁用点击聚焦的手势
@property (nonatomic, assign) BOOL isExposeEnabled;  ///< 是否能曝光，禁用将禁用点击曝光的手势

@property (nonatomic, strong) NSArray<AVMetadataFaceObject *> *faceMetadataObjects;  ///< 人脸识别数据

@end

NS_ASSUME_NONNULL_END
