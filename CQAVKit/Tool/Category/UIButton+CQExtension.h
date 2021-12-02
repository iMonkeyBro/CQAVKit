//
//  UIButton+CQExtension.h
//  CQAVKit
//
//  Created by 刘超群 on 2021/12/2.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, CQBtnStyle) {
    CQBtnStyleDefault           = 0,     ///< 为了辨别默认状态
    CQBtnStyleImgLeft           = 1,     ///< 左图右文，整体居中，设置间隙
    CQBtnStyleImgRight          = 2,     ///< 左文右图，整体居中，设置间隙
    CQBtnStyleImgTop            = 3,     ///< 上图下文，整体居中，设置间隙
    CQBtnStyleImgDown           = 4,     ///< 下图上文，整体居中，设置间隙
};

typedef void(^CQButtonTouchUpInsideBlock) (UIButton *sender);

@interface UIButton (CQExtension)

/// 布局方式
@property (nonatomic, assign) CQBtnStyle cq_btnStyle;

/// 图文间距
@property (nonatomic, assign) CGFloat cq_padding;

/// 图片距离button的边距，如果图片比较大的，此时有效果；如果图片比较小，没有效果，默认居中；
@property (nonatomic, assign) CGFloat cq_space;

/**
 快速同时设置布局方式和图文间距(图文都存在才有效)
 @param style 布局样式
 @param padding 图文间距
 */
- (void)cq_setStyle:(CQBtnStyle)style padding:(CGFloat)padding;

/**
 用block替代 -addTarget:action:forControlEvents:UIControlEventTouchUpInside
 @param block UIControlEventTouchUpInside事件回调
 */
- (void)cq_touchUpInsideBlock:(CQButtonTouchUpInsideBlock)block;

/**
 使用颜色设置按钮背景
 @param bgColor 背景色
 @param state 对应状态
 */
- (void)cq_setBackgroundColor:(UIColor *)bgColor forState:(UIControlState)state;

@end


