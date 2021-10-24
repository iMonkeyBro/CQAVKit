//
//  CQMacros.h
//  CQKit_OC
//
//  Created by 刘超群 on 2021/8/11.
//

#ifndef CQMacros_h
#define CQMacros_h

// 相对比例 - 根据模版11ProMax 414*896，顶部安全区域24，底部安全区域34，实际区域高度838
#define KSCALE_WIDTH(x) ((x) * ([UIScreen mainScreen].bounds.size.width/414.f))
#define KSCALE_HEIGHT(y) ((y) * ([UIScreen mainScreen].bounds.size.height/896.f))
// 屏幕宽度
#define KSCREEN_WIDTH [UIScreen mainScreen].bounds.size.width
#define KSCREEN_HEIGHT [UIScreen mainScreen].bounds.size.height

// 字体
#define KFONT_Medium(v) [UIFont fontWithName:@"PingFangSC-Medium" size:v]
#define KFONT_Regular(v) [UIFont fontWithName:@"PingFangSC-Regular" size:v]
#define KFONT_Semibold(v) [UIFont fontWithName:@"PingFangSC-Semibold" size:v]
#define KFONT_Helvetica(v) [UIFont fontWithName:@"Helvetica" size:v]

// 颜色
#define KRGB(x,y,z) [UIColor colorWithRed:(x/255.0) green:(y/255.0) blue:(z/255.0) alpha:1]
#define KRGBA(r,g,b,a) [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:a]
// 随机颜色
#define KRANDOM_COLOR [UIColor colorWithRed:arc4random_uniform(256) / 255.0 green:arc4random_uniform(256) / 255.0 blue:arc4random_uniform(256) / 255.0 alpha:1]

// masonry pch
#define MAS_SHORTHAND   // 去前缀
#define MAS_SHORTHAND_GLOBALS    // 默认自动装箱拆箱

// NSLog增强
#ifdef DEBUG
#define CQLog(s,...) NSLog(@"STLog--<%p %@ %s [%d]> %@",self,[[NSString stringWithFormat:@"%s",__FILE__] lastPathComponent],__FUNCTION__,__LINE__,[NSString stringWithFormat:(s), ##__VA_ARGS__]);
#else
#define CQLog(s,...)
#endif

// __weak
#define __weakObj(o) __weak typeof(o) weak##o = o;

// YY循环引用解决宏
#ifndef weakify
#if DEBUG
#if __has_feature(objc_arc)
#define weakify(object) autoreleasepool{} __weak __typeof__(object) weak##_##object = object;
#else
#define weakify(object) autoreleasepool{} __block __typeof__(object) block##_##object = object;
#endif
#else
#if __has_feature(objc_arc)
#define weakify(object) try{} @finally{} {} __weak __typeof__(object) weak##_##object = object;
#else
#define weakify(object) try{} @finally{} {} __block __typeof__(object) block##_##object = object;
#endif
#endif
#endif

#ifndef strongify
#if DEBUG
#if __has_feature(objc_arc)
#define strongify(object) autoreleasepool{} __typeof__(object) object = weak##_##object;
#else
#define strongify(object) autoreleasepool{} __typeof__(object) object = block##_##object;
#endif
#else
#if __has_feature(objc_arc)
#define strongify(object) try{} @finally{} __typeof__(object) object = weak##_##object;
#else
#define strongify(object) try{} @finally{} __typeof__(object) object = block##_##object;
#endif
#endif
#endif

// 线程
// 异步子线程
#define st_async_global_queue(block) dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), block)
// 保证异步主线程
#define st_async_main_safe(block)\
if ([NSThread isMainThread]) {\
block();\
} else {\
dispatch_async(dispatch_get_main_queue(), block);\
}


#endif /* CQMacros_h */
