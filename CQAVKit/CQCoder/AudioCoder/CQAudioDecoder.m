//
//  CQAudioDecoder.m
//  CQAVKit
//
//  Created by 刘超群 on 2022/2/27.
//

#import "CQAudioDecoder.h"
#import <AudioToolbox/AudioToolbox.h>

typedef struct {
    char * data;
    UInt32 size;
    UInt32 channelCount;
    AudioStreamPacketDescription packetDesc;
} CQAudioUserData;

@interface CQAudioDecoder ()
@property (nonatomic, strong) dispatch_queue_t decodeQueue;  ///< 解码队列
@property (nonatomic, strong) dispatch_queue_t callbackQueue;  ///< 回调队列
@property (strong, nonatomic) NSCondition *converterCond;
/// 对音频转换器对象
@property (nonatomic) AudioConverterRef audioConverter;
/// aac缓冲区
@property (nonatomic) char *aacBuffer;
/// aac缓冲区大小
@property (nonatomic) UInt32 aacBufferSize;
@property (nonatomic) AudioStreamPacketDescription *packetDesc;
@end

@implementation CQAudioDecoder

#pragma mark - Init
- (instancetype)initWithConfig:(CQAudioCoderConfig *)config {
    if (self = [super init]) {
        _config = config;
        _decodeQueue = dispatch_queue_create("CQAudioDecoder decode queue", DISPATCH_QUEUE_SERIAL);
        _callbackQueue = dispatch_queue_create("CQAudioDecoder callBack queue", DISPATCH_QUEUE_SERIAL);
        _audioConverter = NULL;
        _aacBufferSize = 0;
        _aacBuffer = NULL;
        AudioStreamPacketDescription desc = {0};
        _packetDesc = &desc;
        [self setupDecoder];
    }
    return self;
}

- (void)dealloc {
    if (_audioConverter) {
        AudioConverterDispose(_audioConverter);
        _audioConverter = NULL;
    }
    NSLog(@"CQAudioDecoder - dealloc !!!");
}

#pragma mark - Public Func
- (void)audioDecodeWithAACData:(NSData *)aacData {
    if (!_audioConverter) { return; }
    dispatch_async(_decodeQueue, ^{
        // 记录aac 作为参数参入 给到 解码回调函数
        CQAudioUserData userData = {0};
        userData.channelCount = (UInt32)self.config.channelCount;
        userData.data = (char *)[aacData bytes];
        userData.size = (UInt32)aacData.length;
        userData.packetDesc.mDataByteSize = (UInt32)aacData.length;
        userData.packetDesc.mStartOffset = 0;
        userData.packetDesc.mVariableFramesInPacket = 0;
        
        // 输出大小和packet个数
        UInt32 pcmBufferSize = (UInt32)(2048 * self.config.channelCount);
        UInt32 pcmDataPacketSize = 1024;
        
        // 创建临时容器pcm
        uint8_t *pcmBuffer = malloc(pcmBufferSize);
        memset(pcmBuffer, 0, pcmBufferSize);
        
        // 输出buffer
        AudioBufferList outAudioBufferList = {0};
        outAudioBufferList.mNumberBuffers = 1;
        outAudioBufferList.mBuffers[0].mNumberChannels = (uint32_t)self.config.channelCount;
        outAudioBufferList.mBuffers[0].mDataByteSize = (UInt32)pcmBufferSize;
        outAudioBufferList.mBuffers[0].mData = pcmBuffer;
        
        // 输出描述
        AudioStreamPacketDescription outputPacketDesc = {0};
        
        // 配置填充函数，获取输出数据
        OSStatus status = AudioConverterFillComplexBuffer(self.audioConverter, &AudioDecoderConverterComplexInputDataProc, &userData, &pcmDataPacketSize, &outAudioBufferList, &outputPacketDesc);
        if (status != noErr) {
            NSLog(@"Error: AAC Decoder error, status=%d",(int)status);
            return;
        }
        // 如果获取到数据
        if (outAudioBufferList.mBuffers[0].mDataByteSize > 0) {
            NSData *rawData = [NSData dataWithBytes:outAudioBufferList.mBuffers[0].mData length:outAudioBufferList.mBuffers[0].mDataByteSize];
            dispatch_async(self.callbackQueue, ^{
                if (self.delegate && [self.delegate respondsToSelector:@selector(audioDecoder:didDecodeSuccessWithPCMData:)]) {
                    [self.delegate audioDecoder:self didDecodeSuccessWithPCMData:rawData];
                }
            });
        }
        free(pcmBuffer);
    });
}

