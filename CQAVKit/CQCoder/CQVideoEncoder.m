//
//  CQVideoEncoder.m
//  CQAVKit
//
//  Created by 刘超群 on 2022/2/5.
//

#import "CQVideoEncoder.h"
#import <VideoToolbox/VideoToolbox.h>

@interface CQVideoEncoder ()
@property (nonatomic, strong) dispatch_queue_t encodeQueue;  ///< 编码队列
@property (nonatomic, strong) dispatch_queue_t callBackQueue;  ///< 回调队列
@property (nonatomic, assign) VTCompressionSessionRef encodeSession;  ///< 编码会话


@end

@implementation CQVideoEncoder
{
    long _frameID;  ///< 帧的递增标识
    BOOL _isHasSpsPps;  ///< 是否已经获取到sps/pps
}

#pragma mark - Init
- (instancetype)initWithConfig:(CQVideoCoderConfig *)config {
    if (self = [super init]) {
        _config = config;
        [self initVideoToolBox];
    }
    return self;
}

- (void)dealloc {
    if (self.encodeSession) {
        VTCompressionSessionCompleteFrames(self.encodeSession, kCMTimeInvalid);
        VTCompressionSessionInvalidate(self.encodeSession);
        CFRelease(self.encodeSession);
        self.encodeSession = NULL;
    }
}

#pragma mark - Public Func
- (void)videoEncodeWithSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    CFRetain(sampleBuffer);
    dispatch_async(_encodeQueue, ^{
        // 帧数据
        CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
        // 该帧的时间戳
        _frameID ++;
        CMTime timeStamp = CMTimeMake(_frameID, 1000);
        // 持续时间
        CMTime duration = kCMTimeInvalid;
        // 编码
        VTEncodeInfoFlags flags;
        OSStatus status = VTCompressionSessionEncodeFrame(_encodeSession, imageBuffer, timeStamp, duration, NULL, NULL, &flags);
        if (status != noErr) {
            NSLog(@"CQVideoEncoder-VTCompressionSessionEncodeFrame failed. status = %d", (int)status);
        }
        CFRelease(sampleBuffer);
    });
}

