#!/bin/zsh

zmodload zsh/zutil

# --- Konfiguration ---
BASE_PFAD="/Volumes/HD16/iTunes Media"
SEARCH_DIRS="(Movies|Home Videos)"
AUSGABE_DATEI="filme_inventory.json"
MIN_MB=50
EXT_MUSTER="mp4|m4v|mkv|mov|avi"

# Optionen
setopt extendedglob
setopt nullglob

# --- Check Dependencies ---
if ! command -v jq &> /dev/null; then echo "Fehler: 'jq' fehlt."; exit 1; fi

echo "Suche in: $SUCH_PFAD"

# --- SCHRITT 1: Bestehende Daten laden ---
typeset -A existing_entries
integer next_nr=1

if [[ -f "$AUSGABE_DATEI" ]]; then
    echo "Lese existierende Datei '$AUSGABE_DATEI'..."
    
    # 1. Höchste NR ermitteln
    local max_found=$(jq '[.[] .nr] | max // 0' "$AUSGABE_DATEI")
    next_nr=$((max_found + 1))
    echo "Fortsetzung bei Nummer: $next_nr"

    # 2. Index erstellen
    while IFS=$'\t' read -r fpath json_content; do
        existing_entries[$fpath]=$json_content
    done < <(jq -r '.[] | "\(.datei)\t\(.|tostring)"' "$AUSGABE_DATEI")
fi

# --- SCHRITT 2: Dateien suchen ---
# Zsh Globbing bleibt gleich - das ist perfekt so
files=( "$BASE_PFAD"/$~SEARCH_DIRS/**/*.(#i)($~EXT_MUSTER)(.Lm+${MIN_MB}oa:A) )

ANZ=${#files}
if (( ANZ == 0 )); then echo "Keine Dateien gefunden."; exit 0; fi

echo "Verarbeite $ANZ gefundene Dateien..."

# --- SCHRITT 3: Abgleich und Generierung ---
TEMP_JSON="${AUSGABE_DATEI}.tmp"

{
    integer i=1
    for file in "${files[@]}"; do
        print -n "\rChecke $i / $ANZ" >&2
        ((i++))

        # CHECK: Kennen wir die Datei schon?
        if [[ -n "${existing_entries[$file]}" ]]; then
            # JA: Alten Eintrag behalten
            echo "${existing_entries[$file]}"
        else
            # NEIN: Neuen Eintrag mit jq bauen
            # Wir übergeben Shell-Variablen sicher mit --arg (String) und --argjson (Zahl)
            
            jq -n -c \
               --argjson nr "$next_nr" \
               --arg datei "$file" \
               --arg base "${file:r:t}" \
               '{
                  nr: $nr,
                  datei: $datei,
                  filebasename: $base,
                  regisseur: { vorname: "", nachname: "", geboren: "" },
                  titel: { de: "", orig: "" }
               }'
            
            ((next_nr++))
        fi
    done
} | jq -s '.' > "$TEMP_JSON" 

echo "" 

# --- Abschluss ---
if [[ -s "$TEMP_JSON" ]]; then
    mv "$TEMP_JSON" "$AUSGABE_DATEI"
    echo "Fertig! Datenbank aktualisiert: $AUSGABE_DATEI"
else
    echo "Fehler: Temp-Datei war leer. Abbruch."
    rm -f "$TEMP_JSON"
fi