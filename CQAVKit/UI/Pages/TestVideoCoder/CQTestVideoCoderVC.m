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
}

#pragma mark - CQCaptureManagerDelegate

#pragma mark - CQVideoEncoderDelegate
- (void)videoEncoder:(CQVideoEncoder *)videoEncoder didEncodeWithSps:(NSData *)sps pps:(NSData *)pps {
    // 写入文件
    if (!self.fileHandle) [self createFileHandler];
    [self.fileHandle seekToEndOfFile];
    [self.fileHandle writeData:sps];
    [self.fileHandle seekToEndOfFile];
    [self.fileHandle writeData:pps];
    
    // 直接给解码器解码
    [self.videoDecoder videoDecodeWithH264Data:sps];
    [self.videoDecoder videoDecodeWithH264Data:pps];
}

- (void)videoEncoder:(CQVideoEncoder *)videoEncoder didEncodeSuccessWithH264Data:(NSData *)h264Data {
    // 写入文件
    if (!self.fileHandle) [self createFileHandler];
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
    NSString *filePath = [NSHomeDirectory()stringByAppendingPathComponent:@"/Documents/video.h264"];
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
