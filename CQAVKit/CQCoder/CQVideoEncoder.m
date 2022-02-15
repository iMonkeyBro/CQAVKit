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
        NSLog(@"CQVideoEncoder-VTCompressionSessionCreate create failed. statuc = %d", (int)status);
        return;
    }
    // 设置编码器属性
    // 设置实时执行
    status = VTSessionSetProperty(_encodeSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
    if (status != noErr) {
        NSLog(@"CQVideoEncoder-VTSessionSetProperty set RealTime failed. statuc = %d", (int)status);
        return;
    }
    // 指定编码比特流的配置文件和级别。直播一般使用baseline，可减少由B帧带来的延时
    
}




#pragma mark - 编码完成回调
void videoEncoderCallBack(void *outputCallbackRefCon, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags, CMSampleBufferRef sampleBuffer) {
    
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
