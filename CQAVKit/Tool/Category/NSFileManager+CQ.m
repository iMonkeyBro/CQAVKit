//
//  NSFileManager+CQ.m
//  CQAVKit
//
//  Created by 刘超群 on 2021/11/24.
//

#import "NSFileManager+CQ.h"

@implementation NSFileManager (CQ)
// 临时目录与模板字符串
- (NSString *)temporaryDirectoryWithTemplateString:(NSString *)templateString {
    NSString *docPath = NSTemporaryDirectory();
    NSString *mkdTemplate = [docPath stringByAppendingPathComponent:templateString];
    const char *templateCString = [mkdTemplate fileSystemRepresentation];
    char *buffer = (char *)malloc(strlen(templateCString) + 1);
    strcpy(buffer, templateCString);
    NSString *directoryPath = nil;
    char *result = mkdtemp(buffer);
    if (result) {
        directoryPath = [self stringWithFileSystemRepresentation:buffer length:strlen(result)];
    }
    free(buffer);
    return directoryPath;
}

@end
