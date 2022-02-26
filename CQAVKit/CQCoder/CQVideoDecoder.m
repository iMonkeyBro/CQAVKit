//
//  CQVideoDecoder.m
//  CQAVKit
//
//  Created by 刘超群 on 2022/2/5.
//

/**
 思路
 1 解析数据(NALU Unit) 判断I/P/B帧
 2 初始化解码器
 3 将解析后的H264 NALU Unit 输入到解码器
 4 在解码完成的回调函数里，输出解码后的数据
 5 解码后的数据回调(可以使用OpenGL ES显示)
 
 核心函数:
 1 创建解码会话， VTDecompressionSessionCreate
 2 解码一个frame，VTDecompressionSessionDecodeFrame
 3 销毁解码会话  VTDecompressionSessionInvalidate
 
 原理分析:
 H264原始码流 --> NALU
 I帧 关键帧，保留了一张完整的视频帧，解码的关键！
 P帧 向前参考帧，差异数据，解码需要依赖I帧
 B帧 双向参考帧，解码需要同时依赖I帧和P帧
 如果H264码流中I帧错误/丢失，就会导致错误传递，P和B无法单独完成解码。会有花屏现象产生
 使用VideoToolBox 硬编码时，第一帧并不是I，而是手动加入的SPS/PPS
 解码时，需要使用SPS/PPS来对解码器进行初始化。
 
 解码思路：
 1 解析数据
 NALU是一个接一个输入的，实时解码。
 NALU数据，前4个字节起始位，标识一个NALU的开始，从第五位开始获取，第五位才是NALU数据类型
 获取第五位数据，转化十进制，然后判断数据类型。
 判断好类型，才能将NALU送入解码器，SPS、PPS不需要放入解码器，只需要用来构建解码器
 
 2 VideoToolBox
 基于CoreMedia CoreVideo CoreFoundation的C语言API
 一共有三种类型会话，编码会话，解码会话，像素移动
 从CoreMedia，CoreVideo衍生出时间或帧管理数据类型，CMTime，CVPixelBuffer
 CMVideoFormatDescription 视频格式描述，包含视频尺寸等信息
 */

#import "CQVideoDecoder.h"
#import <VideoToolbox/VideoToolbox.h>

@interface CQVideoDecoder ()
@property (nonatomic, strong) dispatch_queue_t decodeQueue;  ///< 解码队列
@property (nonatomic, strong) dispatch_queue_t callBackQueue;  ///< 回调队列
@property (nonatomic, assign) VTDecompressionSessionRef decodeSession;  ///< 解码会话

@end

@implementation CQVideoDecoder
{
    uint8_t *_sps;
    long _spsSize;
    uint8_t *_pps;
    long _ppsSize;
    CMVideoFormatDescriptionRef _videoDesc;  ///< 视频格式描述
}

#pragma mark - Init
- (instancetype)initWithConfig:(CQVideoCoderConfig *)config {
    if (self = [super init]) {
        _config = config;
    }
    return self;
}

- (void)dealloc {
    if (self.decodeSession) {
        VTDecompressionSessionInvalidate(self.decodeSession);
        CFRelease(self.decodeSession);
        self.decodeSession = NULL;
    }
}

#pragma mark - Public Func
- (void)videoDecodeWithH264Data:(NSData *)h264Data; {
    dispatch_async(self.decodeQueue, ^{
        // 获取帧二进制数据
        uint8_t *nalu = (uint8_t *)h264Data.bytes;
        [self decodeNaluData:nalu withSize:(uint32_t)h264Data.length];
    });
}


