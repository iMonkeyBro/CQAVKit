//
//  CQPlayEAGLLayer.m
//  CQAVKit
//
//  Created by 刘超群 on 2022/2/23.
//

#import "CQPlayEAGLLayer.h"
#import <AVFoundation/AVUtilities.h>
#include <OpenGLES/ES2/gl.h>
#include <OpenGLES/ES2/glext.h>

#pragma mark - 枚举
// Uniform index.
enum
{
    UNIFORM_Y,
    UNIFORM_UV,
    UNIFORM_ROTATION_ANGLE,
    UNIFORM_COLOR_CONVERSION_MATRIX,
    NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

// Attribute index.
enum
{
    ATTRIB_VERTEX,
    ATTRIB_TEXCOORD,
    NUM_ATTRIBUTES
};

#pragma mark - 常量
//YUV->RGB
//颜色转换常量（yuv到rgb），包括从16-235/16-240（视频范围）进行调整
static const GLfloat kColorConversion601[] = {
    1.164,  1.164, 1.164,
    0.0, -0.392, 2.017,
    1.596, -0.813,   0.0,
};

// BT.709, 这是高清电视的标准
static const GLfloat kColorConversion709[] = {
    1.164,  1.164, 1.164,
    0.0, -0.213, 2.112,
    1.793, -0.533,   0.0,
};

#pragma mark -  OpenGL ES着色器
/// 片元着色器代码
const GLchar *shader_fsh = (const GLchar*)"varying highp vec2 texCoordVarying;"
"precision mediump float;"
"uniform sampler2D SamplerY;"
"uniform sampler2D SamplerUV;"
"uniform mat3 colorConversionMatrix;"
"void main()"
"{"
"    mediump vec3 yuv;"
"    lowp vec3 rgb;"
//   Subtract constants to map the video range start at 0
"    yuv.x = (texture2D(SamplerY, texCoordVarying).r - (16.0/255.0));"
"    yuv.yz = (texture2D(SamplerUV, texCoordVarying).rg - vec2(0.5, 0.5));"
"    rgb = colorConversionMatrix * yuv;"
"    gl_FragColor = vec4(rgb, 1);"
"}";

/// 顶点着色器代码
const GLchar *shader_vsh = (const GLchar*)"attribute vec4 position;"
"attribute vec2 texCoord;"
"uniform float preferredRotation;"
"varying vec2 texCoordVarying;"
"void main()"
"{"
"    mat4 rotationMatrix = mat4(cos(preferredRotation), -sin(preferredRotation), 0.0, 0.0,"
"                               sin(preferredRotation),  cos(preferredRotation), 0.0, 0.0,"
"                               0.0,                        0.0, 1.0, 0.0,"
"                               0.0,                        0.0, 0.0, 1.0);"
"    gl_Position = position * rotationMatrix;"
"    texCoordVarying = texCoord;"
"}";

@interface CQPlayEAGLLayer ()
@property (nonatomic, assign) GLuint program;

@end

@implementation CQPlayEAGLLayer
{
    // CAEAGLLayer尺寸相关
    GLint _backingWidth;  ///< 宽
    GLint _backingHeight; //高
    EAGLContext *_context;
    /*
     YUV分为2个YUV视频帧分为亮度和色度两个纹理，
     分别用GL_LUMINANCE格式和GL_LUMINANCE_ALPHA格式读取。
     */
    CVOpenGLESTextureRef _lumaTexture;  ///< 亮度纹理
    CVOpenGLESTextureRef _chromaTexture;  ///< 色度纹理
    
    GLuint _frameBufferHandle;  ///< 帧缓存区
    GLuint _colorBufferHandle;  ///< 颜色缓存区
    
    const GLfloat *_preferredConversion;  ///<选择颜色通道
}

#pragma mark - Init
- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super init]) {
        CGFloat scale = [[UIScreen mainScreen] scale];
        self.contentsScale = scale;
        //一个布尔值，指示层是否包含完全不透明的内容.默认为NO
        self.opaque = TRUE;
        /*
         kEAGLDrawablePropertyRetainedBacking 可绘制表面在显示后是否保留其内容,默认为NO.
         */
        self.drawableProperties = @{ kEAGLDrawablePropertyRetainedBacking:[NSNumber numberWithBool:YES]};
        // 设置layer图层frame
        [self setFrame:frame];
        
        // 设置绘制框架的上下文.
        _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        if (!_context) {
            return nil;
        }
        
        // 视频质量标准  BT.709，这是HDTV的标准
        _preferredConversion = kColorConversion709;
        [self setupGL];
    }
    return self;
}