#pragma mark - VideoToolBox
- (void)initVideoToolBox {
    _frameID = 0;
    // 1 创建session（VideoToolBox中的session）
    /**
     参数1： 分配器，一般NULL 默认也是NULL
     参数2： 分辨率的width，像素为单位，如果此数据非法，编码会改为合理的值
     参数3： 分辨率的height，像素为单位，如果此数据非法，编码会改为合理的值
     参数4： 编码类型-H264:KCMVideoCodecType_H264
     参数5： 编码规范 NULL
     参数6： 原像素缓冲区，NULL，由VideoToolBox默认创建
     参数7： 压缩数据分配器 NULL
     参数8： 回调，编码完成后的回调，需要给个回调方法，也可以NULL,函数指针，指向函数名，这里填写C函数名,不知道参数点进去copy
     参数9： self 桥接过去，因为C语言函数如果想要调用OC方法，需要对象，就把self传过去，
     参数10：compressionSession
     */
    OSStatus status = VTCompressionSessionCreate(kCFAllocatorDefault, (int32_t)_config.width, (int32_t)_config.height, kCMVideoCodecType_H264, NULL, NULL, NULL, videoEncoderCallBack, (__bridge  void *_Nullable)self, &_encodeSession);
    if (status != noErr) {
        NSLog(@"CQVideoEncoder-VTCompressionSessionCreate create failed. status = %d", (int)status);
        return;
    }
    // 设置编码器属性
    // 设置实时编码
    status = VTSessionSetProperty(_encodeSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
    NSLog(@"CQVideoEncoder-VTSessionSetProperty set RealTime. return status = %d", (int)status);
    // 指定编码比特流的配置文件和级别。直播一般使用baseline，抛弃B帧，可减少由B帧带来的延时
    status = VTSessionSetProperty(_encodeSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Baseline_AutoLevel);
    NSLog(@"CQVideoEncoder-VTSessionSetProperty set ProfileLevel. return status = %d", (int)status);
    // 设置码率均值(比特率可以高于此。默认比特率为0，表示视频编码器。应该确定压缩数据的大小。注意，比特率设置只在定时时有效)
    CFNumberRef bit = (__bridge CFNumberRef)@(_config.bitrate);
    status = VTSessionSetProperty(_encodeSession, kVTCompressionPropertyKey_AverageBitRate, bit);
    NSLog(@"CQVideoEncoder-VTSessionSetProperty set AverageBitRate. return status = %d", (int)status);
    // 码率限制(只在定时时起作用)*待确认
    CFArrayRef limits = (__bridge CFArrayRef)@[@(_config.bitrate / 4), @(_config.bitrate * 4)];
    status = VTSessionSetProperty(_encodeSession, kVTCompressionPropertyKey_DataRateLimits,limits);
    NSLog(@"CQVideoEncoder-VTSessionSetProperty set DataRateLimits. return status = %d", (int)status);
    //设置关键帧间隔(GOPSize)GOP太大图像会模糊
    CFNumberRef maxKeyFrameInterval = (__bridge CFNumberRef)@(_config.fps * 2);
    status = VTSessionSetProperty(_encodeSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, maxKeyFrameInterval);
    NSLog(@"CQVideoEncoder-VTSessionSetProperty set MaxKeyFrameInterval. return status = %d", (int)status);
    //设置fps(预期)
    CFNumberRef expectedFrameRate = (__bridge CFNumberRef)@(_config.fps);
    status = VTSessionSetProperty(_encodeSession, kVTCompressionPropertyKey_ExpectedFrameRate, expectedFrameRate);
    NSLog(@"CQVideoEncoder-VTSessionSetProperty set ExpectedFrameRate. return status = %d", (int)status);
    
    //准备编码
    status = VTCompressionSessionPrepareToEncodeFrames(_encodeSession);
    if (status != noErr) {
        NSLog(@"CQVideoEncoder-VTCompressionSessionPrepareToEncodeFrames failed. status = %d", (int)status);
        return;
    }
}



#pragma mark - 编码完成回调
// startCode 长度 4
const Byte startCode[] = "\x00\x00\x00\x01";
void videoEncoderCallBack(void *outputCallbackRefCon, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags, CMSampleBufferRef sampleBuffer) {
    if (status != noErr) {
        // 有错误
        NSLog(@"CQVideoEncoder-VideoEncodeCallback: encode error, status = %d", (int)status);
        return;
    }
    if (!CMSampleBufferDataIsReady(sampleBuffer)) {
        // 数据没有准备好
        NSLog(@"CQVideoEncoder-VideoEncodeCallback: data is not ready");
        return;
    }
    // 拿到自己
    CQVideoEncoder *encoder = (__bridge CQVideoEncoder *)outputCallbackRefCon;
    // 判断是否是关键帧
    BOOL isKeyFrame = NO;
    CFArrayRef attachArr = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true);
    isKeyFrame = !CFDictionaryContainsKey(CFArrayGetValueAtIndex(attachArr, 0), kCMSampleAttachmentKey_NotSync);
    // 获取sps pps数据，只需要获取一次，保存在h264文件头即可
    if (isKeyFrame && !encoder->_isHasSpsPps) {
        
    }
}

#pragma mark - Load
- (dispatch_queue_t)encodeQueue {
    if (!_encodeQueue) {
        _encodeQueue = dispatch_queue_create("CQVideoEncoder encode queue", DISPATCH_QUEUE_SERIAL);
    }
    return _encodeQueue;
}

- (dispatch_queue_t)callBackQueue {
    if (!_callBackQueue) {
        _callBackQueue = dispatch_queue_create("CQVideoEncoder callBack queue", DISPATCH_QUEUE_SERIAL);
    }
    return _callBackQueue;
}

@end
