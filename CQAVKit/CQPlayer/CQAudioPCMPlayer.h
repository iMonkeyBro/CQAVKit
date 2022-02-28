//
//  CQAudioPCMPlayer.h
//  CQAVKit
//
//  Created by 刘超群 on 2022/2/28.
//

#import <Foundation/Foundation.h>
#import "CQCoderConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface CQAudioPCMPlayer : NSObject

@property (nonatomic, strong, readonly) CQAudioCoderConfig *config;  ///< 配置信息

/**
 唯一初始化函数
 @param config 编码配置信息
 */
- (instancetype)initWithConfig:(CQAudioCoderConfig *)config;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/// 播放pcm
- (void)playPCMData:(NSData *)data;
/// 设置音量增量 0.0 - 1.0
- (void)setupVoice:(Float32)gain;
/// 销毁
- (void)dispose;

@end

NS_ASSUME_NONNULL_END
