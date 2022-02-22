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
 5 解码后数据的显示(OpenGL ES)
 
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
    CMVideoFormatDescriptionRef _videoDesc;
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
    if (self.decodeSession) {
        VTDecompressionSessionInvalidate(self.decodeSession);
        CFRelease(self.decodeSession);
        self.decodeSession = NULL;
    }
}

#pragma mark - Public Func
- (void)videoDecodeWithH264Data:(NSData *)h264Data; {

}




#pragma mark - Private Func
/// 初始化解码会话
- (BOOL)initDecoderSession {
    if (self.decodeSession) return YES;
    const uint8_t * const parameterSetPointers[2] = {_sps, _pps};
    const size_t parameterSetSizes[2] = {_spsSize, _ppsSize};
    int naluHeaderLen = 4;
}

- (CVPixelBufferRef)decode:(uint8_t *)frame withSize:(uint32_t)frameSize {
    return nil;
}

- (void)decodeNaluData:(uint8_t *)frame withSize:(uint32_t)frameSize {
    
}


#pragma mark - 解码完成回调
void videoDecoderCallBack(void * CM_NULLABLE decompressionOutputRefCon, void * CM_NULLABLE sourceFrameRefCon, OSStatus status, VTDecodeInfoFlags infoFlags, CM_NULLABLE CVImageBufferRef imageBuffer, CMTime presentationTimeStamp, CMTime presentationDuration ) {
    
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
