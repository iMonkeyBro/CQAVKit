//
//  CQAudioEncoder.h
//  CQAVKit
//
//  Created by 刘超群 on 2022/2/27.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CMSampleBuffer.h>
#import "CQCoderConfig.h"

@class CQAudioEncoder;

NS_ASSUME_NONNULL_BEGIN

@protocol CQAudioEncoderDelegate <NSObject>
@required
/**
 当编码完成时
 @param aacData 编码完成的aac数据
 */
- (void)audioEncoder:(CQAudioEncoder *)audioEncoder didEncodeSuccessWithAACData:(NSData *)aacData;

@end

/**
 视频编码工具
 @discussion 二次封装AudioToolBox编码 (编码和回调均在异步队列执行)
 */
@interface CQAudioEncoder : NSObject

/**
 唯一初始化函数
 @param config 编码配置信息
 */
- (instancetype)initWithConfig:(CQAudioCoderConfig *)config;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@property (nonatomic, strong, readonly) CQAudioCoderConfig *config;  ///< 配置信息

@property (nonatomic, weak) id<CQAudioEncoderDelegate> delegate;  ///< 代理

/**
 音频编码
 @param sampleBuffer buffer
 */
- (void)audioEncodeWithSampleBuffer:(CMSampleBufferRef)sampleBuffer;

@end

NS_ASSUME_NONNULL_END