#pragma mark - Private Func
/// 解析NALU数据
- (void)decodeNaluData:(uint8_t *)naluData withSize:(uint32_t)frameSize {
    // 数据类型:frame，前四个字节为NALU开始码，00 00 00 01
    // 第五位标识数据类型，转化十进制，7表示sps，8表示pps，5表示I帧
    int type = (naluData[4] & 0x1F);
    
    // 将NALU的开始码转为4字节大端NALU的长度信息
    uint32_t naluSize = frameSize - 4;
    uint8_t *pNaluSize = (uint8_t *)(&naluSize);
    naluData[0] = *(pNaluSize + 3);
    naluData[1] = *(pNaluSize + 2);
    naluData[2] = *(pNaluSize + 1);
    naluData[3] = *(pNaluSize);
    CVPixelBufferRef pixelBuffer = NULL;
    
    /**
     第一次解析时: 初始化解码器initDecoder
     判断数据类型，帧数据调用decode:(uint8_t *)frame
     sps/pps数据，则给成员变量赋值保存
     */
    switch (type) {
        case 0x05:
            // 关键帧
            if ([self initDecoderSession]) {
                pixelBuffer = [self decode:naluData withSize:frameSize];
            }
            break;
        case 0x06:
            // 增强型
            break;
        case 0x07:
            // sps
            _spsSize = naluSize;
            _sps = malloc(_spsSize);
            // 从下标4(也就是第五个元素)开始复制数据
            memcpy(_sps, &naluData[4], _spsSize);
            break;
        case 0x08:
            // pps
            _ppsSize = naluSize;
            _pps = malloc(_ppsSize);
            // 从下标4(也就是第五个元素)开始复制数据
            memcpy(_pps, &naluData[4], _ppsSize);
            break;
        default:
            // 其他帧（1-5）
            if ([self initDecoderSession]) {
                pixelBuffer = [self decode:naluData withSize:frameSize];
            }
            break;
    }
}

