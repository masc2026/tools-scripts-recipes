#!/bin/zsh

# --- Konfiguration ---
EXTENSIONS="(mp4|m4v|mov)"
# Filter Beispiele:
# EXCLUDE_STR="(Lynch)" 
# INCLUDE_STR="(Polat)" 
# INCLUDE_STR="(Tatort*Reini|Reini*Tatort)"

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
    echo "--- FORCE MODUS AKTIV ---"
fi

setopt extendedglob
setopt nullglob

# Dependencies Check
# Liste der benötigten Programme
DEPENDENCIES=(ffmpeg ffprobe AtomicParsley magick)

for cmd in "${DEPENDENCIES[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "FEHLER: Der Befehl '$cmd' wurde nicht gefunden."
        echo "Bitte installieren (z.B. mit 'brew install $cmd')."
        exit 1
    fi
done

# Hilfsfunktion für ffprobe (liefert leeren String zurück, wenn Tag fehlt)
get_tag() {
    local file="$1"
    local tag="$2"

    if [[ "$tag" == "cover" ]]; then
        ffprobe -v error -select_streams v \
            -show_entries stream_disposition=attached_pic \
            -of default=noprint_wrappers=1:nokey=1 "$file" | grep -m 1 "1"
    else
        ffprobe -v error -show_entries format_tags="$tag" \
            -of default=noprint_wrappers=1:nokey=1 "$file"
    fi
}

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

if (( ${#files} == 0 )); then echo "Keine Dateien gefunden."; exit 0; fi

echo "Prüfe ${#files} Dateien auf fehlende Cover..."
echo "---------------------------------------------------"

for file in "${files[@]}"; do
    basename="${file:t:r}"
    extension="${file:e}"

    # 1. Metadaten lesen bzw, Cover check
    has_cover=$(get_tag "$file" "cover")
    title=$(get_tag "$file" "title")
    show=$(get_tag "$file" "show")
    season_number=$(get_tag "$file" "season_number")
    episode_sort=$(get_tag "$file" "episode_sort")
    artist=$(get_tag "$file" "artist")

    echo "---------------------------------------------------"
    # %-15s bedeutet: String mit 15 Zeichen Breite, linksbündig
    # Die ${VAR:-...} Syntax zeigt "-" an, falls die Variable leer ist.

    printf "DATEI:          %s\n" "$basename"
    printf "  %-14s %s\n" "Cover vorh.:" "${${has_cover:+ja}:-nein}"
    printf "  %-14s %s\n" "Titel:"       "${title:--}"
    printf "  %-14s %s\n" "Show:"        "${show:--}"
    printf "  %-14s %s\n" "Staffel:"     "${season_number:--}"
    printf "  %-14s %s\n" "Episode:"     "${episode_sort:--}"
    printf "  %-14s %s\n" "Artist:"      "${artist:--}"
    echo ""

#   if [[ -z "$show" ]]; then
#       [[ "$DRY_RUN" == "true" ]] && echo "[SKIP] '$basename' ist keine TV-Show."
#       continue
#   fi

#   if [[ -n "$show" ]]; then
#       [[ "$DRY_RUN" == "true" ]] && echo "[SKIP] '$basename' ist eine TV-Show (ignoriere)."
#       continue
#   fi

    # Fallback
    if [[ -z "$title" ]]; then title="$basename"; fi

    [[ -z "${artist// }" ]] && unset artist

    # --- ENTSCHEIDUNG ---

    if [[ -n "$has_cover" ]] && [[ "$FORCE" == "false" ]]; then
        [[ "$DRY_RUN" == "true" ]] && echo "[SKIP] Cover bereits vorhanden: $basename"
        continue
    fi

    echo "Datei: $file"
    
    if [[ -n "$has_cover" && "$FORCE" == "true" ]]; then
         echo "  [FORCE] Überschreibe existierendes Cover."
    fi

    echo "Generiere Cover für: $basename"
    echo "  -> Text: $title ${artist:+($artist)}"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  [DRY-RUN] Würde ImageMagick und AtomicParsley starten."
        continue
    fi

    # 2. Temporärer Dateinamen für Artwork Bild

    safe_name="${basename//[^a-zA-Z0-9]/_}"
    cover_file="/tmp/cover_${safe_name}.png"

    # 3. Bild mit ImageMagick erstellen (mit automatischem Umbruch!)

    WIDTH=540
    HEIGHT=720
    TEXT_WIDTH=$((WIDTH - 90))

    if [[ -z "$artist" ]]; then
        magick -size ${WIDTH}x${HEIGHT} xc:grey66 \
            -depth 8 \
            -colorspace sRGB \
            -density 72 -units PixelsPerInch \
            -gravity center \
            \( -background none -fill "white" -font "System-Font-Semibold" -pointsize 55 \
                -size ${TEXT_WIDTH}x caption:"$title" \) \
            -geometry +0-200 -composite \
            "$cover_file"

    else
        magick -size ${WIDTH}x${HEIGHT} xc:grey66 \
            -depth 8 \
            -colorspace sRGB \
            -density 72 -units PixelsPerInch \
            -gravity center \
            \( -background none -fill "white" -font "System-Font-Semibold" -pointsize 55 \
                -size ${TEXT_WIDTH}x caption:"$title" \) \
            -geometry +0-200 -composite \
            \( -background none -fill "brown" -font "System-Font-Medium" -pointsize 35 \
                -size ${TEXT_WIDTH}x caption:"$artist" \) \
            -geometry +0+230 -composite \
            "$cover_file"
    fi

    # 4. Bild schreiben mit AtomicParsley oder ffmpeg als fall BACK

    # Versuch 1: AtomicParsley
    # Fehler abfangen (2> /dev/null wegnehmen, um Fehler zu sehen, oder in Variable speichern)
    if AtomicParsley "$file" --artwork REMOVE_ALL --artwork "$cover_file" --overWrite >/dev/null 2>&1; then
        echo "     [OK] Cover eingebettet (AtomicParsley)."
    else
        # Versuch 2: FFmpeg Fallback
        echo "     [WARNUNG] AtomicParsley fehlgeschlagen (zu wenig Header-Platz oder .mov Container)."
        echo "     -> Starte FFmpeg Fallback (Reparatur & Umwandlung in .m4v)..."
        
        # WICHTIG: ändern der Endung auf .m4v!
        # Das löst alle Container-Probleme mit Apple TV und AtomicParsley.
        temp_ffmpeg="${file:r}_fixed.m4v"
        
        ffmpeg -hide_banner -loglevel error \
            -i "$file" -i "$cover_file" \
            -map "0:v" -map "0:a" -map "0:s?" \
            -map 1 \
            -c copy \
            -dn \
            -f mp4 \
            -movflags +faststart \
            -disposition:v:1 attached_pic \
            "$temp_ffmpeg"
            
        if [[ $? -eq 0 ]]; then
            # Wenn erfolgreich: Alte Datei löschen und neue behalten
            mv "$temp_ffmpeg" "${file:r}.m4v"
            
            # Falls die Originaldatei NICHT .m4v hieß (z.B. .mov), das Original löschen
            if [[ "${file}" != "${file:r}.m4v" ]]; then
                rm "$file"
                echo "     [INFO] Datei wurde von .${file:e} zu .m4v konvertiert."
            fi
            
            echo "     [OK] Cover eingebettet & Container repariert."
        else
            echo "     [ERROR] Auch FFmpeg ist gescheitert."
            rm -f "$temp_ffmpeg"
        fi
    fi
    
    # Aufräumen
    rm -f "$cover_file"
    
done

echo "\nFertig."