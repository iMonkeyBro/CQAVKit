//
//  CQCapturePreviewView.m
//  CQAVKit
//
//  Created by 刘超群 on 2021/10/28.
//

#import "CQCapturePreviewView.h"

#define BOX_BOUNDS CGRectMake(0.0f, 0.0f, 150, 150.0f)

@interface CQCapturePreviewView ()
@property (strong, nonatomic) UIView *focusBoxView;  ///< 对焦框
@property (strong, nonatomic) UIView *exposureBoxView;  ///< 曝光框
@property (strong, nonatomic) UITapGestureRecognizer *singleTapRecognizer;  ///< 单击手势
@property (strong, nonatomic) UITapGestureRecognizer *doubleTapRecognizer;  ///< 双击手势
@property (strong, nonatomic) UITapGestureRecognizer *doubleDoubleTapRecognizer;  ///< 双指双击手势
@end

@implementation CQCapturePreviewView

- (instancetype)init {
    self = [super init];
    if (self) {
        [self configUI];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self configUI];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self configUI];
    }
    return self;
}

#pragma mark - Events
- (void)singleTapAction:(UITapGestureRecognizer *)sender {
    CGPoint point = [sender locationInView:self];
    [self runBoxViewAnimation:self.focusBoxView atPoint:point];
    if (self.delegate && [self.delegate respondsToSelector:@selector(didTapFocusAtPoint:)]) {
        [self.delegate didTapFocusAtPoint:point];
    }
}

- (void)doubleTapAction:(UITapGestureRecognizer *)sender {
    CGPoint point = [sender locationInView:self];
    [self runBoxViewAnimation:self.exposureBoxView atPoint:point];
    if (self.delegate && [self.delegate respondsToSelector:@selector(didTapExposeAtPoint:)]) {
        [self.delegate didTapExposeAtPoint:point];
    }
}

- (void)doubleDoubleTapAction:(UITapGestureRecognizer *)sender {
    [self runResetAnimation];
    if (self.delegate && [self.delegate respondsToSelector:@selector(didTapResetFocusAndExposure)]) {
        [self.delegate didTapResetFocusAndExposure];
    }
}

#pragma mark - Private Methods
/// 用于支持该类定义的不同触摸处理方法。 将屏幕坐标系上的触控点转换为摄像头上的坐标系点
- (CGPoint)captureDevicePointForPoint:(CGPoint)point {
    // 坐标系转换
    return [(AVCaptureVideoPreviewLayer *)self.layer captureDevicePointOfInterestForPoint:point];
}

/// 对焦框动画展示
- (void)runBoxViewAnimation:(UIView *)boxView atPoint:(CGPoint)point {
    boxView.center = point;
    boxView.hidden = NO;
    [UIView animateWithDuration:0.15f delay:0.0f options:UIViewAnimationOptionCurveEaseInOut animations:^{
        boxView.layer.transform = CATransform3DMakeScale(0.5, 0.5, 1.0);
    } completion:^(BOOL finished) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            boxView.hidden = YES;
            boxView.transform = CGAffineTransformIdentity;
        });
    }];
}

/// 运行重置动画
- (void)runResetAnimation {
    if (!self.isFocusEnabled && !self.isExposeEnabled) return;
    // 坐标系转换
    CGPoint centerPoint = [(AVCaptureVideoPreviewLayer *)self.layer pointForCaptureDevicePointOfInterest:CGPointMake(0.5f, 0.5f)];
    self.focusBoxView.center = centerPoint;
    self.exposureBoxView.center = centerPoint;
    self.exposureBoxView.transform = CGAffineTransformMakeScale(1.2f, 1.2f);
    self.focusBoxView.hidden = NO;
    self.exposureBoxView.hidden = NO;
    [UIView animateWithDuration:0.15f delay:0.0f options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.focusBoxView.layer.transform = CATransform3DMakeScale(0.5, 0.5, 1.0);
        self.exposureBoxView.layer.transform = CATransform3DMakeScale(0.7, 0.7, 1.0);
    } completion:^(BOOL finished) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.focusBoxView.hidden = YES;
            self.focusBoxView.transform = CGAffineTransformIdentity;
            self.exposureBoxView.hidden = YES;
            self.exposureBoxView.transform = CGAffineTransformIdentity;
        });
    }];
}

