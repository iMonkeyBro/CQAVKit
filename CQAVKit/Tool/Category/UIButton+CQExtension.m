//
//  UIButton+CQExtension.m
//  CQAVKit
//
//  Created by 刘超群 on 2021/12/2.
//

#import "UIButton+CQExtension.h"
#import <objc/runtime.h>

@implementation UIButton (CQExtension)

#pragma mark - Public Func
// 设置图文样式和图文间距
- (void)cq_setStyle:(CQBtnStyle)style padding:(CGFloat)padding {
    self.cq_btnStyle = style;
    self.cq_padding = padding;
}

// 设置touchUpInside回调的block
- (void)cq_touchUpInsideBlock:(CQButtonTouchUpInsideBlock)block {
    if (block) objc_setAssociatedObject(self, "CQTouchUpInsideKey", block, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self addTarget:self action:@selector(handleTouchUpInside:) forControlEvents:UIControlEventTouchUpInside];
}

// 使用颜色设置按钮背景
- (void)cq_setBackgroundColor:(UIColor *)bgColor forState:(UIControlState)state {
    if (!bgColor) {
        return;
    }
    NSDictionary *localInfo = objc_getAssociatedObject(self, "CQBackgroundImageColorInfo") ?:[NSDictionary dictionary];
    NSMutableDictionary *tempInfo = [NSMutableDictionary dictionaryWithDictionary:localInfo];
    tempInfo[[NSString stringWithFormat:@"%ld",(long)state]] = bgColor;
    objc_setAssociatedObject(self, "CQBackgroundImageColorInfo", tempInfo, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [self setBackgroundImage:[self cq_rectImageWithColor:bgColor size:CGSizeMake(1, 1)] forState:state];
}


#pragma mark - 方法交换
+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self changeOrignalSEL:@selector(layoutSubviews) swizzleSEL:@selector(cq_LayoutSubviews)];
    });
}


+ (void)changeOrignalSEL:(SEL)orignalSEL swizzleSEL:(SEL)swizzleSEL {
    Method originalMethod = class_getInstanceMethod([self class], orignalSEL);
    Method swizzleMethod = class_getInstanceMethod([self class], swizzleSEL);
    if (class_addMethod([self class], orignalSEL, method_getImplementation(swizzleMethod), method_getTypeEncoding(swizzleMethod))) {
        class_replaceMethod([self class], swizzleSEL, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzleMethod);
    }
}


/// 交换布局方法
- (void)cq_LayoutSubviews {
    [self cq_LayoutSubviews];
    if (self.imageView && self.imageView.image && self.titleLabel && self.titleLabel.text) {
        [self configButtonStyle];
        return;
    }
}

