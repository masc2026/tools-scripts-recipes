## Validierungs-Tool ValidateTaxaDBShareFiles

CLI-Tool zur schnellen _stichprobenweisen_ Validierung von `.txz`-Archivdateien.

### Validierungs-Logik

Prüfung einer Datei auf Integrität durch Abgleich des Dateinamens mit dem Datei-Inhalt.

Dateiformat: `[HMAC-SHA256].txz`

Der Dateiname (ohne Erweiterung) muss dem 64-Zeichen langen HMAC-SHA256-Hash des Datei-Inhalts entsprechen.

### Validierungs-Prozess:

Extrahieren: Das Tool liest den 64-Zeichen-Hash (Erwarteter-HMAC) aus dem Dateinamen.

Berechnen: Das Tool berechnet einen neuen HMAC (Berechneter-HMAC) aus dem Datei-Inhalt.

**Wichtig**: Die Berechnung nutzt eine einfache Logik (Sampling von HmacHeadTailSize-Blöcken) und einen fest kodierten Schlüssel (`HmacKey`).

Vergleichen: Das Tool vergleicht Erwarteter-HMAC mit Berechneter-HMAC.

### Ergebnis:

Match: Die Datei ist valide. Rückgabe: ok.

Mismatch: Die Datei ist korrupt oder manipuliert. Rückgabe: nok.

### Kompilieren:

Kompilierung der validatehmac.m Datei mit clang:

```bash
cd ValidateTaxaDBShareFiles
clang -fobjc-arc -framework Foundation -framework Security main.m FileValidator.m -o ValidateTaxaDBShareFiles
```

### Verwendung:

Ausführung des Tools mit dem Dateipfad als Argument (es werden die `Command Line Developer Tools` gebraucht):

```bash
./ValidateTaxaDBShareFiles ../data/baf4c32a3cdd4e386679ba2fd387b5ce35dae670e33fbf7112cb48a425d0b379.txz
ok
```


#### Rückgabewerte (Exit Codes):

Das Tool liefert Exit Codes für Skripting:

0: Validierung erfolgreich (ok).

1: Allgemeiner Fehler (z.B. Datei nicht gefunden, falsche Argumente).

2: Validierung fehlgeschlagen (nok).

### Voraussetzungen:

So installierst du sie (falls noch nicht geschehen):

Öffne das Terminal.

Gib diesen Befehl ein:

```bash
xcode-select --install
````

Dann die "Command Line Developer Tools" installieren.
