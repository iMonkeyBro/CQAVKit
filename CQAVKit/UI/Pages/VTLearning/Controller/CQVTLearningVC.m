//
//  CQVTLearningVC.m
//  CQAVKit
//
//  Created by 刘超群 on 2022/1/1.
//

#import "CQVTLearningVC.h"
#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>

@interface CQVTLearningVC ()<AVCaptureVideoDataOutputSampleBufferDelegate>
@property (nonatomic, strong) UILabel *cLabel;
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureDeviceInput *captureDeviceInput;
@property (nonatomic, strong) AVCaptureVideoDataOutput *captureVideoDataOutput;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;

@property (nonatomic, strong) dispatch_queue_t captureQueue; ///< 捕捉队列
@property (nonatomic, strong) dispatch_queue_t encodeQueue; ///< 编码队列
@property (nonatomic, strong) NSFileHandle *fileHandle; ///< 文件处理
@property (nonatomic, assign) VTCompressionSessionRef compressionSessionRef;
@property (nonatomic, assign) CMFormatDescriptionRef formatDescriptionRef;
@property (nonatomic, assign) int frameID;
@end

@implementation CQVTLearningVC

- (void)viewDidLoad {
    [super viewDidLoad];
    UIButton *optionBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [optionBtn setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    [optionBtn setTitle:@"Play" forState:UIControlStateNormal];
    optionBtn.frame = CGRectMake(0, 0, 50, 20);
    [optionBtn addTarget:self action:@selector(optionAction:) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:optionBtn];
    [self initCapture];
}


- (void)optionAction:(UIButton *)sender {
    if (!self.captureSession || !self.captureSession.isRunning) {
        [self startCapture];
        [sender setTitle:@"Stop" forState:UIControlStateNormal];
    } else {
        [ self stopCapture];
        [sender setTitle:@"Play" forState:UIControlStateNormal];
    }
}

#pragma mark - Capture
- (void)initCapture {
    // 初始化captureSession
    self.captureSession = [[AVCaptureSession alloc] init];
    // 设置分辨率
    self.captureSession.sessionPreset = AVCaptureSessionPreset3840x2160;
    // 设置输入设备
    NSArray<AVCaptureDevice *> *videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];// 拿到所有摄像头
    AVCaptureDevice *inputDevice = nil;
    for (AVCaptureDevice *device in videoDevices) {
        // 遍历拿到后置摄像头
        if (device.position == AVCaptureDevicePositionBack) {
            inputDevice = device;
        }
    }
    self.captureDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:inputDevice error:nil];
    if (self.captureDeviceInput && [self.captureSession canAddInput:self.captureDeviceInput]) {
        [self.captureSession addInput:self.captureDeviceInput];
    }
    // 设置视频数据输出
    self.captureVideoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    // 表示如果视频帧迟到，是否丢弃视频帧。一般NO
    self.captureVideoDataOutput.alwaysDiscardsLateVideoFrames = NO;
    self.captureVideoDataOutput.videoSettings = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)};
    // 设置捕捉代理和队列
    [self.captureVideoDataOutput setSampleBufferDelegate:self queue:self.captureQueue];
    // 输出添加到session
    if ([self.captureSession canAddOutput:self.captureVideoDataOutput]) {
        [self.captureSession addOutput:self.captureVideoDataOutput];
    }
    // 创建链接
    AVCaptureConnection *connection = [self.captureVideoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    connection.videoOrientation = AVCaptureVideoOrientationPortrait; // 方向竖屏
    // 预览图层
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
    // 视频重力
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    self.previewLayer.bounds = CGRectMake(0, 0, KSCREEN_WIDTH, KSCREEN_HEIGHT-CQScreenTool.navHeight);
    self.previewLayer.position = CGPointMake(KSCREEN_WIDTH/2, (KSCREEN_HEIGHT-CQScreenTool.navHeight)/2);
    
    
}

