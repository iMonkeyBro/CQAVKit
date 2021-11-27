//
//  NSFileManager+CQ.h
//  CQAVKit
//
//  Created by 刘超群 on 2021/11/24.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSFileManager (CQ)

/**
 创建一个临时目录
 @param templateString 模板字符串
 */
- (NSString *)temporaryDirectoryWithTemplateString:(NSString *)templateString;

@end

NS_ASSUME_NONNULL_END