- (void)configUI {
    [(AVCaptureVideoPreviewLayer *)self.layer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    [self addGestureRecognizer:self.singleTapRecognizer];
    [self addGestureRecognizer:self.doubleTapRecognizer];
    [self addGestureRecognizer:self.doubleDoubleTapRecognizer];
    // 解决单击和双击冲突
    [self.singleTapRecognizer requireGestureRecognizerToFail:self.doubleTapRecognizer];
    [self addSubview:self.focusBoxView];
    [self addSubview:self.exposureBoxView];
}

#pragma mark - override
+ (Class)layerClass {
    // 在UIView 重写layerClass 类方法可以让开发者创建视图实例自定义图层下
    // 重写layerClass方法并返回AVCaptureVideoPrevieLayer类对象
    return AVCaptureVideoPreviewLayer.class;
}

#pragma mark - Setters
- (void)setSession:(AVCaptureSession *)session {
    //重写session属性的访问方法，在setSession:方法中访问视图layer属性。
    //AVCaptureVideoPreviewLayer 实例，并且设置AVCaptureSession 将捕捉数据直接输出到图层中，并确保与会话状态同步。
    [(AVCaptureVideoPreviewLayer*)self.layer setSession:session];
}

- (void)setVideoGravity:(AVLayerVideoGravity)videoGravity {
    [(AVCaptureVideoPreviewLayer*)self.layer setVideoGravity:videoGravity];
}

- (void)setIsFocusEnabled:(BOOL)isFocusEnabled {
    _isFocusEnabled = isFocusEnabled;
    self.singleTapRecognizer.enabled = isFocusEnabled;
}

- (void)setIsExposeEnabled:(BOOL)isExposeEnabled {
    _isExposeEnabled = isExposeEnabled;
    self.doubleTapRecognizer.enabled = isExposeEnabled;
}

#pragma mark - Getters
- (AVCaptureSession *)session {
    // 重写session方法，返回捕捉会话
    return [(AVCaptureVideoPreviewLayer *)self.layer session];
}

#pragma mark - Lazy Load
- (UITapGestureRecognizer *)singleTapRecognizer {
    if (!_singleTapRecognizer) {
        _singleTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(singleTapAction:)];
    }
    return _singleTapRecognizer;
}

- (UITapGestureRecognizer *)doubleTapRecognizer {
    if (!_doubleTapRecognizer) {
        _doubleTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTapAction:)];
        _doubleTapRecognizer.numberOfTapsRequired = 2;
    }
    return _doubleTapRecognizer;
}

- (UITapGestureRecognizer *)doubleDoubleTapRecognizer {
    if (!_doubleDoubleTapRecognizer) {
        _doubleDoubleTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleDoubleTapAction:)];
        _doubleDoubleTapRecognizer.numberOfTapsRequired = 2;
        _doubleDoubleTapRecognizer.numberOfTouchesRequired = 2;
    }
    return _doubleDoubleTapRecognizer;
}

- (UIView *)focusBoxView {
    if (!_focusBoxView) {
        _focusBoxView = [[UIView alloc] initWithFrame:BOX_BOUNDS];
        _focusBoxView.backgroundColor = [UIColor clearColor];
        _focusBoxView.layer.borderColor = [UIColor colorWithRed:0.102 green:0.636 blue:1.000 alpha:1.000].CGColor;
        _focusBoxView.layer.borderWidth = 5.0f;
        _focusBoxView.hidden = YES;
    }
    return _focusBoxView;
}

- (UIView *)exposureBoxView {
    if (!_exposureBoxView) {
        _exposureBoxView = [[UIView alloc] initWithFrame:BOX_BOUNDS];
        _exposureBoxView.backgroundColor = [UIColor clearColor];
        _exposureBoxView.layer.borderColor = [UIColor colorWithRed:1.000 green:0.421 blue:0.054 alpha:1.000].CGColor;
        _exposureBoxView.layer.borderWidth = 5.0f;
        _exposureBoxView.hidden = YES;
    }
    return _exposureBoxView;
}

@end
