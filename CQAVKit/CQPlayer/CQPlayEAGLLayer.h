//
//  CQPlayEAGLLayer.h
//  CQAVKit
//
//  Created by 刘超群 on 2022/2/23.
//

#import <QuartzCore/QuartzCore.h>
#import <CoreVideo/CVPixelBuffer.h>

NS_ASSUME_NONNULL_BEGIN

@interface CQPlayEAGLLayer : CAEAGLLayer

- (instancetype)initWithFrame:(CGRect)frame;

/// 重新设置帧缓存区与渲染缓存区
- (void)resetRenderBuffer;

@property (nonatomic, assign) CVPixelBufferRef pixelBuffer;  ///< 需要渲染的buffer

@end

NS_ASSUME_NONNULL_END
