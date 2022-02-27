//
//  CQTestAudioCoderVC.m
//  CQAVKit
//
//  Created by 刘超群 on 2022/2/27.
//

#import "CQTestAudioCoderVC.h"
#import "CQAudioEncoder.h"
#import "CQCaptureManager.h"

@interface CQTestAudioCoderVC ()<CQCaptureManagerDelegate, CQAudioEncoderDelegate>
@property (nonatomic, strong) CQCaptureManager *captureManager;  ///< 捕捉管理
@property (nonatomic, strong) CQAudioEncoder *audioEncoder;  ///< 编码器
@property (nonatomic, strong) NSFileHandle *fileHandle; ///< 文件处理
@end

@implementation CQTestAudioCoderVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.captureManager = CQCaptureManager.new;
    self.captureManager.delegate = self;
    self.audioEncoder = [[CQAudioEncoder alloc] initWithConfig:[CQAudioCoderConfig defaultConifg]];
    self.audioEncoder.delegate = self;
    [self configUI];
    [self configCaptureSession];
}

#pragma mark - UI
- (void)configUI {
    UIButton *startEncodeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    startEncodeBtn.frame = CGRectMake(20, 50, 150, 30);
    [startEncodeBtn setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    [startEncodeBtn setTitle:@"开始录制" forState:UIControlStateNormal];
    [startEncodeBtn setTitle:@"关闭录制" forState:UIControlStateSelected];
    [startEncodeBtn addTarget:self action:@selector(startCaptureAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:startEncodeBtn];
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
    if ([self.captureManager configAudioInput:&error]) {
        [self.captureManager configAudioDataOutput];
    } else {
        CQLog(@"Error: %@", [error localizedDescription]);
    }
}

#pragma mark - CQCaptureManagerDelegate
- (void)captureAudioSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    /** 直接播放
    CMSampleBufferRef-> PCM
    播放PCM
    */
    
    // 做编码
    [self.audioEncoder audioEncodeWithSampleBuffer:sampleBuffer];
}

#pragma mark - CQAudioEncoderDelegate
- (void)audioEncoder:(CQAudioEncoder *)audioEncoder didEncodeSuccessWithAACData:(NSData *)aacData {
    // 写入AAC
    if (!self.fileHandle) [self createFileHandler];
    [self.fileHandle seekToEndOfFile];
    [self.fileHandle writeData:aacData];
    
    // 解码
}

#pragma mark - FileHandler
- (void)createFileHandler {
    // 沙盒路径
    NSString *filePath = [NSHomeDirectory()stringByAppendingPathComponent:@"/Library/TestAudioCoder0.aac"];
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
