#!/bin/zsh

zmodload zsh/zutil

# --- Konfiguration ---
# Pfad zur globalen Datenbank (ggf. absoluten Pfad anpassen!)
AUSGABE_DATEI="/Users/fama/Projekte/github/tools-scripts-recipes/movietags/filme_inventory.json"

EXTENSIONS="(mp4|m4v|mov|mkv|avi)"

# Filter
# EXCLUDE_STR="(Trailer)" 
# INCLUDE_STR="(Tatort)" 

# Standardwerte
DRY_RUN="false"
FORCE="false"

# Argumente prüfen
if [[ "${@}" =~ "--dry-run" ]]; then
    DRY_RUN="true"
    echo "--- DRY RUN MODUS ---"
fi

if [[ "${@}" =~ "--force" ]]; then
    FORCE="true"
    echo "--- FORCE MODUS ---"
fi

# Optionen
setopt extendedglob
setopt nullglob

# Dependencies Check
DEPENDENCIES=(jq ffprobe)
for cmd in "${DEPENDENCIES[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "FEHLER: '$cmd' fehlt."
        exit 1
    fi
done

# Hilfsfunktion für ffprobe
get_tag() {
    local file="$1"
    local tag="$2"
    ffprobe -v error -show_entries format_tags="$tag" -of default=noprint_wrappers=1:nokey=1 "$file"
}

# --- SCHRITT 1: Globale Datenbank laden ---
# Dateinamen (Basename) als Key
typeset -A db_entries
integer next_nr=1

if [[ -f "$AUSGABE_DATEI" ]]; then
    echo "Lade globale Datenbank: $AUSGABE_DATEI"
    
    # 1. Höchste NR ermitteln
    local max_found=$(jq '[.[] .nr] | max // 0' "$AUSGABE_DATEI")
    next_nr=$((max_found + 1))
    
    # 2. In Array laden (Key = filebasename, Value = ganzer JSON String)
    # Zeilenweise lesen: BASENAME [TAB] JSON
    while IFS=$'\t' read -r key json_line; do
        db_entries[$key]=$json_line
    done < <(jq -r '.[] | "\(.filebasename)\t\(.|tostring)"' "$AUSGABE_DATEI")
    
    echo "  -> ${#db_entries} Einträge geladen. Nächste ID: $next_nr"
else
    echo "Keine Datenbank gefunden. Starte neu."
fi

# --- SCHRITT 2: Dateien suchen ---
files=()

# FALL A: Input kommt aus einer Pipe (z.B. ls ... | script)
if [[ ! -t 0 ]]; then
    echo "Modus: Pipe Input (lese von stdin)..."
    while IFS= read -r line; do
        # Leere Zeilen ignorieren und Datei zum Array hinzufügen
        [[ -n "$line" ]] && files+=("$line")
    done

