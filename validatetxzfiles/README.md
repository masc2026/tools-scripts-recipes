## Einfacher Integritätscheck für TXZ Files

Ein macOS CLI-Tool zur schnellen _stichprobenweisen_ Validierung von `.txz`-Archivdateien.

### Logik

Dateinamen Format: `[HMAC-SHA256].txz`

Der Dateiname (ohne Erweiterung) muss dem 64-Zeichen langen HMAC-SHA256-Hash des Datei-Inhalts entsprechen.

Das Tool liest den 64-Zeichen-Hash (Erwarteter-HMAC) aus dem Dateinamen und vergleicht diesen mit dem berechneten HMAC aus dem Datei-Inhalt.

Es wird eine einfache Logik (Sampling von HmacHeadTailSize-Blöcken) und ein fest kodierter Schlüssel (`HmacKey`) verwendet.

### Setup

#### `Command Line Developer Tools`

Die "Command Line Developer Tools" unter macOS installieren.

```bash
xcode-select --install
```

#### Tool compilieren

```bash
clang -fobjc-arc -framework Foundation -framework Security main.m FileValidator.m -o ValidateTaxaDBShareFiles
```

### Syntax

**Aufruf:**

(`Command Line Developer Tools` müssen installiert sein)

Der Dateipfad wird als Argument übergeben:

```bash
./ValidateTaxaDBShareFiles <TXZ Dateipfad>
```

**Return Codes:**

0: Validierung erfolgreich (ok).

1: Allgemeiner Fehler (z.B. Datei nicht gefunden, falsche Argumente).

2: Validierung fehlgeschlagen (nok).

**Beispiel:**

```bash
./ValidateTaxaDBShareFiles ../data/baf4c32a3cdd4e386679ba2fd387b5ce35dae670e33fbf7112cb48a425d0b379.txz
```

```bash
ok
```






