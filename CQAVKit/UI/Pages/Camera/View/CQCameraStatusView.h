//
//  CQCameraStatusView.h
//  CQAVKit
//
//  Created by 刘超群 on 2021/11/27.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 上方状态视图，录制时间，摄像头闪光灯
@interface CQCameraStatusView : UIView


@property (nonatomic, copy) void(^flashBtnCallbackBlock)(void);  ///< flash按钮回调
@property (nonatomic, copy) void(^switchCameraBtnCallbackBlock)(void);  ///< 切换相机按钮回调

@property (nonatomic, assign) NSInteger flashMode;  ///< 闪光灯模式

@end

NS_ASSUME_NONNULL_END
