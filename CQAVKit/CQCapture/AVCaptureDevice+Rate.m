//
//  AVCaptureDevice+CQ.m
//  Learn_AVFoundation
//
//  Created by 刘超群 on 2022/6/30.
//

#import "AVCaptureDevice+Rate.h"

#pragma mark - CQQualityOfService


@implementation CQCaptureDeviceRateInfo

+ (instancetype)infoWithFormat:(AVCaptureDeviceFormat *)format
               frameRateRange:(AVFrameRateRange *)frameRateRange {
    return [[self alloc] initWithFormat:format frameRateRange:frameRateRange];
}

- (instancetype)initWithFormat:(AVCaptureDeviceFormat *)format frameRateRange:(AVFrameRateRange *)frameRateRange {
    if (self = [super init]) {
        _format = format;
        _frameRateRange = frameRateRange;
    }
    return self;
}

- (BOOL)isHighFrameRate {
    return self.frameRateRange.maxFrameRate > 60.0f;
}

@end

#pragma mark - AVCaptureDevice Extension
@implementation AVCaptureDevice (Rate)

#pragma mark - Public Func
- (BOOL)isSupportsHighFrameRateCapture {
    // 查看是否支持AVMediaTypeVideo判断是不是视频设备，不是一定不支持高帧率
    if (![self hasMediaType:AVMediaTypeVideo]) return NO;
    return [self buildMaxCaptureDeviceRateInfo].isHighFrameRate;
}

// 开启最大帧率捕获
- (BOOL)enableMaxFrameRateCapture:(NSError *__autoreleasing  _Nullable *)error {
    CQCaptureDeviceRateInfo *rateInfo = [self buildMaxCaptureDeviceRateInfo];
    // 不支持高帧率直接返回错误
    if (!rateInfo.isHighFrameRate) {
        if (error) {
            NSString *message = @"Device does not support high FPS capture";
            NSDictionary *userInfo = @{NSLocalizedDescriptionKey : message};
            *error = [NSError errorWithDomain:@"Error" code:404 userInfo:userInfo];
        }
        return NO;
    }
    if ([self lockForConfiguration:error]) {
        self.activeFormat = rateInfo.format;
        self.activeVideoMinFrameDuration = rateInfo.frameRateRange.minFrameDuration;
        self.activeVideoMaxFrameDuration = rateInfo.frameRateRange.minFrameDuration;
        [self unlockForConfiguration];
        return YES;
    }
    return NO;
}

- (BOOL)enableFrameRateCapturWithRateInfo:(CQCaptureDeviceRateInfo *)rateInfo error:(NSError **)error {
    if ([self lockForConfiguration:error]) {
        self.activeFormat = rateInfo.format;
        self.activeVideoMinFrameDuration = rateInfo.frameRateRange.minFrameDuration;
        self.activeVideoMaxFrameDuration = rateInfo.frameRateRange.minFrameDuration;
        [self unlockForConfiguration];
        return YES;
    }
    return NO;
}


- (NSArray<CQCaptureDeviceRateInfo *> *)getRateInfos {
    NSMutableArray<CQCaptureDeviceRateInfo *> *tempArr = [NSMutableArray array];
    for (AVCaptureDeviceFormat *deviceFormat in self.formats) {
        // 拿到类型，这里需要kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange 格式
        FourCharCode codecType = CMVideoFormatDescriptionGetCodecType(deviceFormat.formatDescription);
        if (codecType == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) {
            for (AVFrameRateRange *range in deviceFormat.videoSupportedFrameRateRanges) {
                [tempArr addObject:[CQCaptureDeviceRateInfo infoWithFormat:deviceFormat frameRateRange:range]];
            }
        }
    }
    return tempArr;
}


#pragma mark - Private Func
/// 从self.formats 查找信息构建CQQualityOfService
- (CQCaptureDeviceRateInfo *)buildMaxCaptureDeviceRateInfo {
    AVCaptureDeviceFormat *maxFormat;
    AVFrameRateRange *maxFrameRateRange;
    for (AVCaptureDeviceFormat *deviceFormat in self.formats) {
        // 拿到类型，这里需要kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange 格式
        FourCharCode codecType = CMVideoFormatDescriptionGetCodecType(deviceFormat.formatDescription);
        if (codecType == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) {
            // 遍历，maxFrameRate大于当前则赋值
            for (AVFrameRateRange *range in deviceFormat.videoSupportedFrameRateRanges) {
                if (range.maxFrameRate > maxFrameRateRange.maxFrameRate) {
                    maxFrameRateRange = range;
                    maxFormat = deviceFormat;
                }
            }
        }
    }
    
    return [CQCaptureDeviceRateInfo infoWithFormat:maxFormat frameRateRange:maxFrameRateRange];
}




@end
