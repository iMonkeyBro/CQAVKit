//
//  CQVideoDecoder.h
//  CQAVKit
//
//  Created by 刘超群 on 2022/2/5.
//

#import <Foundation/Foundation.h>
#import <CoreVideo/CVPixelBuffer.h>
#import "CQCoderConfig.h"

@class CQVideoDecoder;

NS_ASSUME_NONNULL_BEGIN

@protocol CQVideoDecoderDelegate <NSObject>
@required
/**
 解码成功回调
 @param pixelBuffer 解码后的数据(未编码前的数据，可以通过OpenGL显示)
 */
- (void)videoDecoder:(CQVideoDecoder *)videoDecoder didDecodeSuccessWithPixelBuffer:(CVPixelBufferRef)pixelBuffer;

@end

/**
 视频解码工具
 @discussion 二次封装VideoToolBox解码 h264硬解码器 (编码和回调均在异步队列执行)
 */
@interface CQVideoDecoder : NSObject

/**
 唯一初始化函数
 @param config 编码配置信息
 */
- (instancetype)initWithConfig:(CQVideoCoderConfig *)config;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@property (nonatomic, strong, readonly) CQVideoCoderConfig *config;  ///< 配置信息

@property (nonatomic, weak) id<CQVideoDecoderDelegate> delegate;  ///< 代理

/**
 视频解码
 @param h264Data h264视频数据
 */
- (void)videoDecodeWithH264Data:(NSData *)h264Data;

@end

NS_ASSUME_NONNULL_END
