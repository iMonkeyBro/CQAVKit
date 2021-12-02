//
//  CQCameraShutterButton.m
//  CQAVKit
//
//  Created by 刘超群 on 2021/12/2.
//

#import "CQCameraShutterButton.h"

#define kLINE_WIDTH 6.0f
#define kDEFAULT_FRAME CGRectMake(0.0f, 0.0f, 68.0f, 68.0f)

@interface CQCameraShutterButton ()
@property (nonatomic, strong) CALayer *circleLayer;

@end

@implementation CQCameraShutterButton

#pragma mark -Init
+ (instancetype)shutterButton {
    return [[self alloc] initWithMode:0];
}

+ (instancetype)shutterButtonWithMode:(CQCameraShutterButtonMode)mode {
    return [[self alloc] initWithMode:mode];
}

- (instancetype)initWithMode:(CQCameraShutterButtonMode)mode {
    self = [super initWithFrame:kDEFAULT_FRAME];
    if (self) {
        _mode = mode;
        [self configUI];
    }
    return self;
}

#pragma mark -Setter
- (void)setMode:(CQCameraShutterButtonMode)mode {
    if (_mode != mode) {
        _mode = mode;
        UIColor *toColor = (mode == CQCameraShutterButtonModeVideo) ? [UIColor redColor] : [UIColor whiteColor];
        self.circleLayer.backgroundColor = toColor.CGColor;
    }
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    CABasicAnimation *fadeAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    fadeAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    fadeAnimation.duration = 0.2f;
    if (highlighted) {
        fadeAnimation.toValue = @0.0f;
    } else {
        fadeAnimation.toValue = @1.0f;
    }
    self.circleLayer.opacity = [fadeAnimation.toValue floatValue];
    [self.circleLayer addAnimation:fadeAnimation forKey:@"fadeAnimation"];
}

- (void)setSelected:(BOOL)selected {
    [super setSelected:selected];
    if (self.mode == CQCameraShutterButtonModeVideo) {
        [CATransaction disableActions];
        CABasicAnimation *scaleAnimation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
        CABasicAnimation *radiusAnimation = [CABasicAnimation animationWithKeyPath:@"cornerRadius"];
        if (selected) {
            scaleAnimation.toValue = @0.6f;
            radiusAnimation.toValue = @(self.circleLayer.bounds.size.width / 4.0f);
        } else {
            scaleAnimation.toValue = @1.0f;
            radiusAnimation.toValue = @(self.circleLayer.bounds.size.width / 2.0f);
        }
        
        CAAnimationGroup *animationGroup = [CAAnimationGroup animation];
        animationGroup.animations = @[scaleAnimation, radiusAnimation];
        animationGroup.beginTime = CACurrentMediaTime() + 0.2f;
        animationGroup.duration = 0.35f;
        [self.circleLayer setValue:radiusAnimation.toValue forKeyPath:@"cornerRadius"];
        [self.circleLayer setValue:scaleAnimation.toValue forKeyPath:@"transform.scale"];
        [self.circleLayer addAnimation:animationGroup forKey:@"scaleAndRadiusAnimation"];
    }
}

#pragma mark - override
- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextSetLineWidth(context, kLINE_WIDTH);
    CGRect insetRect = CGRectInset(rect, kLINE_WIDTH / 2.0f, kLINE_WIDTH / 2.0f);
    CGContextStrokeEllipseInRect(context, insetRect);
}

#pragma mark -UI
- (void)configUI {
    self.backgroundColor = [UIColor clearColor];
    self.tintColor = [UIColor clearColor];
    [self.layer addSublayer:self.circleLayer];
}

#pragma mark - Lazy Load
- (CALayer *)circleLayer {
    if (!_circleLayer) {
        _circleLayer = [CALayer layer];
        UIColor *circleColor = (self.mode == CQCameraShutterButtonModeVideo) ? [UIColor redColor] : [UIColor whiteColor];
        _circleLayer.backgroundColor = circleColor.CGColor;
        _circleLayer.bounds = CGRectInset(self.bounds, 8.0, 8.0);
        _circleLayer.position = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
        _circleLayer.cornerRadius = _circleLayer.bounds.size.width / 2.0f;
    }
    return _circleLayer;
}

@end