- (void)startCapture {
    [self initVideoToolBox];
    
    // 沙盒路径
    NSString *filePath = [NSHomeDirectory()stringByAppendingPathComponent:@"/Documents/video.h264"];
    // 移除
    [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
    // 新建
    BOOL createFile = [[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil];
    if (!createFile) {
        NSLog(@"create file failed");
    } else {
        NSLog(@"create file success");
    }
    NSLog(@"filePaht = %@",filePath);
    // 写入数据 NSFIleHandle 类似于C语言文件指针，创建写入的handle
    self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
    
    // 到此 采集的准备工作完成
    
    [self.view.layer addSublayer:self.previewLayer];
    [self.captureSession startRunning];
}

- (void)stopCapture {
    [self.captureSession stopRunning];
    [self.previewLayer removeFromSuperlayer];
    [self.fileHandle closeFile];
    self.fileHandle = nil;
    [self endVideoToolBox];
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
/**
 MovieFileOutput     视频采集后，直接形成mov视频文件
 mediaData           想要采集数据做识别时，使用
 VideoDataOutput     直播，录制视频，获取视频帧时，使用这个
 */
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    // 注意，视频/音频通过AV采集，都会走这里，需要对音频/视频做区分
    // 直接判断output 是videoDataOutput/Audio
    // 未压缩的视频流 CVPixcelBuffer
    dispatch_sync(self.encodeQueue, ^{
        [self encode:sampleBuffer];
    });
}

#pragma mark - 编码
// 编码，当AVFoundation 捕捉的数据时调用
- (void)encode:(CMSampleBufferRef)sampleBuffer {
    // 获取录制视频中每一张图片
    CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
    // 帧时间
    CMTime pTime = CMTimeMake(self.frameID++, 1000);
    VTEncodeInfoFlags flags;
    // 编码函数
    /**
     参数1  编码会话
     参数2  未编码的数据
     参数3  时间戳
     参数4  帧展示时间，如果没有时间信息，KCMTimeInvalid
     参数5  帧属性！NULL
     参数6  编码过程回调！ NULL
     参数7  flags  同步/异步
     */
    OSStatus status = VTCompressionSessionEncodeFrame(_compressionSessionRef, imageBuffer, pTime, kCMTimeInvalid, NULL, NULL, &flags);
    if (status != noErr) {
        NSLog(@"H264:VTCompressionSessionEncodeFrame Failed");
        // 结束编码
        VTCompressionSessionInvalidate(_compressionSessionRef);
        if (_compressionSessionRef) CFRelease(_compressionSessionRef);
        _compressionSessionRef = NULL;
        return;
    }
    // 编码成功
    NSLog(@"H264:VTCompressionSessionEncodeFrame Success");
}

#pragma mark - 编码完成回调
// VideoToolBox编码完成回调
void didCompressH264(void *outputCallbackRefCon, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags, CMSampleBufferRef sampleBuffer) {
    NSLog(@"didCompressH264 called with status %d infoFlags %d",(int)status,(int)infoFlags);
    // 状态错误
    if (status != 0) {
        NSLog(@"didCompressH264 status is failed");
        return;
    }
    // 数据没准备好
    if (!CMSampleBufferDataIsReady(sampleBuffer)) {
        NSLog(@"didCompressH264 data is not ready");
        return;
    }
    //  C语言函数中调用OC，outputCallbackRefCon就是之前传的self
    CQVTLearningVC *encoder = (__bridge CQVTLearningVC *)outputCallbackRefCon;
    // 判断当前帧是否为关键帧 ！ sps/pps信息
    bool keyFrame = !CFDictionaryContainsKey(CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0), kCMSampleAttachmentKey_NotSync);
    if (keyFrame) {
        // 获取sps/pps
        // 拿到源图像编码相关信息
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        // sps count/size/content
        size_t spsSize, spsCount;
        const uint8_t *spsContent;
        // 获取sps/pps
        /**
         参数1  原图像存储格式
         参数2  索引 0
         参数3  获取内容 spsContent ，传一个地址，会把内容赋值给地址
         参数4  获取 spsSize ，传一个地址，会把内容赋值给地址
         参数5  获取 spsCount ，传一个地址，会把内容赋值给地址
         参数6  头长度
         */
        OSStatus spsStatus = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &spsContent, &spsSize, &spsCount, 0);
        if (spsStatus != noErr) return;
        
        // 获取pps count/size/content
        size_t ppsSize, ppsCount;
        const uint8_t *ppsContent;
        // 索引 1
        OSStatus ppsStatus = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &ppsContent, &ppsSize, &ppsCount, 0);
        if (ppsStatus != noErr) return; // sps pps出现问题直接return，丢弃之后的流数据
    
        // 写入到文件
        NSData *spsData = [NSData dataWithBytes:spsContent length:spsSize];
        NSData *ppsData = [NSData dataWithBytes:ppsContent length:ppsSize];
        if (encoder) {
            [encoder gotSpsPps:spsData pps:ppsData];
        }
    }
    
    // sps/pps之后的数据 NALU
    // 编码后的H264 NALU数据
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    // 单个数据长度，整个数据块长度
    size_t length, totalLength;
    char *dataPointer;
    // 获取blockBuffer
    /**
     参数1  数据
     参数2  偏移量0
     参数3  获取单个数据长度
     参数4  获取总数据长度
     参数5  指针指向
     获取数据块总大小，单个数据大小，数据块首地址，---理解数组
     */
    OSStatus statusNalu = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
    if (statusNalu == noErr) {
        // 读取数据
        // 大端小端模式
        /**
         计算机硬件有两种存储方式： 大端字节序，小端字节序
         大端字节序：高位字节在前面，低位字节在后面，01 23 45 67
         小端字节序：低位字节在前面，高位字节在后面，67 45 23 01
         0x1234567
         为什么会有小端字节序？  计算机电路先处理低位字节序，效率比较高！因为计算都是从低位开始，计算机内部处理都是从低位开始处理
         人类的读写习惯是大端字节序，所以除了计算机内部，一般情况我们都会保持大端字节序
         */
        
        /**
         范例
         数组a[4] = {1,2,3,4};
         指针方式打印每一个元素
         1. int *p = a; （修改步长方式来读取元素）
         2. int *t = a;  （修改指针指向的地址来读取元素）
         for (int i = 0; i<4;i++)
             *(p+i);  修改步长，p一直指向数组首地址
             *(t++);  修改指针指向地址，t的地址一直发生变化
             a(数组名就是首地址) 不能做自增自减  常量
             *(a+i) 可以
         */
        size_t bufferOffset = 0;
        // 获取的NALU前面4个字节不是001的起始位，而是大端模式的帧长度
        static const int AVCHeaderLength = 4;
        // 通过偏移量获取每个NALU数据
        while (bufferOffset < totalLength - AVCHeaderLength) {
            uint32_t NALUnitLength = 0;
            memcpy(&NALUnitLength, dataPointer+bufferOffset, AVCHeaderLength);
            // 从大端模式转为小端模式 (Mac系统端模式就是小端模式)
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
            // 获取NSData类型 NALU
            NSData *data = [[NSData alloc] initWithBytes:dataPointer+bufferOffset+AVCHeaderLength length:NALUnitLength];
            // 写入H264文件
            [encoder gotEncodedData:data isKeyFrame:keyFrame];
            // 移动偏移量，读取下一个数据
            bufferOffset += AVCHeaderLength + NALUnitLength;
        }
    }
}

