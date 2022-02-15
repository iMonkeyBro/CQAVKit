//
//  CQCoderConfig.m
//  CQAVKit
//
//  Created by 刘超群 on 2022/2/5.
//

#import "CQCoderConfig.h"

@implementation CQVideoCoderConfig
+ (instancetype)defaultConifg {
    return [[CQVideoCoderConfig alloc] init];
}
- (instancetype)init
{
    self = [super init];
    if (self) {
        self.width = 480;
        self.height = 640;
        self.bitrate = 640*1000;
        self.fps = 25;
    }
    return self;
}

@end

@implementation CQAudioCoderConfig

+ (instancetype)defaultConifg {
    return  [[CQAudioCoderConfig alloc] init];
}
- (instancetype)init
{
    self = [super init];
    if (self) {
        self.bitrate = 96000;
        self.channelCount = 1;
        self.sampleSize = 16;
        self.sampleRate = 44100;
    }
    return self;
}

@end