- (void)dealloc {
    if (!_context || ![EAGLContext setCurrentContext:_context]) {
        return;
    }
    [self cleanUpTextures];
    if (_pixelBuffer) {
        CVPixelBufferRelease(_pixelBuffer);
    }
    if (self.program) {
        glDeleteProgram(self.program);
        self.program = 0;
    }
    if (_context) {
        _context = nil;
    }
}

#pragma mark - Setter
- (void)setPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    // 先释放当前的
    if(_pixelBuffer) {
        CVPixelBufferRelease(_pixelBuffer);
    }
    /*
     在iOS里，我们经常能看到 CVPixelBufferRef 这个类型，在Camera 采集返回的数据里得到一个CMSampleBufferRef，而每个CMSampleBufferRef里则包含一个 CVPixelBufferRef，在视频硬解码的返回数据里也是一个 CVPixelBufferRef（里面包好了所有的压缩的图片信息）。CVPixelBufferRef：是一种像素图片类型，由于CV开头，所以它是属于 CoreVideo 模块的。
     
     */
    _pixelBuffer = CVPixelBufferRetain(pixelBuffer);
    
    // 获取视频帧的宽与高
    int frameWidth = (int)CVPixelBufferGetWidth(_pixelBuffer);
    int frameHeight = (int)CVPixelBufferGetHeight(_pixelBuffer);
    
    // 显示_pixelBuffer
    /*
     参数1: 显示数据
     参数2: frame宽
     参数3: frame高
     */
    [self displayPixelBuffer:_pixelBuffer width:frameWidth height:frameHeight];
}

