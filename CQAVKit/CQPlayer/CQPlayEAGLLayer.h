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

@property (nonatomic, assign) CVPixelBufferRef pixelBuffer;

- (instancetype)initWithFrame:(CGRect)frame;

- (void)resetRenderBuffer;

@end

NS_ASSUME_NONNULL_END
