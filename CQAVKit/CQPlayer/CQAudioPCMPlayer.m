//
//  CQAudioPCMPlayer.m
//  CQAVKit
//
//  Created by 刘超群 on 2022/2/28.
//

#import "CQAudioPCMPlayer.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

#define MIN_SIZE_PER_FRAME 2048 //每帧最小数据长度

static const int kNumberBuffers_play = 3;

typedef struct CQPlayerState {
    AudioStreamBasicDescription   mDataFormat;                    // 2
    AudioQueueRef                 mQueue;                         // 3
    AudioQueueBufferRef           mBuffers[kNumberBuffers_play];       // 4
    AudioStreamPacketDescription  *mPacketDescs;                  // 9
} CQPlayerState;

@interface CQAudioPCMPlayer ()
@property (nonatomic, assign) CQPlayerState aqps;
@property (nonatomic, assign) BOOL isPlaying;
@end

@implementation CQAudioPCMPlayer

#pragma mark - Init
- (instancetype)initWithConfig:(CQAudioCoderConfig *)config {
    if (self = [super init]) {
        _config = config;
        // 配置
        AudioStreamBasicDescription dataFormat = {0};
        dataFormat.mSampleRate = (Float64)_config.sampleRate;       // 采样率
        dataFormat.mChannelsPerFrame = (UInt32)_config.channelCount; // 输出声道数
        dataFormat.mFormatID = kAudioFormatLinearPCM;                // 输出格式
        dataFormat.mFormatFlags = (kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked); // 编码 12
        dataFormat.mFramesPerPacket = 1;                            // 每一个packet帧数 ；
        dataFormat.mBitsPerChannel = 16;                             // 数据帧中每个通道的采样位数。
        // 每一帧大小（采样位数 / 8 *声道数）
        dataFormat.mBytesPerFrame = dataFormat.mBitsPerChannel / 8 *dataFormat.mChannelsPerFrame;
        // 每个packet大小（帧大小 * 帧数）
        dataFormat.mBytesPerPacket = dataFormat.mBytesPerFrame * dataFormat.mFramesPerPacket;
        dataFormat.mReserved =  0;
        CQPlayerState state = {0};
        state.mDataFormat = dataFormat;
        _aqps = state;
        
        [self setupSession];
        
        // 创建播放队列
        OSStatus status = AudioQueueNewOutput(&_aqps.mDataFormat, audioQueueOutputCallback, NULL, NULL, NULL, 0, &_aqps.mQueue);
        if (status != noErr) {
            NSError *error = [[NSError alloc] initWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
            NSLog(@"Error: AudioQueue create error = %@", [error description]);
            return self;
        }
        
        [self setupVoice:1];
        _isPlaying = false;
    }
    return self;
}

- (void)dealloc {
    NSLog(@"CQAudioPCMPlayer - dealloc !!!");
}

#pragma mark - Public
- (void)playPCMData:(NSData *)data {
    
    // 指向音频队列缓冲区
    AudioQueueBufferRef inBuffer;
    /*
     要求音频队列对象分配音频队列缓冲区。
     参数1:要分配缓冲区的音频队列
     参数2:新缓冲区所需的容量（字节）
     参数3:输出，指向新分配的音频队列缓冲区
     */
    AudioQueueAllocateBuffer(_aqps.mQueue, MIN_SIZE_PER_FRAME, &inBuffer);
    // 将data里的数据拷贝到inBuffer.mAudioData中
    memcpy(inBuffer->mAudioData, data.bytes, data.length);
    // 设置inBuffer.mAudioDataByteSize
    inBuffer->mAudioDataByteSize = (UInt32)data.length;
    
    // 将缓冲区添加到录制或播放音频队列的缓冲区队列。
    /*
     参数1:拥有音频队列缓冲区的音频队列
     参数2:要添加到缓冲区队列的音频队列缓冲区。
     参数3:inBuffer参数中音频数据包的数目,对于以下任何情况，请使用值0：
     * 播放恒定比特率（CBR）格式时。
     * 当音频队列是录制（输入）音频队列时。
     * 当使用audioqueueallocateBufferWithPacketDescriptions函数分配要重新排队的缓冲区时。在这种情况下，回调应该描述缓冲区的mpackedDescriptions和mpackedDescriptionCount字段中缓冲区的数据包。
     参数4:一组数据包描述。对于以下任何情况，请使用空值
     * 播放恒定比特率（CBR）格式时。
     * 当音频队列是输入（录制）音频队列时。
     * 当使用audioqueueallocateBufferWithPacketDescriptions函数分配要重新排队的缓冲区时。在这种情况下，回调应该描述缓冲区的mpackedDescriptions和mpackedDescriptionCount字段中缓冲区的数据包
     */
    OSStatus status = AudioQueueEnqueueBuffer(_aqps.mQueue, inBuffer, 0, NULL);
    if (status != noErr) {
        NSLog(@"Error: audio queue palyer  enqueue error: %d",(int)status);
    }
    
    // 开始播放或录制音频
    /*
     参数1:要开始的音频队列
     参数2:音频队列应开始的时间。
     要指定相对于关联音频设备时间线的开始时间，请使用audioTimestamp结构的msampletime字段。使用NULL表示音频队列应尽快启动
     */
    AudioQueueStart(_aqps.mQueue, NULL);
}

// 不需要该函数，
//- (void)pause {
//     AudioQueuePause(_aqps.mQueue);
//}

//设 置音量增量//0.0 - 1.0
- (void)setupVoice:(Float32)gain {
    
    Float32 gain0 = gain;
    if (gain < 0) {
        gain0 = 0;
    }else if (gain > 1) {
        gain0 = 1;
    }
    // 设置播放音频队列参数值
    /*
     参数1:要开始的音频队列
     参数2:属性
     参数3:value
     */
    AudioQueueSetParameter(_aqps.mQueue, kAudioQueueParam_Volume, gain0);
}

// 销毁
- (void)dispose {
    
    AudioQueueStop(_aqps.mQueue, true);
    AudioQueueDispose(_aqps.mQueue, true);
}

#pragma mark - Session
- (void)setupSession {
    NSError *error = nil;
    // 将会话设置为活动或非活动。请注意，激活音频会话是一个同步（阻塞）操作
    [[AVAudioSession sharedInstance] setActive:YES error:&error];
    if (error) {
        NSLog(@"Error: audioQueue palyer AVAudioSession error, error: %@", error);
    }
    // 设置会话类别
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    if (error) {
        NSLog(@"Error: audioQueue palyer AVAudioSession error, error: %@", error);
    }
}

#pragma mark -
static void audioQueueOutputCallback(void * inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer) {
    AudioQueueFreeBuffer(inAQ, inBuffer);
}

@end
