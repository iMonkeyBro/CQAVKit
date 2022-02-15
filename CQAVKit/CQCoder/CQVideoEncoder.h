//
//  CQVideoEncoder.h
//  CQAVKit
//
//  Created by 刘超群 on 2022/2/5.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CMSampleBuffer.h>
#import "CQCoderConfig.h"

@class CQVideoEncoder;

NS_ASSUME_NONNULL_BEGIN

@protocol CQVideoEncoderDelegate <NSObject>

/**
 当编码完成时
 @param h264Data 编码完成的H264数据
 */
- (void)videoEncoder:(CQVideoEncoder *)videoEncoder didEncodeSuccessWithH264Data:(NSData *)h264Data;

/**
 编码工具编码时
 @param sps sps数据
 @param pps pps数据
 */
- (void)videoEncoder:(CQVideoEncoder *)videoEncoder didEncodeWithSps:(NSData *)sps pps:(NSData *)pps;

@end

/**
 视频编码工具
 @discussion 二次封装VideoToolBox编码 h264硬编码器 (编码和回调均在异步队列执行)
 */
@interface CQVideoEncoder : NSObject

/**
 唯一初始化函数
 @param config 编码配置信息
 */
- (instancetype)initWithConfig:(CQVideoCoderConfig *)config;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@property (nonatomic, strong, readonly) CQVideoCoderConfig *config;  ///< 配置信息

@property (nonatomic, weak) id<CQVideoEncoderDelegate> delegate;  ///< 代理

/**
 视频编码
 @param sampleBuffer buffer
 */
- (void)videoEncodeWithSampleBuffer:(CMSampleBufferRef)sampleBuffer;

@end

NS_ASSUME_NONNULL_END
