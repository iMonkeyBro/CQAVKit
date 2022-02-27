//
//  CQTestVideoCoderVC.m
//  CQAVKit
//
//  Created by 刘超群 on 2022/2/23.
//

#import "CQTestVideoCoderVC.h"
#import "CQCaptureManager.h"
#import "CQCapturePreviewView.h"
#import "CQVideoEncoder.h"
#import "CQVideoDecoder.h"
#import "CQPlayEAGLLayer.h"

@interface CQTestVideoCoderVC ()<CQCaptureManagerDelegate, CQVideoEncoderDelegate, CQVideoDecoderDelegate>
@property (nonatomic, strong) CQCaptureManager *captureManager;  ///< 捕捉管理
@property (nonatomic, strong) CQCapturePreviewView *capturePreviewView;  ///< 捕捉预览
@property (nonatomic, strong) CQVideoEncoder *videoEncoder;  ///< 编码器
@property (nonatomic, strong) CQVideoDecoder *videoDecoder;  ///< 解码器
@property (nonatomic, strong) CQPlayEAGLLayer *playEAGLLayer; ///< OpenGL绘制PixelBuffer
@property (nonatomic, strong) NSFileHandle *fileHandle; ///< 文件处理
@end

@implementation CQTestVideoCoderVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.captureManager = CQCaptureManager.new;
    self.captureManager.delegate = self;
    self.videoEncoder = [[CQVideoEncoder alloc] initWithConfig:[CQVideoCoderConfig defaultConifg]];
    self.videoEncoder.delegate = self;
    self.videoDecoder = [[CQVideoDecoder alloc] initWithConfig:[CQVideoCoderConfig defaultConifg]];
    self.videoDecoder.delegate = self;
    
    [self configUI];
    [self configCaptureSession];
}

#pragma mark - UI
- (void)configUI {
    self.capturePreviewView = [[CQCapturePreviewView alloc] initWithFrame:CGRectMake(KSCREEN_WIDTH/2, 0, KSCREEN_WIDTH/2, KSCREEN_HEIGHT/2-50)];
    [self.view addSubview:self.capturePreviewView];
    UIButton *startEncodeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    startEncodeBtn.frame = CGRectMake(20, 50, 150, 30);
    [startEncodeBtn setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    [startEncodeBtn setTitle:@"开始采集文件" forState:UIControlStateNormal];
    [startEncodeBtn setTitle:@"关闭采集文件" forState:UIControlStateSelected];
    [startEncodeBtn addTarget:self action:@selector(startCaptureAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:startEncodeBtn];
    
    self.playEAGLLayer = [[CQPlayEAGLLayer alloc] initWithFrame:CGRectMake(0, KSCREEN_HEIGHT/2-30, KSCREEN_WIDTH/2, KSCREEN_HEIGHT/2-50)];
    [self.view.layer addSublayer:self.playEAGLLayer];
}

#pragma mark - Event
- (void)startCaptureAction:(UIButton *)sender {
    if (sender.selected) {
        // 关闭
        [self.captureManager stopSessionAsync];
    } else {
        // 打开
        [self.captureManager startSessionAsync];
    }
    sender.selected = !sender.isSelected;
}

#pragma mark - CaptureSession
- (void)configCaptureSession {
    NSError *error;
    [self.captureManager configSessionPreset:AVCaptureSessionPreset1920x1080];
    if ([self.captureManager configVideoInput:&error]) {
        [self.captureManager configVideoDataOutput];
        self.capturePreviewView.session = self.captureManager.captureSession;
        
        self.captureManager.flashMode = AVCaptureFlashModeAuto;
    } else {
        CQLog(@"Error: %@", [error localizedDescription]);
    }
}

#pragma mark - CQCaptureManagerDelegate
- (void)captureVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    [self.videoEncoder videoEncodeWithSampleBuffer:sampleBuffer];
}

#pragma mark - CQVideoEncoderDelegate
- (void)videoEncoder:(CQVideoEncoder *)videoEncoder didEncodeWithSps:(NSData *)sps pps:(NSData *)pps {
    // 写入文件
    if (!self.fileHandle) [self createFileHandler];
    
    const char bytes[] = "\x00\x00\x00\x01";
    size_t length = sizeof(bytes) - 1;
    NSData *byteHeader = [NSData dataWithBytes:bytes length:length];
    
//    [self.fileHandle writeData:byteHeader];
    [self.fileHandle seekToEndOfFile];
    [self.fileHandle writeData:sps];
    
//    [self.fileHandle writeData:byteHeader];
    [self.fileHandle seekToEndOfFile];
    [self.fileHandle writeData:pps];
    
    // 直接给解码器解码
    [self.videoDecoder videoDecodeWithH264Data:sps];
    [self.videoDecoder videoDecodeWithH264Data:pps];
}

- (void)videoEncoder:(CQVideoEncoder *)videoEncoder didEncodeSuccessWithH264Data:(NSData *)h264Data {
    // 写入文件
    if (!self.fileHandle) [self createFileHandler];
    
    const char bytes[] = "\x00\x00\x00\x01";
    size_t length = sizeof(bytes) - 1;
    NSData *byteHeader = [NSData dataWithBytes:bytes length:length];
    
//    [self.fileHandle writeData:byteHeader];
    [self.fileHandle seekToEndOfFile];
    [self.fileHandle writeData:h264Data];
    
    // 直接给解码器解码
    [self.videoDecoder videoDecodeWithH264Data:h264Data];
}

#pragma mark - CQVideoDecoderDelegate
- (void)videoDecoder:(CQVideoDecoder *)videoDecoder didDecodeSuccessWithPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    // 使用CAEAGLLayer绘制出来
    self.playEAGLLayer.pixelBuffer = pixelBuffer;
}

#pragma mark - FileHandler
- (void)createFileHandler {
    // 沙盒路径
    NSString *filePath = [NSHomeDirectory()stringByAppendingPathComponent:@"/Library/TestVideoCoder4.h264"];
    NSFileManager *manager = [NSFileManager defaultManager];
    BOOL createFile = NO;
    if ([manager fileExistsAtPath:filePath]) {
        if ([manager removeItemAtPath:filePath error:nil]) {
            createFile = [[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil];
        }
    } else {
        createFile = [[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil];
    }
    if (!createFile) {
        NSLog(@"create file failed");
    } else {
        NSLog(@"create file success");
    }
    NSLog(@"filePaht = %@",filePath);
    // 写入数据 NSFIleHandle 类似于C语言文件指针，创建写入的handle
    self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
}

- (void)destroyFileHandler {
    [self.fileHandle closeFile];
    self.fileHandle = nil;
}

@end
