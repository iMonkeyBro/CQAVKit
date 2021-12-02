//
//  CQScreenTool.m
//  CQAVKit
//
//  Created by 刘超群 on 2021/12/2.
//

#import "CQScreenTool.h"

#define KSCREEN_WIDTH [UIScreen mainScreen].bounds.size.width
#define KSCREEN_HEIGHT [UIScreen mainScreen].bounds.size.height

@implementation CQScreenTool

/// 设备屏幕类型
+ (CQDeviceScreenType)deviceScreenType {
    if (@available(iOS 11.0, *)) {
        if ((KSCREEN_HEIGHT == 812 && KSCREEN_WIDTH == 375) || (KSCREEN_HEIGHT == 896 && KSCREEN_WIDTH == 414)) {
            return CQDeviceScreenTypeIphoneX11;
        } else if ((KSCREEN_HEIGHT == 844 && KSCREEN_WIDTH == 390) || (KSCREEN_HEIGHT == 926 && KSCREEN_WIDTH == 428)) {
            return CQDeviceScreenTypeIphone12ProMax;
        } else if (KSCREEN_HEIGHT == 780 && KSCREEN_WIDTH == 360) {
            return CQDeviceScreenTypeIphone12Mini;
        } else {
            return CQDeviceScreenTypeDefault;
        }
    } else {
        return CQDeviceScreenTypeDefault;
    }
}

/// 安全区域底部高度
+ (CGFloat)safeAreaBottom {
    if ([CQScreenTool deviceScreenType] == CQDeviceScreenTypeDefault) {
        return 0;
    }else{
        return 34.0;
    }
}

/// 安全区域顶部高度
+ (CGFloat)safeAreaTop {
    CQDeviceScreenType type = [CQScreenTool deviceScreenType];
    if (type == CQDeviceScreenTypeDefault) {
        return 0;
    } else if (type == CQDeviceScreenTypeIphoneX11) {
        return 24;
    } else if (type == CQDeviceScreenTypeIphone12ProMax) {
        return 27;
    } else if (type == CQDeviceScreenTypeIphone12Mini) {
        return 30;
    } else {
        return 0;
    }
}

/// 导航条高度 (安全区+状态栏+导航栏)
+ (CGFloat)navHeight {
    return [CQScreenTool statusBarHeight] + 44.0;
}

/// 状态栏高度 (安全区+状态栏)
+ (CGFloat)statusBarHeight {
    return [CQScreenTool safeAreaTop] + 20.0;

}

/// tabbar高度 (安全区+tabbar)
+ (CGFloat)tabBarHeight {
    if ([CQScreenTool deviceScreenType] == CQDeviceScreenTypeDefault) {
        return 49.0;
    }else{
        return 83.0;
    }
}


@end