#pragma mark - 渲染
/// 显示CVPixelBufferRef
- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer width:(uint32_t)frameWidth height:(uint32_t)frameHeight {
    // 判断_context 是否创建成功.不成功则无法继续
    if (!_context || ![EAGLContext setCurrentContext:_context]) {
        return;
    }
    
    // 判断需要显示的数据是否为空.为空则返回并给出错误信息
    if(pixelBuffer == NULL) {
        NSLog(@"Pixel buffer is null");
        return;
    }
    
    CVReturn err;
    // 返回像素缓冲区的平面数
    size_t planeCount = CVPixelBufferGetPlaneCount(pixelBuffer);
    
    /*
     使用像素缓冲区的颜色附件确定适当的颜色转换矩阵.
     参数1: 像素缓存区
     参数2: kCVImageBufferYCbCrMatrixKey  YCbCr->RGB
     参数3: 附件模式,NULL
     */
    CFTypeRef colorAttachments = CVBufferGetAttachment(pixelBuffer, kCVImageBufferYCbCrMatrixKey, NULL);
    
    // 将一个字符串中的字符范围与另一个字符串中的字符范围进行比较
    /*
     参数1:theString1,用于比较的第一个字符串
     参数2:theString2,用于比较的第二个字符串。
     参数3:rangeToCompare,要比较的字符范围。要使用整个字符串，请传递范围或使用。指定的范围不得超过字符串的长度
     
     */
    if (CFStringCompare(colorAttachments, kCVImageBufferYCbCrMatrix_ITU_R_601_4, 0) == kCFCompareEqualTo) {
        _preferredConversion = kColorConversion601;
    }
    else {
        _preferredConversion = kColorConversion709;
    }
    
    /*
     CVOpenGLESTextureCacheCreateTextureFromImage 将创建 GLES texture 从 CVPixelBufferRef.
     */
    
    /*
     从像素缓存区pixelBuffer创建Y和UV纹理,这些纹理会被绘制在帧缓存区的Y平面上.
     */
    
    CVOpenGLESTextureCacheRef _videoTextureCache;
    
    /*
     CVOpenGLESTextureCacheCreate
     功能:   创建 CVOpenGLESTextureCacheRef 创建新的纹理缓存
     参数1:  kCFAllocatorDefault默认内存分配器.
     参数2:  NULL
     参数3:  EAGLContext  图形上下文
     参数4:  NULL
     参数5:  新创建的纹理缓存
     @result kCVReturnSuccess
     */
    err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _context, NULL, &_videoTextureCache);
    if (err != noErr) {
        NSLog(@"Error at CVOpenGLESTextureCacheCreate %d", err);            
        return;
    }
    
    // 处理Y纹理
    // 激活纹理
    glActiveTexture(GL_TEXTURE0);
    // 创建亮度纹理-Y纹理
    /*
     CVOpenGLESTextureCacheCreateTextureFromImage
     功能:根据CVImageBuffer创建CVOpenGlESTexture 纹理对象
     参数1: 内存分配器,kCFAllocatorDefault
     参数2: 纹理缓存.纹理缓存将管理纹理的纹理缓存对象
     参数3: sourceImage.
     参数4: 纹理属性.默认给NULL
     参数5: 目标纹理,GL_TEXTURE_2D
     参数6: 指定纹理中颜色组件的数量(GL_RGBA, GL_LUMINANCE, GL_RGBA8_OES, GL_RG, and GL_RED (NOTE: 在 GLES3 使用 GL_R8 替代 GL_RED).)
     参数7: 帧宽度
     参数8: 帧高度
     参数9: 格式指定像素数据的格式
     参数10: 指定像素数据的数据类型,GL_UNSIGNED_BYTE
     参数11: planeIndex
     参数12: 纹理输出新创建的纹理对象将放置在此处。
     */
    err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                       _videoTextureCache,
                                                       pixelBuffer,
                                                       NULL,
                                                       GL_TEXTURE_2D,
                                                       GL_RED_EXT,
                                                       frameWidth,
                                                       frameHeight,
                                                       GL_RED_EXT,
                                                       GL_UNSIGNED_BYTE,
                                                       0,
                                                       &_lumaTexture);
    if (err) {
        NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
    }
    
    // 配置亮度纹理属性
    // 绑定纹理.
    glBindTexture(CVOpenGLESTextureGetTarget(_lumaTexture), CVOpenGLESTextureGetName(_lumaTexture));
    // 配置纹理放大/缩小过滤方式以及纹理围绕S/T环绕方式
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);  // 缩小
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);  // 放大
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);  // S环绕方式
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);  // T环绕方式
    
    // 亮度纹理配置完，已经可以成像(黑白效果)
    
    // UV-plane 纹理
    // 如果颜色通道个数>1,则除了Y还有UV-Plane.
    if (planeCount == 2) {
        // UV-plane.
        // 激活UV-plane纹理
        glActiveTexture(GL_TEXTURE1);
        // 创建UV-plane纹理
        /*
         CVOpenGLESTextureCacheCreateTextureFromImage
         功能:根据CVImageBuffer创建CVOpenGlESTexture 纹理对象
         参数1: 内存分配器,kCFAllocatorDefault
         参数2: 纹理缓存.纹理缓存将管理纹理的纹理缓存对象
         参数3: sourceImage.
         参数4: 纹理属性.默认给NULL
         参数5: 目标纹理,GL_TEXTURE_2D
         参数6: 指定纹理中颜色组件的数量(GL_RGBA, GL_LUMINANCE, GL_RGBA8_OES, GL_RG, and GL_RED (NOTE: 在 GLES3 使用 GL_R8 替代 GL_RED).)
         参数7: 帧宽度
         参数8: 帧高度
         参数9: 格式指定像素数据的格式
         参数10: 指定像素数据的数据类型,GL_UNSIGNED_BYTE
         参数11: planeIndex
         参数12: 纹理输出新创建的纹理对象将放置在此处。
         */
        err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                           _videoTextureCache,
                                                           pixelBuffer,
                                                           NULL,
                                                           GL_TEXTURE_2D,
                                                           GL_RG_EXT,
                                                           frameWidth / 2,
                                                           frameHeight / 2,
                                                           GL_RG_EXT,
                                                           GL_UNSIGNED_BYTE,
                                                           1,
                                                           &_chromaTexture);
        if (err) {
            NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
        }
        
        // 绑定纹理
        glBindTexture(CVOpenGLESTextureGetTarget(_chromaTexture), CVOpenGLESTextureGetName(_chromaTexture));
        // 配置纹理放大/缩小过滤方式以及纹理围绕S/T环绕方式
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    }
    
    // 绑定帧缓存区
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBufferHandle);
    
    // 设置视口.
    glViewport(0, 0, _backingWidth, _backingHeight);
    
    // 清理颜色缓冲区
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    
    // 使用shaderProgram
    glUseProgram(self.program);
    // 传递Uniform属性到shader
    // UNIFORM_ROTATION_ANGLE 旋转角度
    glUniform1f(uniforms[UNIFORM_ROTATION_ANGLE], 0);
    // UNIFORM_COLOR_CONVERSION_MATRIX YUV->RGB颜色矩阵
    glUniformMatrix3fv(uniforms[UNIFORM_COLOR_CONVERSION_MATRIX], 1, GL_FALSE, _preferredConversion);
    
    // 根据视频的方向和纵横比设置最终显示视频的frame
    CGRect viewBounds = self.bounds;
    CGSize contentSize = CGSizeMake(frameWidth, frameHeight);
    
    /*
     计算纵横比
     AVMakeRectWithAspectRatioInsideRect
     功能: 返回一个按比例缩放的CGRect，该CGRect保持由边界CGRect内的CGSize指定的纵横比
     参数1:希望保持的宽高比或纵横比
     参数2:填充的rect
     */
    CGRect vertexSamplingRect = AVMakeRectWithAspectRatioInsideRect(contentSize, viewBounds);
    
    // 计算标准化的四边形坐标以将帧绘制到其中
    // 标准化采样大小
    CGSize normalizedSamplingSize = CGSizeMake(0.0, 0.0);
    // 标准化规模
    CGSize cropScaleAmount = CGSizeMake(vertexSamplingRect.size.width/viewBounds.size.width,vertexSamplingRect.size.height/viewBounds.size.height);
    
    // 规范化四元顶点
    if (cropScaleAmount.width > cropScaleAmount.height) {
        normalizedSamplingSize.width = 1.0;
        normalizedSamplingSize.height = cropScaleAmount.height/cropScaleAmount.width;
    } else {
        normalizedSamplingSize.width = cropScaleAmount.width/cropScaleAmount.height;
        normalizedSamplingSize.height = 1.0;;
    }
    
    /*
     OpenGL ES (-1,1)
     四顶点数据定义了我们绘制像素缓冲区的二维平面区域。
     使用（-1，-1）和（1,1）分别作为左下角和右上角坐标形成的顶点数据覆盖整个屏幕。
     */
    GLfloat quadVertexData [] = {
        -1 * normalizedSamplingSize.width, -1 * normalizedSamplingSize.height,
        normalizedSamplingSize.width, -1 * normalizedSamplingSize.height,
        -1 * normalizedSamplingSize.width, normalizedSamplingSize.height,
        normalizedSamplingSize.width, normalizedSamplingSize.height,
    };
    
    // 坐标值->vsh
    // 更新属性值. 坐标数据
    glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, 0, 0, quadVertexData);
    glEnableVertexAttribArray(ATTRIB_VERTEX);
    
    // 纹理坐标
    /*
     纹理顶点的设置使我们垂直翻转纹理。这使得我们的左上角原点缓冲区匹配OpenGL的左下角纹理坐标系
     */
    CGRect textureSamplingRect = CGRectMake(0, 0, 1, 1);
    GLfloat quadTextureData[] =  {
        CGRectGetMinX(textureSamplingRect), CGRectGetMaxY(textureSamplingRect),
        CGRectGetMaxX(textureSamplingRect), CGRectGetMaxY(textureSamplingRect),
        CGRectGetMinX(textureSamplingRect), CGRectGetMinY(textureSamplingRect),
        CGRectGetMaxX(textureSamplingRect), CGRectGetMinY(textureSamplingRect)
    };
    // 更新纹理坐标属性值
    glVertexAttribPointer(ATTRIB_TEXCOORD, 2, GL_FLOAT, 0, 0, quadTextureData);
    glEnableVertexAttribArray(ATTRIB_TEXCOORD);
    
    // 绘制图形
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    // 绑定渲染缓存区->显示到屏幕
    glBindRenderbuffer(GL_RENDERBUFFER, _colorBufferHandle);
    [_context presentRenderbuffer:GL_RENDERBUFFER];
    
    // 到此，已完成显示动作
    
    // 清理纹理,方便下一帧纹理显示
    [self cleanUpTextures];
    // 定期纹理缓存刷新每帧
    CVOpenGLESTextureCacheFlush(_videoTextureCache, 0);
    
    if(_videoTextureCache) {
        CFRelease(_videoTextureCache);
    }
}

