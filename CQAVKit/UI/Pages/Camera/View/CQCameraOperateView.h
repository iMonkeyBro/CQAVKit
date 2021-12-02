//
//  CQCameraOperationalView.h
//  CQAVKit
//
//  Created by 刘超群 on 2021/11/27.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 下方的操作视图，点按快门，模式切换
@interface CQCameraOperateView : UIView

@property (nonatomic, copy) void(^shutterBtnCallbackBlock)(void);  ///< 快门按钮回调

@end

NS_ASSUME_NONNULL_END
