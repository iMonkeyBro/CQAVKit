//
//  CQVideoDecoder.m
//  CQAVKit
//
//  Created by 刘超群 on 2022/2/5.
//

#import "CQVideoDecoder.h"

@interface CQVideoDecoder ()

@end

@implementation CQVideoDecoder

/**
 思路
 1 解析数据(NALU Unit) 判断I/P/B帧
 2 初始化解码器
 3 将解析后的H264 NALU Unit 输入到解码器
 4 在解码完成的回调函数里，输出解码后的数据
 5 解码后数据的显示(OpenGL ES)
 
 核心函数:
 1 创建解码会话， VTDecompressionSessionCreate
 2 解码一个frame，VTDecompressionSessionDecodeFrame
 3 销毁解码会话  VTDecompressionSessionInvalidate
 
 H264原始码流 --> NALU
 I帧 保留了一张完整的视频帧，解码的关键
 */

@end