#pragma mark - OpenGL setup
// OpenGL 相关设置
- (void)setupGL {
    if (!_context || ![EAGLContext setCurrentContext:_context]) {
        return;
    }
    // 1 设置缓冲区
    [self setupBuffers];
    // 2 加载着色器
    [self loadShaders];
    //  3 使用program
    glUseProgram(self.program);
    
    // 设置相关参数
    // 0 and 1 are the texture IDs of _lumaTexture and _chromaTexture respectively.
    glUniform1i(uniforms[UNIFORM_Y], 0);
    glUniform1i(uniforms[UNIFORM_UV], 1);
    glUniform1f(uniforms[UNIFORM_ROTATION_ANGLE], 0);  // 旋转角度
    // 需要转换的颜色矩阵
    glUniformMatrix3fv(uniforms[UNIFORM_COLOR_CONVERSION_MATRIX], 1, GL_FALSE, _preferredConversion);
}

#pragma mark - Utilities
- (void)setupBuffers {
    // 取消深度测试
    glDisable(GL_DEPTH_TEST);
    // 打开ATTRIB_VERTEX 属性 position
    glEnableVertexAttribArray(ATTRIB_VERTEX);
    // 顶点数据解析方式
    /*
     参数1: 指定从索引0开始取数据，与顶点着色器对应
     参数2: 顶点属性大小
     参数3: 数据类型
     参数4: 归一化
     参数5: 步长（Stride)
     参数6: 数据在缓冲区起始位置的偏移量
     */
    glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(GLfloat), 0);
    
    // ATTRIB_TEXCOORD == texCoord
    glEnableVertexAttribArray(ATTRIB_TEXCOORD);
    glVertexAttribPointer(ATTRIB_TEXCOORD, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(GLfloat), 0);
    
    // 创建buffer
    [self createBuffers];
}

