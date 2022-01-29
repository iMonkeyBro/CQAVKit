//
//  CQAuthorizationTool.h
//  CQAVKit
//
//  Created by 刘超群 on 2022/1/6.
//

#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN

@interface CQAuthorizationTool : NSObject

+ (void)checkCameraAuthorization:(void (^)(BOOL isAuthorization))handler;

+ (void)checkMicrophoneAuthorization:(void (^)(BOOL isAuthorization))handler;

@end

NS_ASSUME_NONNULL_END
