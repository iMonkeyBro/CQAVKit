//
//  CQCapturePreviewView.m
//  CQAVKit
//
//  Created by 刘超群 on 2021/10/28.
//

#import "CQCapturePreviewView.h"

#define BOX_BOUNDS CGRectMake(0.0f, 0.0f, 150, 150.0f)

@interface CQCapturePreviewView ()
@property (nonatomic, strong) UIView *focusBoxView;  ///< 对焦框
@property (nonatomic, strong) UIView *exposureBoxView;  ///< 曝光框
@property (nonatomic, strong) UITapGestureRecognizer *singleTapRecognizer;  ///< 单击手势
@property (nonatomic, strong) UITapGestureRecognizer *doubleTapRecognizer;  ///< 双击手势
@property (nonatomic, strong) UITapGestureRecognizer *doubleDoubleTapRecognizer;  ///< 双指双击手势

/******人脸识别框*****/
@property(nonatomic, strong) CALayer *overlayLayer;  ///< 承载人脸识别layer
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, CALayer *> *faceLayers;  ///< 人脸识别layer集合，key是faceID

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
        [self.delegate didTapFocusAtPoint:[self captureDevicePointForPoint:point]];
    }
}

- (void)doubleTapAction:(UITapGestureRecognizer *)sender {
    CGPoint point = [sender locationInView:self];
    [self runBoxViewAnimation:self.exposureBoxView atPoint:point];
    if (self.delegate && [self.delegate respondsToSelector:@selector(didTapExposeAtPoint:)]) {
        [self.delegate didTapExposeAtPoint:[self captureDevicePointForPoint:point]];
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
    // 坐标系转换，获取屏幕中心点坐标
    // 设备坐标转为屏幕坐标，
    // 捕捉设备空间左上角（0，0），右下角（1，1） 中心点则（0.5，0.5）
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
    [self.layer addSublayer:self.overlayLayer];
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

- (void)setFaceMetadataObjects:(NSArray<AVMetadataFaceObject *> *)faceMetadataObjects {
    _faceMetadataObjects = faceMetadataObjects;
    NSArray *transformedFaces = [self transformedMetadataObjects:faceMetadataObjects];
    NSMutableArray *needRemoveFaces = [self.faceLayers.allKeys mutableCopy];  // 需要删除的
    for (AVMetadataFaceObject *faceObj in transformedFaces) {
        NSNumber *faceID = @(faceObj.faceID);
        // 存在的不需要删除，从删除数组中移除
        [needRemoveFaces removeObject:faceID];
        // 拿到当前faceID对应的layer
        CALayer *faceLayer = self.faceLayers[faceID];
        // 如果给定的faceID 没有找到对应的图层，创建一个新的，找的则直接使用
        if (!faceLayer) {
            faceLayer = [CALayer layer];
            faceLayer.borderWidth = 5.0f;
            faceLayer.borderColor = [UIColor redColor].CGColor;
//            faceLayer.contents = (id)[UIImage imageNamed:@"faceLayer.jpeg"].CGImage;
            [self.overlayLayer addSublayer:faceLayer];
            self.faceLayers[faceID] = faceLayer;
        }
        // 图层的大小 = 人脸的大小
        faceLayer.frame = faceObj.bounds;
        // 设置图层的transform属性 CATransform3DIdentity 先创建一个3D单元矩阵
        faceLayer.transform = CATransform3DIdentity;
        // 判断人脸对象是否具有有效的倾斜旋转。围绕Z轴，例人脸向肩膀转动
        if (faceObj.hasRollAngle) {
            // 度数转弧度，拿到矩阵
            CATransform3D t = [self transformForRollAngle:faceObj.rollAngle];
            // 矩阵相乘
            faceLayer.transform = CATransform3DConcat(faceLayer.transform, t);
        }
        // 判断人脸对象是否具有有效的偏转角，围绕Y轴，例如点头
        if (faceObj.hasYawAngle) {
            // 获取相应的CATransform3D值
            CATransform3D  t = [self transformForYawAngle:faceObj.yawAngle];
            faceLayer.transform = CATransform3DConcat(faceLayer.transform, t);
        }
    }
    for (NSNumber *faceID in needRemoveFaces) {
        CALayer *layer = self.faceLayers[faceID];
        [layer removeFromSuperlayer];
        [self.faceLayers removeObjectForKey:faceID];
    }
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

- (NSMutableDictionary<NSNumber *,CALayer *> *)faceLayers {
    if (!_faceLayers) {
        _faceLayers = [NSMutableDictionary dictionary];
    }
    return _faceLayers;
}

- (CALayer *)overlayLayer {
    if (!_overlayLayer) {
        _overlayLayer = [CALayer layer];
        _overlayLayer.frame = self.bounds;
        // 设置投影方式
        _overlayLayer.sublayerTransform = [self transform3DMakePerspective:1000];
    }
    return _overlayLayer;
}

#pragma mark - 人脸识别layer相关函数
/**
 透视投影
 投影方式 正投影，无法体现立体效果   透视投影，体现立体效果
 @param eyePosition 观察者到投射面的距离，一般500-1000
 */
- (CATransform3D)transform3DMakePerspective:(CGFloat)eyePosition {
    // CATransform3D 图层的旋转，缩放，偏移，歪斜和应用的透
    // CATransform3DIdentity是单位矩阵，该矩阵没有缩放，旋转，歪斜，透视。该矩阵应用到图层上，就是设置默认值。
    CATransform3D  transform = CATransform3DIdentity;
    // 透视效果（就是近大远小），是通过设置m34 m34 = -1.0/D 默认是0.D越小透视效果越明显
    // eyePosition 观察者到投射面的距离，一般500-1000
    transform.m34 = -1.0/eyePosition;
    return transform;
}

/// 摄像头元数据转换
- (NSArray<AVMetadataObject *> *)transformedMetadataObjects:(NSArray<AVMetadataObject *> *)medMetadataObjects {
    NSMutableArray *transformedMetadatas = [NSMutableArray array];
    for (AVMetadataObject *metadataObject in medMetadataObjects) {
        // 将摄像头的元数据 转换为 视图上的可展示的元数据
        // 简单说：UIKit的坐标 与 摄像头坐标系统（0，0）-（1，1）不一样。所以需要转换
        // 转换需要考虑图层、镜像、视频重力、方向等因素 在iOS6.0之前需要开发者自己计算，但iOS6.0后提供方法
        AVMetadataObject *transformedMetadata = [(AVCaptureVideoPreviewLayer *)self.layer transformedMetadataObjectForMetadataObject:metadataObject];
        [transformedMetadatas addObject:transformedMetadata];
    }
    return transformedMetadatas;
}

/// 将RollAngle 的 度数转弧度 再生成 CATransform3D
- (CATransform3D)transformForRollAngle:(CGFloat)rollAngleInDegrees {
    // 将人脸对象得到的RollAngle 单位“度” 转为Core Animation需要的弧度值
    CGFloat rollAngleInRadians = [self degreesToRadians:rollAngleInDegrees];
    // RollAngle围绕Z旋转 x,y,z轴为0，0，1 得到绕Z轴倾斜角旋转转换
    return CATransform3DMakeRotation(rollAngleInRadians, 0.0f, 0.0f, 1.0f);
}

/// 将YawAngle 的 度数转弧度 再生成 CATransform3D
- (CATransform3D)transformForYawAngle:(CGFloat)yawAngleInDegrees {
    // 将角度转换为弧度值
     CGFloat yawAngleInRaians = [self degreesToRadians:yawAngleInDegrees];
    // 绕Y轴旋转
    // 由于overlayer 需要应用sublayerTransform，所以图层会投射到z轴上，人脸从一侧转向另一侧会有3D 效果
    CATransform3D yawTransform = CATransform3DMakeRotation(yawAngleInRaians, 0.0f, -1.0f, 0.0f);
    // 因为应用程序的界面固定为垂直方向，但需要为设备方向计算一个相应的旋转变换
    // 如果不这样，会造成人脸图层的偏转效果不正确，会看起来比较傻不自然
    return CATransform3DConcat(yawTransform, [self orientationTransform]);
}

/// 度数转弧度
- (CGFloat)degreesToRadians:(CGFloat)degrees {
    return degrees * M_PI / 180;
}

/// 根据设备方向调整角度
- (CATransform3D)orientationTransform {
    CGFloat angle = 0.0;
    // 拿到设备方向
    switch ([UIDevice currentDevice].orientation) {
            // 下
        case UIDeviceOrientationPortraitUpsideDown:
            angle = M_PI;
            break;
            // 右
        case UIDeviceOrientationLandscapeRight:
            angle = -M_PI / 2.0f;
            break;
            // 左
        case UIDeviceOrientationLandscapeLeft:
            angle = M_PI /2.0f;
            break;
            // 其他
        default:
            angle = 0.0f;
            break;
    }
    return CATransform3DMakeRotation(angle, 0.0f, 0.0f, 1.0f);
}

@end