/// 创建buffer
- (void)createBuffers {
    // 创建帧缓存区 frameBuffer
    glGenFramebuffers(1, &_frameBufferHandle);
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBufferHandle);
    
    // 创建color缓存区 RenderBuffer
    glGenRenderbuffers(1, &_colorBufferHandle);
    glBindRenderbuffer(GL_RENDERBUFFER, _colorBufferHandle);
    
    // 绑定渲染缓存区
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:self];
    
    // 设置渲染缓存区的尺寸:_backingWidth/_backingHeight
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);
    
    // 绑定renderBuffer到FrameBuffer
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _colorBufferHandle);
    
    // 检查FrameBuffer状态
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"Failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
    }
}

/// 释放帧缓存区与渲染缓存区
- (void)releaseBuffers {
    if(_frameBufferHandle) {
        glDeleteFramebuffers(1, &_frameBufferHandle);
        _frameBufferHandle = 0;
    }
    if(_colorBufferHandle) {
        glDeleteRenderbuffers(1, &_colorBufferHandle);
        _colorBufferHandle = 0;
    }
}

/// 重新设置帧缓存区与渲染缓存区
- (void)resetRenderBuffer {
    if (!_context || ![EAGLContext setCurrentContext:_context]) {
        return;
    }
    [self releaseBuffers];
    [self createBuffers];
}

