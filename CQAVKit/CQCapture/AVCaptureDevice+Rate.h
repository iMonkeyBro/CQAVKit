//
//  AVCaptureDevice+CQ.h
//  Learn_AVFoundation
//
//  Created by 刘超群 on 2022/6/30.
//

#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - CaptureDeviceRateInfo
/// 捕捉设备的帧率信息
@interface CQCaptureDeviceRateInfo : NSObject
@property (nonatomic, strong, readonly) AVCaptureDeviceFormat *format;
@property (nonatomic, strong, readonly) AVFrameRateRange *frameRateRange;
@property(nonatomic, readonly) BOOL isHighFrameRate;

+ (instancetype)infoWithFormat:(AVCaptureDeviceFormat *)format
               frameRateRange:(AVFrameRateRange *)frameRateRange;

- (instancetype)initWithFormat:(AVCaptureDeviceFormat *)format frameRateRange:(AVFrameRateRange *)frameRateRange;

@end

#pragma mark - 开启捕捉
@interface AVCaptureDevice (Rate)

@property (nonatomic, readonly) BOOL isSupportsHighFrameRateCapture;  ///< 是否支持高帧率捕获

/// 开启最大帧率捕获
- (BOOL)enableMaxFrameRateCapture:(NSError **)error;

/// 开启帧率捕获
- (BOOL)enableFrameRateCapturWithRateInfo:(CQCaptureDeviceRateInfo *)rateInfo error:(NSError **)error;

/// 获取捕捉信息
- (NSArray<CQCaptureDeviceRateInfo *> *)getRateInfos;

@end

NS_ASSUME_NONNULL_END
