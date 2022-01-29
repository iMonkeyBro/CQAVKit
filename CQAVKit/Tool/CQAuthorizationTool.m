//
//  CQAuthorizationTool.m
//  CQAVKit
//
//  Created by 刘超群 on 2022/1/6.
//

#import "CQAuthorizationTool.h"
#import <AVFoundation/AVCaptureDevice.h>
#import <AVFoundation/AVAudioSession.h>

#define kasync_main_safe(block)\
if ([NSThread isMainThread]) {\
block();\
} else {\
dispatch_async(dispatch_get_main_queue(), block);\
}


@implementation CQAuthorizationTool

+ (void)checkCameraAuthorization:(void (^)(BOOL isAuthorization))handler {
    
    /**
     AVAuthorizationStatusNotDetermined = 0, //没有询问是否开启相机
     AVAuthorizationStatusRestricted    = 1, //未授权，家长限制
     AVAuthorizationStatusDenied        = 2, //未授权
     AVAuthorizationStatusAuthorized    = 3, //玩家授权
     */
    
    AVAuthorizationStatus videoStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    switch (videoStatus) {
        case AVAuthorizationStatusNotDetermined:
        {
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                !handler?:handler(granted);
            }];
        }
            break;
        case AVAuthorizationStatusAuthorized:
        {
            !handler?:handler(YES);
        }
            break;
        default:
        {
            !handler?:handler(NO);
        }
            break;
    }
}

+ (void)checkMicrophoneAuthorization:(void (^)(BOOL isAuthorization))handler {
    //麦克风
    AVAudioSessionRecordPermission permissionStatus = [[AVAudioSession sharedInstance] recordPermission];
    switch (permissionStatus) {
        case AVAudioSessionRecordPermissionUndetermined:
        {
            [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
                !handler?:handler(granted);
            }];
        }
            break;
        case AVAudioSessionRecordPermissionDenied://拒绝
        {
            !handler?:handler(NO);
        }
            break;
        case AVAudioSessionRecordPermissionGranted://允许
        {
            !handler?:handler(YES);
        }
            break;
    }
}

@end
