//
//  FileValidator.m
//  ValidateTaxaDBShareFiles
//
//  Created by Markus Schmid / Gemini 2.5 Pro on 10.11.25.
//

#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonHMAC.h>
#import <sys/mman.h>
#import <sys/stat.h>
#import <fcntl.h>
#import <unistd.h>
#include "FileValidator.h"

#define HmacHeadTailSize 30
#define NumberOfHmacs 10
#define HmacKey @"geheimins"

@implementation FileValidator

+ (BOOL)validateFile:(NSString *)filePath {
    @try {
        NSString *fileNameWithExt = [filePath lastPathComponent];
        
        // 1. Regex-Logik aus deiner scanFilesToShare Methode
        NSError *error = nil;
        NSRegularExpression *regexTXZ = [NSRegularExpression regularExpressionWithPattern:@"^([a-f0-9]{64,64})\\.(txz)" options:0 error:&error];
        
        if (error) {
            fprintf(stderr, "Regex-Fehler: %s\n", [[error localizedDescription] UTF8String]);
            return NO;
        }

        NSRange range = NSMakeRange(0, fileNameWithExt.length);
        NSTextCheckingResult *match = [regexTXZ firstMatchInString:fileNameWithExt options:0 range:range];
        
        // 2. Prüfen, ob der Dateiname überhaupt dem Muster entspricht
        if (!match || [match numberOfRanges] < 2) {
            fprintf(stderr, "Fehler: Dateiname '%s' passt nicht zum erwarteten Muster (64-Zeichen-Hash + .txz)\n", [fileNameWithExt UTF8String]);
            return NO;
        }
        
        // 3. Erwarteten HMAC aus dem Dateinamen extrahieren
        NSString *expectedHmac = [fileNameWithExt substringWithRange:[match rangeAtIndex:1]];
        
        // 4. Tatsächlichen HMAC aus dem Datei-Inhalt berechnen
        NSString *actualHmac = [FileValidator calculateHmacForFile:filePath];
        
        // 5. Vergleichen
        if ([actualHmac isEqualToString:expectedHmac]) {
            return YES;
        } else {
            fprintf(stderr, "Validierung fehlgeschlagen.\n");
            fprintf(stderr, "  Erwartet (aus Dateiname): %s\n", [expectedHmac UTF8String]);
            fprintf(stderr, "  Berechnet (aus Inhalt):   %s\n", [actualHmac UTF8String]);
            return NO;
        }
    } @catch (NSException *exception) {
        fprintf(stderr, "Kritische Ausnahme: %s - %s\n", [[exception name] UTF8String], [[exception reason] UTF8String]);
        return NO;
    }
}

+ (NSString *)calculateHmacForFile:(NSString *)filePath {
    NSMutableData *headTail = [[NSMutableData alloc] init];
    
    int fd = open([filePath cStringUsingEncoding:NSUTF8StringEncoding], O_RDONLY);
    
    if (fd < 0) {
        fprintf(stderr, "Fehler: Konnte Datei nicht öffnen: %s\n", [filePath UTF8String]);
        return @"";
    }
    
    struct stat info;
    int status = fstat(fd, &info);
    if (status < 0) {
        fprintf(stderr, "Fehler: fstat fehlgeschlagen.\n");
        close(fd);
        return @"";
    }
    
    unsigned long size = (unsigned long)info.st_size;
    
    if (size == 0) {
        close(fd);
        return [FileValidator hmac:headTail withKey:HmacKey];
    }

    NSInteger hmacHeadTailSize = MIN(HmacHeadTailSize, size);

    char *mapped = (char *)mmap(0, size, PROT_READ, MAP_FILE | MAP_SHARED, fd, 0);
    if (mapped == MAP_FAILED) {
        fprintf(stderr, "Fehler: mmap fehlgeschlagen.\n");
        close(fd);
        return @"";
    }
    
    NSInteger parts = MIN(size / hmacHeadTailSize, NumberOfHmacs);
    if (parts == 0) {
        parts = 1;
    }
    
    NSInteger partSize = size / parts;
    

    for (NSInteger pos = 0, posNr = 1; pos < (size - hmacHeadTailSize); pos = (posNr * partSize), posNr++) {
        [headTail appendBytes:&mapped[pos] length:hmacHeadTailSize];
    }
    
    munmap(mapped, size);
    close(fd);
    
    return [FileValidator hmac:headTail withKey:HmacKey];
}

+ (NSString *)hmac:(NSData *)data withKey:(NSString *)key {
    const char *cKey = [key cStringUsingEncoding:NSASCIIStringEncoding];
    const char *cData = data.bytes;
    
    unsigned char cHMAC[CC_SHA256_DIGEST_LENGTH];
    
    CCHmac(kCCHmacAlgSHA256, cKey, strlen(cKey), cData, data.length, cHMAC);
    
    NSData *HMACData = [[NSData alloc] initWithBytes:cHMAC length:CC_SHA256_DIGEST_LENGTH];
    
    const unsigned char *buffer = (const unsigned char *)HMACData.bytes;

    NSMutableString *HMAC = [NSMutableString stringWithCapacity:HMACData.length * 2];
    
    for (int i = 0; i < HMACData.length; ++i) {
        [HMAC appendFormat:@"%02lx", (unsigned long)buffer[i]];
    }
    
    return [NSString stringWithString:HMAC];
}

@end