#pragma mark - VideoToolBox
// 初始化VideoToolBox 编码
- (void)initVideoToolBox {
    self.frameID = 0;
    // 分辨率与captureSession保持一致
    int width = 2160, height = 3840;
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
    OSStatus status = VTCompressionSessionCreate(NULL, width, height, kCMVideoCodecType_H264, NULL, NULL, NULL, didCompressH264, (__bridge void*)self, &_compressionSessionRef);
    // noErr 等价于0
    if (status != noErr) {
        NSLog(@"H264: VTCompressionSessionCreate Failed!");
        return;
    }
    // 配置参数
    // OC  对象.属性来传递参数
    // C 用函数来实现配置参数
    /**
     配置编码参数
     参数1  参数设置对象
     参数2  属性名称
     参数3  属性对应的值
     */
    // 设置实时编码
    VTSessionSetProperty(_compressionSessionRef, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
    // 舍弃B帧
    VTSessionSetProperty(_compressionSessionRef, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Baseline_AutoLevel);
    // GOP (太小视频模糊，太大文件会很大)
    int frameInterval = 30;
    // VTSessionSetProperty 不能直接设置ing/float作为属性值，需要做类型转换
    /**
     参数1  分配器，默认
     参数2  数据类型
     参数3  地址
     */
    CFNumberRef frameIntervalRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &frameInterval);
    VTSessionSetProperty(_compressionSessionRef, kVTCompressionPropertyKey_MaxKeyFrameInterval, frameIntervalRef);
    // 帧率上限
    int fps = 30;
    CFNumberRef fpsIntervalRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &fps);
    VTSessionSetProperty(_compressionSessionRef, kVTCompressionPropertyKey_ExpectedFrameRate, fpsIntervalRef);
    // 码率上限
    // 参考PPT表格
    int bitRate = width * height * 3 * 4 * 8;
    CFNumberRef bitRateIntervalRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &bitRate);
    VTSessionSetProperty(_compressionSessionRef, kVTCompressionPropertyKey_AverageBitRate, bitRateIntervalRef);
    // 码率值 码率过大视频清晰度会比较高，但是体积会很大
    int bitRateLimit = width * height * 3 * 4;
    CFNumberRef bitRateLimitIntervalRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &bitRateLimit);
    VTSessionSetProperty(_compressionSessionRef, kVTCompressionPropertyKey_DataRateLimits, bitRateLimitIntervalRef);
    // 以上为必须设置的参数
    // 准备编码
    VTCompressionSessionPrepareToEncodeFrames(_compressionSessionRef);
    
    // 当AVFoundation 捕捉的数据时，开始编码
}