#pragma mark - 创建解码器
- (void)setupDecoder {
    // 输出参数pcm
    AudioStreamBasicDescription outputAudioDes = {0};
    outputAudioDes.mSampleRate = (Float64)_config.sampleRate;       // 采样率
    outputAudioDes.mChannelsPerFrame = (UInt32)_config.channelCount; // 输出声道数
    outputAudioDes.mFormatID = kAudioFormatLinearPCM;                // 输出格式
    outputAudioDes.mFormatFlags = (kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked); // 编码 12
    outputAudioDes.mFramesPerPacket = 1;                            // 每一个packet帧数 ；
    outputAudioDes.mBitsPerChannel = 16;                             // 数据帧中每个通道的采样位数。
    // 每一帧大小（采样位数 / 8 *声道数）
    outputAudioDes.mBytesPerFrame = outputAudioDes.mBitsPerChannel / 8 *outputAudioDes.mChannelsPerFrame;
    // 每个packet大小（帧大小 * 帧数）
    outputAudioDes.mBytesPerPacket = outputAudioDes.mBytesPerFrame * outputAudioDes.mFramesPerPacket;
    outputAudioDes.mReserved =  0;                                  //对其方式 0(8字节对齐)
    
    // 输入参数aac，原文件格式
    AudioStreamBasicDescription inputAduioDes = {0};
    inputAduioDes.mSampleRate = (Float64)_config.sampleRate;
    inputAduioDes.mFormatID = kAudioFormatMPEG4AAC;
    inputAduioDes.mFormatFlags = kMPEG4Object_AAC_LC;
    inputAduioDes.mFramesPerPacket = 1024;
    inputAduioDes.mChannelsPerFrame = (UInt32)_config.channelCount;
    
    // 填充输出相关信息
    UInt32 inDesSize = sizeof(inputAduioDes);
    AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &inDesSize, &inputAduioDes);
    
    // 获取解码器的描述信息(只能传入software)
    AudioClassDescription *audioClassDesc = [self getAudioCalssDescriptionWithType:outputAudioDes.mFormatID fromManufacture:kAppleSoftwareAudioCodecManufacturer];
    /** 创建converter
     参数1：输入音频格式描述
     参数2：输出音频格式描述
     参数3：class desc的数量
     参数4：class desc
     参数5：创建的解码器
     */
    OSStatus status = AudioConverterNewSpecific(&inputAduioDes, &outputAudioDes, 1, audioClassDesc, &_audioConverter);
    if (status != noErr) {
        NSLog(@"CQAudioDecoder - Error！：硬解码AAC创建失败, status= %d", (int)status);
        return;
    }
}

/**
 获取解码器类型描述
 参数1：类型
 */
- (AudioClassDescription *)getAudioCalssDescriptionWithType: (AudioFormatID)type fromManufacture: (uint32_t)manufacture {
    static AudioClassDescription desc;
    UInt32 decoderSpecific = type;
    // 获取满足AAC解码器的总大小
    UInt32 size;
    /**
     参数1：编码器类型（解码）
     参数2：类型描述大小
     参数3：类型描述
     参数4：大小
     */
    OSStatus status = AudioFormatGetPropertyInfo(kAudioFormatProperty_Decoders, sizeof(decoderSpecific), &decoderSpecific, &size);
    if (status != noErr) {
        NSLog(@"Error！：硬解码AAC get info 失败, status= %d", (int)status);
        return nil;
    }
    // 计算aac解码器的个数
    unsigned int count = size / sizeof(AudioClassDescription);
    // 创建一个包含count个解码器的数组
    AudioClassDescription description[count];
    // 将满足aac解码的解码器的信息写入数组
    status = AudioFormatGetProperty(kAudioFormatProperty_Encoders, sizeof(decoderSpecific), &decoderSpecific, &size, &description);
    if (status != noErr) {
        NSLog(@"Error！：硬解码AAC get propery 失败, status= %d", (int)status);
        return nil;
    }
    for (unsigned int i = 0; i < count; i++) {
        if (type == description[i].mSubType && manufacture == description[i].mManufacturer) {
            desc = description[i];
            return &desc;
        }
    }
    return nil;
}

#pragma mark - AudioToolBox
// 解码器回调函数，在这里填充回调数据
static OSStatus AudioDecoderConverterComplexInputDataProc(  AudioConverterRef inAudioConverter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData,  AudioStreamPacketDescription **outDataPacketDescription,  void *inUserData) {
    CQAudioUserData *audioDecoder = (CQAudioUserData *)(inUserData);
    if (audioDecoder->size <= 0) {
        ioNumberDataPackets = 0;
        return -1;
    }
    
    // 填充数据
    *outDataPacketDescription = &audioDecoder->packetDesc;
    (*outDataPacketDescription)[0].mStartOffset = 0;
    (*outDataPacketDescription)[0].mDataByteSize = audioDecoder->size;
    (*outDataPacketDescription)[0].mVariableFramesInPacket = 0;
    
    ioData->mBuffers[0].mData = audioDecoder->data;
    ioData->mBuffers[0].mDataByteSize = audioDecoder->size;
    ioData->mBuffers[0].mNumberChannels = audioDecoder->channelCount;
    
    return noErr;
}


@end
