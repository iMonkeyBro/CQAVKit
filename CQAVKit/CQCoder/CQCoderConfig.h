//
//  CQCoderConfig.h
//  CQAVKit
//
//  Created by 刘超群 on 2022/2/5.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CQCoderConfig : NSObject

@end

@interface CQVideoCoderConfig : NSObject

@property (nonatomic, assign) NSInteger width; ///< 可选，系统支持的分辨率，采集分辨率的宽
@property (nonatomic, assign) NSInteger height; ///< 可选，系统支持的分辨率，采集分辨率的高
@property (nonatomic, assign) NSInteger bitrate; ///< 自由设置
@property (nonatomic, assign) NSInteger fps; ///< 自由设置 25

+ (instancetype)defaultConifg;

@end

@interface CQAudioCoderConfig : NSObject

@property (nonatomic, assign) NSInteger bitrate; ///< 码率，默认96000
@property (nonatomic, assign) NSInteger channelCount; ///< 声道，默认1
@property (nonatomic, assign) NSInteger sampleRate; ///< 采样率，默认44100
@property (nonatomic, assign) NSInteger sampleSize; ///< 采样点量化，默认16

+ (instancetype)defaultConifg;

@end

NS_ASSUME_NONNULL_END
