//
//  FileValidator.h
//  ValidateTaxaDBShareFiles
//
//  Created by Markus Schmid / Gemini 2.5 Pro on 10.11.25.
//

@interface FileValidator : NSObject

+ (BOOL)validateFile:(NSString *)filePath;

+ (NSString *)calculateHmacForFile:(NSString *)filePath;

+ (NSString *)hmac:(NSData *)data withKey:(NSString *)key;

@end