/// 初始化解码会话
- (BOOL)initDecoderSession {
    if (self.decodeSession) return YES;
    const uint8_t * const parameterSetPointers[2] = {_sps, _pps};
    const size_t parameterSetSizes[2] = {_spsSize, _ppsSize};
    int naluHeaderLen = 4;  // 大端模式起始位长度
    
    /**
     根据sps pps设置解码参数
     param kCFAllocatorDefault 分配器
     param 解码参数个数 ，SPS PPS 所以填2
     param parameterSetPointers 参数集指针(地址)
     param parameterSetSizes 参数集大小
     param naluHeaderLen 起始位长度
     param _decodeDesc 解码器描述
     return 状态
     */
    OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault, 2, parameterSetPointers, parameterSetSizes, naluHeaderLen, &_videoDesc);
    if (status != noErr) {
        NSLog(@"CQVideoDecoder-Video Format DecodeSession create H264ParameterSets(sps, pps) failed status= %d", (int)status);
        return NO;
    }
    
    /**
     解码参数:
    * kCVPixelBufferPixelFormatTypeKey:摄像头的输出数据格式
     kCVPixelBufferPixelFormatTypeKey，已测可用值为
        kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange，即420v
        kCVPixelFormatType_420YpCbCr8BiPlanarFullRange，即420f
        kCVPixelFormatType_32BGRA，iOS在内部进行YUV至BGRA格式转换
     YUV420一般用于标清视频，YUV422用于高清视频，这里的限制让人感到意外。但是，在相同条件下，YUV420计算耗时和传输压力比YUV422都小。
     
    * kCVPixelBufferWidthKey/kCVPixelBufferHeightKey: 视频源的分辨率 width*height
     * kCVPixelBufferOpenGLCompatibilityKey : 它允许在 OpenGL 的上下文中直接绘制解码后的图像，而不是从总线和 CPU 之间复制数据。这有时候被称为零拷贝通道，因为在绘制过程中没有解码的图像被拷贝.
     
     */
    NSDictionary *destinationPixBufferAttrs =
    @{
      (id)kCVPixelBufferPixelFormatTypeKey: [NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange], //iOS上 nv12(uvuv排布) 而不是nv21（vuvu排布）
      (id)kCVPixelBufferWidthKey: [NSNumber numberWithInteger:_config.width],
      (id)kCVPixelBufferHeightKey: [NSNumber numberWithInteger:_config.height],
      (id)kCVPixelBufferOpenGLCompatibilityKey: [NSNumber numberWithBool:true]
      };
    
    // 解码回调设置
    /**
     VTDecompressionOutputCallbackRecord 是一个简单的结构体，它带有一个指针 (decompressionOutputCallback)，指向帧解压完成后的回调方法。你需要提供可以找到这个回调方法的实例 (decompressionOutputRefCon)。VTDecompressionOutputCallback 回调方法包括七个参数：
            参数1: 回调的引用
            参数2: 帧的引用
            参数3: 一个状态标识 (包含未定义的代码)
            参数4: 指示同步/异步解码，或者解码器是否打算丢帧的标识
            参数5: 实际图像的缓冲
            参数6: 出现的时间戳
            参数7: 出现的持续时间
     */
    VTDecompressionOutputCallbackRecord callbackRecord;
    callbackRecord.decompressionOutputCallback = videoDecoderCallBack;
    callbackRecord.decompressionOutputRefCon = (__bridge void * _Nullable)(self);
    
    // 创建session
    
    /**
     @function    VTDecompressionSessionCreate
     @abstract    创建用于解压缩视频帧的会话。
     @discussion  解压后的帧将通过调用OutputCallback发出
     @param    allocator  内存的会话。通过使用默认的kCFAllocatorDefault的分配器。
     @param    videoFormatDescription 描述源视频帧
     @param    videoDecoderSpecification 指定必须使用的特定视频解码器.NULL
     @param    destinationImageBufferAttributes 描述源像素缓冲区的要求 NULL
     @param    outputCallback 使用已解压缩的帧调用的回调
     @param    decompressionSessionOut 指向一个变量以接收新的解压会话
     */
    status = VTDecompressionSessionCreate(kCFAllocatorDefault, _videoDesc, NULL, (__bridge CFDictionaryRef _Nullable)(destinationPixBufferAttrs), &callbackRecord, &_decodeSession);
    if (status != noErr) {
        NSLog(@"Video hard DecodeSession create failed status= %d", (int)status);
        return NO;
    }
    
    // 设置解码会话属性
    // 实时解码
    status = VTSessionSetProperty(self.decodeSession, kVTDecompressionPropertyKey_RealTime,kCFBooleanTrue);
    NSLog(@"Vidoe hard decodeSession set property RealTime status = %d", (int)status);
    
    return YES;
}

