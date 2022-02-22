//
//  CQVideoEncoder.m
//  CQAVKit
//
//  Created by 刘超群 on 2022/2/5.
//

/**
 思路
 1 初始化编码会话
 2 公开函数接收包含`CVPixelBuffer`的`CMSampleBufferRef`
 3 输入到编码器
 4 在编码回调函数里将spspps以及数据回调，外界拿到回调可写入成视频文件
 5 销毁编码会话
 
 用到的三个核心函数
 创建解码会话  VTCompressionSessionCreate
 编码 将CVImageBufferRef转成存储了CMBlockBuffer的CMSampleBuffer     VTCompressionSessionEncodeFrame
 销毁解码会话  VTCompressionSessionInvalidate，销毁前需要先VTCompressionSessionCompleteFrames
 */

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
    BOOL _isHasSpsPps;  ///< 标记是否已经获取到sps/pps
}

#pragma mark - Init
- (instancetype)initWithConfig:(CQVideoCoderConfig *)config {
    if (self = [super init]) {
        _config = config;
        [self initEncoderSession];
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
        // 帧数据 未编码的数据
        CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
        // 该帧的时间戳
        self->_frameID ++;
        CMTime timeStamp = CMTimeMake(self->_frameID, 1000);
        // 持续时间
        CMTime duration = kCMTimeInvalid;
        // 编码
        VTEncodeInfoFlags flags;
        OSStatus status = VTCompressionSessionEncodeFrame(self->_encodeSession, imageBuffer, timeStamp, duration, NULL, NULL, &flags);
        if (status != noErr) {
            NSLog(@"CQVideoEncoder-VTCompressionSessionEncodeFrame failed. status = %d", (int)status);
        }
        CFRelease(sampleBuffer);
    });
}

#pragma mark - 初始化编码会话 设置属性
/// 初始化编码会话 设置属性
- (void)initEncoderSession {
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
    // 拿到self
    CQVideoEncoder *encoder = (__bridge CQVideoEncoder *)outputCallbackRefCon;
    // 判断是否是关键帧
    BOOL isKeyFrame = NO;
    CFArrayRef attachArr = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true);
    isKeyFrame = !CFDictionaryContainsKey(CFArrayGetValueAtIndex(attachArr, 0), kCMSampleAttachmentKey_NotSync);
    // 获取sps pps数据，只需要获取一次，保存在h264文件头即可
    if (isKeyFrame && !encoder->_isHasSpsPps) {
        size_t spsSize, spsCount;
        size_t ppsSize, ppsCount;
        const uint8_t *spsData, *ppsData;
        // 获取图像源像素格式
        CMFormatDescriptionRef formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer);
        // 获取sps
        OSStatus status1 = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDesc, 0, &spsData, &spsSize, &spsCount, 0);
        // 获取pps
        OSStatus status2 = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDesc, 1, &ppsData, &ppsSize, &ppsCount, 0);
        // 判断sps/pps获取成功
        if (status1 == noErr && status2 == noErr) {
            encoder->_isHasSpsPps = YES;
            NSLog(@"CQVideoEncoder-videoEncoderCallBack：Get sps、pps success");
            
            // sps 转NSData
            NSMutableData *sps = [NSMutableData dataWithCapacity:4 + spsSize];
            [sps appendBytes:startCode length:4];// 注意加入起始位
            [sps appendBytes:spsData length:spsSize];
            // pps 转NSData
            NSMutableData *pps = [NSMutableData dataWithCapacity:4 + ppsSize];
            [pps appendBytes:startCode length:4];// 注意加入起始位
            [pps appendBytes:ppsData length:ppsSize];
            
            dispatch_async(encoder.callBackQueue, ^{
                // 回调
                if (encoder.delegate && [encoder.delegate respondsToSelector:@selector(videoEncoder:didEncodeWithSps:pps:)]) {
                    [encoder.delegate videoEncoder:encoder didEncodeWithSps:sps pps:pps];
                }
            });
        } else {
            NSLog(@"CQVideoEncoder-videoEncodeCallback： Get sps/pps failed spsStatus=%d, ppsStatus=%d", (int)status1, (int)status2);
        }
    }
    
    // 获取NALU数据
    size_t lengthAtOffset, totalLength;
    char *dataPoint;
    // 获取blockBuffer sampleBuffer 转CMBlockBufferRef
    CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    // 获取单个长度 总长度 首地址
    /**
     参数1  数据
     参数2  偏移量0
     参数3  获取单个数据长度
     参数4  获取总数据长度
     参数5  指针指向
     获取数据块总大小，单个数据大小，数据块首地址，---理解数组
     */
    OSStatus error = CMBlockBufferGetDataPointer(blockBuffer, 0, &lengthAtOffset, &totalLength, &dataPoint);
    if (error != kCMBlockBufferNoErr) {
        NSLog(@"CQVideoEncoder-videoEncodeCallback: get datapoint failed, status = %d", (int)error);
        return;
    }
    
    size_t offet = 0;
    // 返回的nalu数据前四个字节不是0001的startcode(不是系统端的0001)，而是大端模式的帧长度length
    const int lengthInfoSize = 4;
    // 循环获取nalu数据 (通过移动下标的方式，循环读取数据)
    while (offet < totalLength - lengthInfoSize) {
        uint32_t naluLength = 0;
        // 获取nalu 数据长度
        memcpy(&naluLength, dataPoint + offet, lengthInfoSize);
        // 大端转系统端
        naluLength = CFSwapInt32BigToHost(naluLength);
        // 获取到编码好的视频数据
        NSMutableData *data = [NSMutableData dataWithCapacity:4 + naluLength];
        [data appendBytes:startCode length:4];
        [data appendBytes:dataPoint + offet + lengthInfoSize length:naluLength];
        
        // 将NALU数据回调到代理中
        dispatch_async(encoder.callBackQueue, ^{
            if (encoder.delegate && [encoder.delegate respondsToSelector:@selector(videoEncoder:didEncodeSuccessWithH264Data:)]) {
                [encoder.delegate videoEncoder:encoder didEncodeSuccessWithH264Data:data];
            }
        });
        
        // 移动下标，继续读取下一个数据
        offet += lengthInfoSize + naluLength;
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
