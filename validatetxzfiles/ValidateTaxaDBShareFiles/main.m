//
//  main.m
//  ValidateTaxaDBShareFiles
//
//  Created by Markus Schmid / Gemini 2.5 Pro on 10.11.25.
//

#import <Foundation/Foundation.h>
#include "FileValidator.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
        // 1. Argumente prüfen
        if (argc != 2) {
            fprintf(stderr, "Falsche Verwendung.\n");
            fprintf(stderr, "Aufruf: %s /Pfad/zur/datei.txz\n", argv[0]);
            return 1; // 1 = Allgemeiner Fehler
        }
        
        // 2. Dateipfad aus Argumenten holen
        NSString *filePath = [NSString stringWithUTF8String:argv[1]];
        
        // 3. Prüfen, ob die Datei existiert
        if (![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
            fprintf(stderr, "Fehler: Datei nicht gefunden: %s\n", [filePath UTF8String]);
            return 1;
        }

        // 4. Validierung durchführen
        BOOL isValid = [FileValidator validateFile:filePath];
        
        // 5. Ergebnis ausgeben (ok/nok)
        if (isValid) {
            printf("ok\n");
            return 0; // 0 = Erfolg
        } else {
            printf("nok\n");
            return 2; // 2 = Validierung fehlgeschlagen
        }
        
    }
    return 0;
}