// 结束VideoToolBox
- (void)endVideoToolBox {
    VTCompressionSessionCompleteFrames(self.compressionSessionRef, kCMTimeInvalid);
    VTCompressionSessionInvalidate(self.compressionSessionRef);
    if (self.compressionSessionRef) CFRelease(self.compressionSessionRef);
    self.compressionSessionRef = NULL;
}

#pragma mark - File Handler
- (void)initFileHandler {
    
}

- (void)endFileHandle {
    
}

#pragma mark - File Write
// 数据写入sps pps
- (void)gotSpsPps:(NSData*)sps pps:(NSData*)pps {
    NSLog(@"SpsPps is writing!");
    if (!self.fileHandle) return;
    // 写入之前(起始位)
    const char bytes[] = "\x00\x00\x00\x01";
    // 因为字符串要/0结束 终止符
    size_t length = sizeof(bytes) - 1;
    NSData *byteHeader = [NSData dataWithBytes:bytes length:length];
    [self.fileHandle writeData:byteHeader];
    [self.fileHandle writeData:sps];
    [self.fileHandle writeData:byteHeader];
    [self.fileHandle writeData:pps];
}

- (void)gotEncodedData:(NSData*)data isKeyFrame:(BOOL)isKeyFrame {
    NSLog(@"encoderData is writing!");
    if (!self.fileHandle) return;
    // 创建起始位
    const char bytes[] = "\x00\x00\x00\x01";
    // 计算长度
    size_t length = sizeof(bytes) - 1;
    // bytes转为NSData
    NSData *byteHeader = [NSData dataWithBytes:bytes length:length];
    // 写入NALU数据之前，先写入起始位
    [self.fileHandle writeData:byteHeader];
    // 写入NALU
    [self.fileHandle writeData:data];
}


#pragma mark - Load
- (dispatch_queue_t)captureQueue {
    if (!_captureQueue) {
        _captureQueue = dispatch_queue_create("captureQueue", NULL);
    }
    return _captureQueue;
}

- (dispatch_queue_t)encodeQueue {
    if (!_encodeQueue) {
        _encodeQueue = dispatch_queue_create("encodeQueue", NULL);
    }
    return _encodeQueue;
}


@end