/// 接受帧数据解码
- (CVPixelBufferRef)decode:(uint8_t *)frame withSize:(uint32_t)frameSize {
    CVPixelBufferRef outputPixelBuffer = NULL;
    CMBlockBufferRef blockBuffer = NULL;
    CMBlockBufferFlags flag0 = 0;
    
    // 创建blockBuffer
    /*!
     参数1: structureAllocator kCFAllocatorDefault
     参数2: memoryBlock  frame
     参数3: frame size
     参数4: blockAllocator: Pass NULL
     参数5: customBlockSource Pass NULL
     参数6: offsetToData  数据偏移
     参数7: dataLength 数据长度
     参数8: flags 功能和控制标志
     参数9: newBBufOut blockBuffer地址,不能为空
     */
    OSStatus status = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault, frame, frameSize, kCFAllocatorNull, NULL, 0, frameSize, flag0, &blockBuffer);
    
    if (status != kCMBlockBufferNoErr) {
        NSLog(@"Video hard decode create blockBuffer error code=%d", (int)status);
        return outputPixelBuffer;
    }
    
    CMSampleBufferRef sampleBuffer = NULL;
    const size_t sampleSizeArray[] = {frameSize};
    
    // 创建sampleBuffer
    /*
     参数1: allocator 分配器,使用默认内存分配, kCFAllocatorDefault
     参数2: blockBuffer.需要编码的数据blockBuffer.不能为NULL
     参数3: formatDescription,视频输出格式
     参数4: numSamples.CMSampleBuffer 个数.
     参数5: numSampleTimingEntries 必须为0,1,numSamples
     参数6: sampleTimingArray.  数组.为空
     参数7: numSampleSizeEntries 默认为1
     参数8: sampleSizeArray
     参数9: sampleBuffer对象
     */
    status = CMSampleBufferCreateReady(kCFAllocatorDefault, blockBuffer, _videoDesc, 1, 0, NULL, 1, sampleSizeArray, &sampleBuffer);
    
    if (status != noErr || !sampleBuffer) {
        NSLog(@"Video hard decode create sampleBuffer failed status=%d", (int)status);
        CFRelease(blockBuffer);
        return outputPixelBuffer;
    }
    
    // 解码
    // 向视频解码器提示使用低功耗模式是可以的
    VTDecodeFrameFlags flag1 = kVTDecodeFrame_1xRealTimePlayback;
    // 异步解码
    VTDecodeInfoFlags  infoFlag = kVTDecodeInfo_Asynchronous;
    // 解码数据
    /*
     参数1: 解码session
     参数2: 源数据 包含一个或多个视频帧的CMsampleBuffer
     参数3: 解码标志
     参数4: 解码后数据outputPixelBuffer
     参数5: 同步/异步解码标识
     */
    status = VTDecompressionSessionDecodeFrame(_decodeSession, sampleBuffer, flag1, &outputPixelBuffer, &infoFlag);
    
    if (status == kVTInvalidSessionErr) {
        NSLog(@"Video hard decode  InvalidSessionErr status =%d", (int)status);
    } else if (status == kVTVideoDecoderBadDataErr) {
        NSLog(@"Video hard decode  BadData status =%d", (int)status);
    } else if (status != noErr) {
        NSLog(@"Video hard decode failed status =%d", (int)status);
    }
    CFRelease(sampleBuffer);
    CFRelease(blockBuffer);
    return outputPixelBuffer;
}

#pragma mark - VideoToolBox解码完成回调
void videoDecoderCallBack(void * CM_NULLABLE decompressionOutputRefCon, void * CM_NULLABLE sourceFrameRefCon, OSStatus status, VTDecodeInfoFlags infoFlags, CM_NULLABLE CVImageBufferRef imageBuffer, CMTime presentationTimeStamp, CMTime presentationDuration ) {
    if (status != noErr) {
        NSLog(@"Video hard decode callback error status=%d", (int)status);
        return;
    }
    // 拿到解码后的数据sourceFrameRefCon -> CVPixelBufferRef
    CVPixelBufferRef *outputPixelBuffer = (CVPixelBufferRef *)sourceFrameRefCon;
    *outputPixelBuffer = CVPixelBufferRetain(imageBuffer);
    // 获取self
    CQVideoDecoder *decoder = (__bridge CQVideoDecoder *)(decompressionOutputRefCon);
    // 回调
    dispatch_async(decoder.callBackQueue, ^{
        if (decoder.delegate && [decoder.delegate respondsToSelector:@selector(videoDecoder:didDecodeSuccessWithPixelBuffer:)]) {
            [decoder.delegate videoDecoder:decoder didDecodeSuccessWithPixelBuffer:imageBuffer];
        }
        CVPixelBufferRelease(imageBuffer);
    });
}

#pragma mark - Load
- (dispatch_queue_t)decodeQueue {
    if (!_decodeQueue) {
        _decodeQueue = dispatch_queue_create("CQVideoDncoder decode queue", DISPATCH_QUEUE_SERIAL);
    }
    return _decodeQueue;
}

- (dispatch_queue_t)callBackQueue {
    if (!_callBackQueue) {
        _callBackQueue = dispatch_queue_create("CQVideoDncoder callBack queue", DISPATCH_QUEUE_SERIAL);
    }
    return _callBackQueue;
}


@end