/// 配置按钮风格
- (void)configButtonStyle {
    //文案的宽度
    CGFloat labelWidth = self.titleLabel.frame.size.width;
    //文案的高度
    CGFloat labelHeight = self.titleLabel.frame.size.height;
    //button的image
    UIImage *image = self.currentImage;
    
    switch (self.cq_btnStyle) {
        case CQBtnStyleImgLeft: {
            self.imageEdgeInsets = UIEdgeInsetsMake(self.cq_space, -self.cq_padding / 2, self.cq_space, self.cq_padding / 2);
            self.titleEdgeInsets = UIEdgeInsetsMake(0, self.cq_padding / 2, 0, -self.cq_padding / 2);
        }
            break;
        case CQBtnStyleImgRight: {
            //设置后的image显示的高度
            CGFloat imageHeight = self.frame.size.height - (2 * self.cq_space);
            CGFloat imageWidth = image.size.width;
            //是否图片较大
            if (imageHeight < image.size.height) {
                imageWidth = (imageHeight / image.size.height) * image.size.width;
            }
            self.imageEdgeInsets = UIEdgeInsetsMake(self.cq_space, labelWidth + self.cq_padding / 2, self.cq_space, -labelWidth - (self.cq_padding / 2));
            self.titleEdgeInsets = UIEdgeInsetsMake(0, -imageWidth - (self.cq_padding / 2), 0, imageWidth + (self.cq_padding / 2));
        }
            break;
        case CQBtnStyleImgTop: {
            //设置后的image显示的高度
            CGFloat imageHeight = self.frame.size.height - (2 * self.cq_space) - labelHeight - self.cq_padding;
            if (imageHeight > image.size.height) {
                imageHeight = image.size.height;
            }
            self.imageEdgeInsets = UIEdgeInsetsMake(self.cq_space, (self.frame.size.width - imageHeight) / 2, self.cq_space + labelHeight + self.cq_padding, (self.frame.size.width - imageHeight) / 2);
            self.titleEdgeInsets = UIEdgeInsetsMake(self.cq_space + imageHeight + self.cq_padding, -image.size.width, self.cq_space, 0);
        }
            break;
        case CQBtnStyleImgDown: {
            //设置后的image显示的高度
            CGFloat imageHeight = self.frame.size.height - (2 * self.cq_space) - labelHeight - self.cq_padding;
            if (imageHeight > image.size.height) {
                imageHeight = image.size.height;
            }
            self.imageEdgeInsets = UIEdgeInsetsMake(self.cq_space + labelHeight + self.cq_padding, (self.frame.size.width - imageHeight) / 2, self.cq_space, (self.frame.size.width - imageHeight) / 2);
            self.titleEdgeInsets = UIEdgeInsetsMake(self.cq_space, -image.size.width, self.cq_padding + imageHeight + self.cq_space, 0);
        }
            break;
        default:
            break;
    }
}



#pragma mark - Set Get
// 设置图文样式Setter
- (void)setCq_btnStyle:(CQBtnStyle)btnStyle {
    NSNumber *number = [NSNumber numberWithInteger:(NSInteger)btnStyle];
    objc_setAssociatedObject(self, "cqBtnStyleKey", number, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

// 获取图文样式Getter
- (CQBtnStyle)cq_btnStyle {
    NSNumber *number = objc_getAssociatedObject(self, "cqBtnStyleKey");
    return number ? (CQBtnStyle)[number integerValue] : CQBtnStyleDefault;
}

// 设置图文间距Setter
- (void)setCq_space:(CGFloat)cq_space {
    NSNumber *number = [NSNumber numberWithFloat:cq_space];
    objc_setAssociatedObject(self, "cqSpaceKey", number, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

// 获取图文间距Getter
- (CGFloat)cq_space {
    NSNumber *number = objc_getAssociatedObject(self, "cqSpaceKey");
    return number ? [number floatValue] : 0.5f;
}

// 设置图文间距Setter
- (void)setCq_padding:(CGFloat)cq_padding {
    NSNumber *number = [NSNumber numberWithFloat:cq_padding];
    objc_setAssociatedObject(self, "cqPaddingKey", number, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

// 获取图文间距Getter
- (CGFloat)cq_padding {
    NSNumber *number = objc_getAssociatedObject(self, "cqPaddingKey");
    return number ? [number floatValue] : 0.5f;
}

#pragma mark - Private Func
/// 事件回调
- (void)handleTouchUpInside:(UIButton *)sender {
    CQButtonTouchUpInsideBlock block = objc_getAssociatedObject(self, "CQTouchUpInsideKey");
    if (block) {
        block(sender);
    }
}

/// 内部更改DarkMode切换时背景
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    NSDictionary *infoDict = objc_getAssociatedObject(self, "CQBackgroundImageColorInfo");
    if (infoDict && [infoDict isKindOfClass:[NSDictionary class]]) {
        [infoDict enumerateKeysAndObjectsUsingBlock:^(NSString *key, UIColor *bgColor, BOOL *stop) {
            [self cq_setBackgroundColor:bgColor forState:[key integerValue]];
        }];
    }
}

/// 绘制矩形图片
- (UIImage *)cq_rectImageWithColor:(UIColor *)color size:(CGSize)size {
    CGRect rect = CGRectMake(0, 0, size.width, size.height);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, color.CGColor);
    CGContextFillRect(context, rect);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}


@end
