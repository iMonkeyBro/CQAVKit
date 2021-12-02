//
//  CQScreenTool.h
//  CQAVKit
//
//  Created by 刘超群 on 2021/12/2.
//

#import <Foundation/Foundation.h>

/**
 状态栏20
 导航栏44
 tabbar 49
 刘海屏安全区域目前有3种
 x/xs全系/11全系 顶部安全区域24，底部安全区域34
 12/Pro/Promax顶部安全区域27，底部安全区域34
 12Mini 顶部安全区域30，底部安全区域34
 */

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, CQDeviceScreenType) {
    CQDeviceScreenTypeDefault,  ///< 没刘海的设备
    CQDeviceScreenTypeIphoneX11,  ///< x/xs全系/11全系
    CQDeviceScreenTypeIphone12ProMax, ///< 12/Pro/Promax
    CQDeviceScreenTypeIphone12Mini,  ///< 12Mini
};

@interface CQScreenTool : NSObject

/// 设备屏幕类型
+ (CQDeviceScreenType)deviceScreenType;

/// 安全区域底部高度
+ (CGFloat)safeAreaBottom;

/// 安全区域顶部高度
+ (CGFloat)safeAreaTop;

/// 导航条高度 (安全区+状态栏+导航栏)
+ (CGFloat)navHeight;

/// 状态栏高度 (安全区+状态栏)
+ (CGFloat)statusBarHeight;

/// tabbar高度 (安全区+tabbar)
+ (CGFloat)tabBarHeight;


@end

NS_ASSUME_NONNULL_END
