#!/bin/zsh

# --- Konfiguration ---
SOURCE_ROOT="/run/media/user/EOS_DIGITAL/DCIM/100CANON"
DEST_ROOT="/mnt/transfer/LightroomSSD2/LightroomHD16"
RAW_EXTENSIONS=("CR3" "CR2" "DNG")

# Dry-Run Modus: 'true' für Test, 'false' für tatsächliches Kopieren.
DRY_RUN="false"
# -----------------------------------

# Setze den rsync Befehl basierend auf dem Dry-Run Modus
RSYNC_OPTS="-av"
local ACTION
local DRY_RUN_DISPLAY

if [[ "$DRY_RUN" = "true" ]]; then
    RSYNC_OPTS+="n" # 'n' für Dry-Run
    ACTION="Dry-Run: Würde kopieren"
    DRY_RUN_DISPLAY="*** DRY RUN (Es werden keine Dateien kopiert) ***"
else
    ACTION="Kopiere"
    DRY_RUN_DISPLAY="*** ECHTER LAUF (Dateien werden kopiert) ***"
fi

# --- Überprüfungen ---
if ! command -v exiftool &> /dev/null; then
    echo "Fehler: 'exiftool' ist nicht installiert. Bitte installieren Sie es."
    exit 1
fi
if ! command -v rsync &> /dev/null; then
    echo "Fehler: 'rsync' ist nicht installiert. Bitte installieren Sie es."
    exit 1
fi
if [[ ! -d "$SOURCE_ROOT" ]]; then
    echo "Fehler: Quellverzeichnis '$SOURCE_ROOT' existiert nicht oder ist nicht eingehängt."
    exit 1
fi
if [[ ! -d "$DEST_ROOT" ]]; then
    echo "Fehler: Zielstammverzeichnis '$DEST_ROOT' existiert nicht."
    exit 1
fi

# --- Hauptlogik ---
echo "Starte RAW-Import-Skript..."
echo "Quelle: $SOURCE_ROOT"
echo "Ziel-Stammverzeichnis: $DEST_ROOT"
echo "$DRY_RUN_DISPLAY"
echo "-----------------------------------"

# Aktiviert erweiterte Globbing-Muster wie **
setopt extendedglob

# Iteriere über alle regulären Dateien, die auf die Erweiterungen passen (case-insensitive)
# Die Magie passiert hier: ${(j:|:)RAW_EXTENSIONS} verbindet das Array mit '|'
# und (.) am Ende sorgt dafür, dass nur reguläre Dateien gefunden werden.
files=($(eval "print -r \"$SOURCE_ROOT\"/*.(#i)(${(j:|:)RAW_EXTENSIONS})(N)"))
for raw_file in "${files[@]}"; do
    
    # 1. Erfassungsdatum aus EXIF-Daten mit exiftool auslesen
    # local sorgt dafür, dass die Variable nur innerhalb der Schleife gültig ist.
    local DATE_ORIGINAL
    DATE_ORIGINAL=$(exiftool -d "%Y-%m-%d" -s3 -DateTimeOriginal -CreateDate -FileModifyDate "$raw_file" | head -n 1)

    if [[ -z "$DATE_ORIGINAL" ]]; then
        echo "WARNUNG: Konnte kein Datum für '$raw_file' auslesen. Überspringe Datei."
        continue
    fi

    # 2. Zielpfad auf Basis des Datums erstellen
    local YEAR=${DATE_ORIGINAL:0:4} # Zsh Substring von Position 0 mit Länge 4
    local DEST_DATE_DIR="$DEST_ROOT/$YEAR/$DATE_ORIGINAL"

    # 3. Zielverzeichnisse erstellen (nur im echten Lauf)
    if [[ "$DRY_RUN" = "false" ]]; then
        mkdir -p "$DEST_DATE_DIR"
    fi
    
    # 4. rsync Befehl
    # :t extrahiert den Dateinamen aus dem Pfad (tail)
    local FILE_NAME=${raw_file:t} 
    
    echo "$ACTION: $FILE_NAME -> $DEST_DATE_DIR/"
    
    # Führe rsync aus
    rsync $RSYNC_OPTS "$raw_file" "$DEST_DATE_DIR/"
done

echo "-----------------------------------"
echo "Vorgang abgeschlossen."
