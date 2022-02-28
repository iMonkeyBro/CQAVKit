//
//  CQAudioDecoder.h
//  CQAVKit
//
//  Created by 刘超群 on 2022/2/27.
//

#import <Foundation/Foundation.h>
#import "CQCoderConfig.h"

@class CQAudioDecoder;

NS_ASSUME_NONNULL_BEGIN

@protocol CQAudioDecoderDelegate <NSObject>
@required
/**
 解码成功回调
 @param pcmData 解码后的数据
 */
- (void)audioDecoder:(CQAudioDecoder *)audioDecoder didDecodeSuccessWithPCMData:(NSData *)pcmData;

@end

@interface CQAudioDecoder : NSObject

@property (nonatomic, strong, readonly) CQAudioCoderConfig *config;  ///< 配置信息

@property (nonatomic, weak) id<CQAudioDecoderDelegate> delegate;  ///< 代理

/**
 唯一初始化函数
 @param config 编码配置信息
 */
- (instancetype)initWithConfig:(CQAudioCoderConfig *)config;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/**
 视频解码
 @param aacData aac音频数据
 */
- (void)audioDecodeWithAACData:(NSData *)aacData;

@end

NS_ASSUME_NONNULL_END
