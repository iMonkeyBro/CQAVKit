//
//  CQCameraShutterButton.h
//  CQAVKit
//
//  Created by 刘超群 on 2021/12/2.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, CQCameraShutterButtonMode) {
    CQCameraShutterButtonModePhoto = 0, ///< 拍照片
    CQCameraShutterButtonModeVideo = 1,  ///< 拍视频
};

@interface CQCameraShutterButton : UIButton

+ (instancetype)shutterButton;
+ (instancetype)shutterButtonWithMode:(CQCameraShutterButtonMode)captureButtonMode;
- (instancetype)initWithMode:(CQCameraShutterButtonMode)mode;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@property (nonatomic, assign) CQCameraShutterButtonMode mode;

@end

NS_ASSUME_NONNULL_END
