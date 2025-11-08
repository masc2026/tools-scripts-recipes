# Archivieren von RAW Bilddateien von SD

Zsh-Skript für Import und Abgleich von RAW-Bilddateien (z.B. von einer SD-Karte) in eine datumsbasierte Verzeichnisstruktur (z.B. für Lightroom).

## Was macht das Skript?

Automatisiert den Kopiervorgang von RAW-Fotos von einem Quellmedium (z.B. einer SD-Karte) in ein Archivverzeichnis. 

Beispiel:

**Quelle:**

```bash
tree '/run/media/user/EOS_DIGITAL/DCIM/100CANON'
/run/media/user/EOS_DIGITAL/DCIM/100CANON
├── ER6A3226.CR2
├── ER6A3227.CR2
...
└── IMG_3239.CR3
```

**Ziel:**

```bash
tree '/mnt/transfer/LightroomSSD2/LightroomHD16/'
/mnt/transfer/LightroomSSD2/LightroomHD16/
├── 2024
│   └── 2024-11-24
│       ├── IMG_1219.CR2
│       ├── IMG_1220.CR2
...
    │   ├── ER6A9094.dng
...
    │   └── ER6A9112.dng.xmp
...
│       └── IMG_1238.CR2.xmp
└── 2025
    ├── 2025-01-01
    │   ├── ER6A9078.dng
...
    │   ├── ER6A9079.dng
...
```

**Ablauf im Detail:**

1.  **Scannen:** Durchsucht `SOURCE_ROOT` nach RAW-Dateien (Typen in `RAW_EXTENSIONS` definiert: `CR3`, `CR2`, `DNG` etc.).
2.  **EXIF-Datum lesen:** Liest Aufnahmedatum (`DateTimeOriginal`) von jeder Datei mit `exiftool` aus.
3.  **Zielstruktur erstellen:** Erstellt einen Zielpfad basierend auf dem Schema `DEST_ROOT/JAHR/JAHR-MONAT-TAG`.
4.  **Kopieren:** Kopiert die RAW-Datei mit `rsync` in den Zieldatumsordner.
5.  **Dry-Run Modus:** Bei `DRY_RUN="true"` Testlauf.

## Verwendung

1.  **Konfiguration in `import.zsh` anpassen:**

      * `SOURCE_ROOT`: Einhängepunkt für SD-Karte.
      * `DEST_ROOT`: Stammverzeichnis für Lightroom-Archiv.
      * `RAW_EXTENSIONS` :  Evt. die Datentypen anpasen.
      * `DRY_RUN`: `"true"` (Testlauf) oder `"false"` (echtes Kopieren).

2.  **Skript ausführbar machen:**

    ```bash
    chmod +x import.zsh
    ```

3.  **Skript ausführen:**

    ```bash
    ./import.zsh
    ```

## Anforderungen

**Benötigte Programme:**

  * **zsh**: Shell zur Ausführung.
  * **rsync**: Für den Kopiervorgang.
  * **exiftool**: Zum Auslesen von Metadaten (Aufnahmedatum).

### Installation (Beispiel für Arch Linux)

Pakete mit `pacman` installieren:

```bash
sudo pacman -S rsync perl-image-exiftool
```