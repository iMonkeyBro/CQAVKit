//
//  CQCameraOperationalView.h
//  CQAVKit
//
//  Created by 刘超群 on 2021/11/27.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, CQCameraMode) {
    CQCameraModePhoto = 0, ///< 拍照片
    CQCameraModeVideo = 1,  ///< 拍视频
};

/// 下方的操作视图，点按快门，模式切换
@interface CQCameraOperateView : UIView

@property (nonatomic, strong) UIButton *coverBtn;  ///< 拍摄到的封面图片

@property (nonatomic, copy) void(^shutterBtnCallbackBlock)(void);  ///< 快门按钮回调
@property (nonatomic, copy) void(^coverBtnCallbackBlock)(void);  ///< 封面按钮回调
@property (nonatomic, copy) void(^changeModeCallbackBlock)(CQCameraMode cameraMode);  ///< 模式按钮回调
@property (nonatomic, assign, readonly) CQCameraMode cameraMode;  ///< 相机模式
@property (nonatomic, copy) void(^changeFaceCallbackBlock)(BOOL isStartFace);  ///< 人脸识别按钮回调
@property (nonatomic, assign, readonly) BOOL isStartFace;  ///< 相机模式

@end

NS_ASSUME_NONNULL_END