# FALL B: Keine Pipe -> Suche im aktuellen Verzeichnis (Globbing)
else
    echo "Modus: Lokales Verzeichnis (Globbing)..."

    if [[ -n "$EXCLUDE_STR" && -n "$INCLUDE_STR" ]]; then
        files=( *$~INCLUDE_STR*.(#i)$~EXTENSIONS~*$~EXCLUDE_STR* )
        echo "  Filter: Nur '*$INCLUDE_STR*', ohne '*$EXCLUDE_STR*'"
    elif [[ -n "$EXCLUDE_STR" ]]; then
        files=( *.(#i)$~EXTENSIONS~*$~EXCLUDE_STR* )
        echo "  Filter: Ignoriere '*$EXCLUDE_STR*'"
    elif [[ -n "$INCLUDE_STR" ]]; then
        files=( *$~INCLUDE_STR*.(#i)$~EXTENSIONS )
        echo "  Filter: Nur '*$INCLUDE_STR*'"
    else
        files=( *.(#i)$~EXTENSIONS )
        echo "  Filter: Keine (Alle Extensions)"
    fi
fi

ANZ=${#files}
if (( ANZ == 0 )); then echo "Keine Dateien im aktuellen Ordner gefunden."; exit 0; fi

echo "Verarbeite $ANZ lokale Dateien..."
echo "---------------------------------------------------"

# --- SCHRITT 3: Verarbeitung ---

updates_made="false"

for file in "${files[@]}"; do
    # Absoluter Pfad der Datei
    abs_path="${file:A}"
    # Dateiname (Key für die DB)
    basename="${file:t:r}" # t = tail (nur Dateiname inkl Endung)

    is_known="false"
    current_nr=0
    
    if [[ -n "${db_entries[$basename]}" ]]; then
        is_known="true"
        # Alte ID aus dem gespeicherten JSON extrahieren
        current_nr=$(echo "${db_entries[$basename]}" | jq -r '.nr')
    fi

    # ENTSCHEIDUNG: Skip, Update oder Neu?
    
    if [[ "$is_known" == "true" && "$FORCE" == "false" ]]; then
        # SKIP (schon da, kein Force)
        # echo "[SKIP] $basename"
        continue
    fi

    # Daten auslesen (nur nötig wenn Neu oder Force)
    m_title=$(get_tag "$file" "title")
    m_artist=$(get_tag "$file" "artist")
    m_show=$(get_tag "$file" "show")
    m_season=$(get_tag "$file" "season_number")
    m_episode=$(get_tag "$file" "episode_sort")

    # Fallback Titel
    if [[ -z "$m_title" ]]; then m_title="${file:r}"; fi
    
    if [[ "$is_known" == "true" ]]; then
        # UPDATE (Force ist an)
        action="[UPDATE]"
        # ID bleibt current_nr
    else
        # NEU
        action="[NEU]"
        current_nr=$next_nr
        ((next_nr++))
    fi
    
    # Visuelles Feedback
    echo "$action $basename"
    echo "    -> Title: $m_title | Artist: $m_artist"

    if [[ "$DRY_RUN" == "true" ]]; then
        continue
    fi

    # JSON Objekt bauen
    # Direkt in die globale Map und den alten Wert überschreiben
    # Damit ist die DB im Speicher aktualisiert
    
    json_obj=$(jq -n -c \
       --argjson nr "$current_nr" \
       --arg datei "$abs_path" \
       --arg base "$basename" \
       --arg artist "${m_artist}" \
       --arg show "${m_show}" \
       --arg title "${m_title}" \
       --arg season_number "${m_season_number}" \
       --arg episode "${m_episode}" \
       --arg episodes "${m_episodes}" \
       '{
          nr: $nr,
          datei: $datei,
          filebasename: $base,
          artist: $artist,
          show: $show,
          regisseur: { vorname: "", nachname: "", geboren: "" },
          titel: { de: $title, orig: "" },
          season_number: $season_number,
          episode: $episode,
          episodes: $episodes
       }')

    db_entries[$basename]=$json_obj
    updates_made="true"
done

echo "---------------------------------------------------"

# --- SCHRITT 4: Speichern ---

if [[ "$DRY_RUN" == "true" ]]; then
    echo "DRY RUN BEENDET. Keine Änderungen gespeichert."
    exit 0
fi

if [[ "$updates_made" == "false" ]]; then
    echo "Keine Änderungen nötig. Datenbank ist aktuell."
    exit 0
fi

# Das gesamte Array (Map) zurück in die Datei schreiben
TEMP_JSON="${AUSGABE_DATEI}.tmp"

# Trick: Alle Values des Arrays ausgeben und Pipe in jq -s
# "${db_entries[@]}" expandiert zu allen JSON-Strings
printf "%s\n" "${db_entries[@]}" | jq -s 'sort_by(.nr)' > "$TEMP_JSON"

if [[ -s "$TEMP_JSON" ]]; then
    mv "$TEMP_JSON" "$AUSGABE_DATEI"
    echo "Globale Datenbank gespeichert ($AUSGABE_DATEI)."
    echo "Gesamteinträge: ${#db_entries}"
else
    echo "FEHLER: Temp-Datei leer. Abbruch."
    rm -f "$TEMP_JSON"
fi