/// 清理纹理(Y纹理,UV纹理)
- (void)cleanUpTextures {
    if (_lumaTexture) {
        CFRelease(_lumaTexture);
        _lumaTexture = NULL;
    }
    if (_chromaTexture) {
        CFRelease(_chromaTexture);
        _chromaTexture = NULL;
    }
}

#pragma mark - Shaders Func
/// 加载着色器
- (BOOL)loadShaders {
    GLuint vertShader = 0, fragShader = 0;
    // 创建着色program.
    self.program = glCreateProgram();
    // 编译顶点着色器
    if(![self compileShaderString:&vertShader type:GL_VERTEX_SHADER shaderString:shader_vsh]) {
        NSLog(@"Failed to compile vertex shader");
        return NO;
    }
    // 编译片元着色器
    if(![self compileShaderString:&fragShader type:GL_FRAGMENT_SHADER shaderString:shader_fsh]) {
        NSLog(@"Failed to compile fragment shader");
        return NO;
    }
    // 附着顶点着色器到program.
    glAttachShader(self.program, vertShader);
    // 附着片元着色器到program.
    glAttachShader(self.program, fragShader);
    // 绑定属性位置。这需要在链接之前完成.(让ATTRIB_VERTEX/ATTRIB_TEXCOORD 与position/texCoord产生连接)
    glBindAttribLocation(self.program, ATTRIB_VERTEX, "position");
    glBindAttribLocation(self.program, ATTRIB_TEXCOORD, "texCoord");
    // Link the program.
    if (![self linkProgram:self.program]) {
        NSLog(@"Failed to link program: %d", self.program);
        if (vertShader) {
            glDeleteShader(vertShader);
            vertShader = 0;
        }
        if (fragShader) {
            glDeleteShader(fragShader);
            fragShader = 0;
        }
        if (self.program) {
            glDeleteProgram(self.program);
            self.program = 0;
        }
        return NO;
    }
    // 获取uniform的位置
    // Y亮度纹理
    uniforms[UNIFORM_Y] = glGetUniformLocation(self.program, "SamplerY");
    // UV色量纹理
    uniforms[UNIFORM_UV] = glGetUniformLocation(self.program, "SamplerUV");
    // 旋转角度preferredRotation
    uniforms[UNIFORM_ROTATION_ANGLE] = glGetUniformLocation(self.program, "preferredRotation");
    // YUV->RGB
    uniforms[UNIFORM_COLOR_CONVERSION_MATRIX] = glGetUniformLocation(self.program, "colorConversionMatrix");
    // Release vertex and fragment shaders.
    if (vertShader) {
        glDetachShader(self.program, vertShader);
        glDeleteShader(vertShader);
    }
    if (fragShader) {
        glDetachShader(self.program, fragShader);
        glDeleteShader(fragShader);
    }
    return YES;
}

/// 编译shader
- (BOOL)compileShaderString:(GLuint *)shader type:(GLenum)type shaderString:(const GLchar*)shaderString {
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &shaderString, NULL);
    glCompileShader(*shader);
    
#if defined(DEBUG)
    GLint logLength;
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(*shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    GLint status = 0;
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == 0) {
        glDeleteShader(*shader);
        return NO;
    }
    return YES;
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type URL:(NSURL *)URL {
    NSError *error;
    NSString *sourceString = [[NSString alloc] initWithContentsOfURL:URL encoding:NSUTF8StringEncoding error:&error];
    if (sourceString == nil) {
        NSLog(@"Failed to load vertex shader: %@", [error localizedDescription]);
        return NO;
    }
    const GLchar *source = (GLchar *)[sourceString UTF8String];
    return [self compileShaderString:shader type:type shaderString:source];
}

#pragma mark - Program Func
- (BOOL)linkProgram:(GLuint)prog {
    GLint status;
    glLinkProgram(prog);
    
#if defined(DEBUG)
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program link log:\n%s", log);
        free(log);
    }
#endif
    
    glGetProgramiv(prog, GL_LINK_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    return YES;
}

- (BOOL)validateProgram:(GLuint)prog {
    GLint logLength, status;
    glValidateProgram(prog);
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program validate log:\n%s", log);
        free(log);
    }
    
    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    return YES;
}



@end
