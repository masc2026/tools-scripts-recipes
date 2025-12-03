#!/bin/zsh

# --- Konfiguration ---
EXTENSIONS="(mp4|m4v|mov|mpeg)"
# Filter (optional)
# Beispiel: 'Hitchcock' ohne 'Vorhang'
# EXCLUDE_STR="(Vorhang)" 
# INCLUDE_STR="(Hitchcock)" 
# Beispiel: 'Tatort' und 'Tod'
#INCLUDE_STR="(Tatort*Hüter|Hüter*Tatort)"
#INCLUDE_STR="(Tatort)" 

# Dry Run Check
DRY_RUN="false"
if [[ "${@}" =~ "--dry-run" ]]; then
    DRY_RUN="true"
    echo "--- DRY RUN MODUS ---"
fi

setopt extendedglob
setopt nullglob

# Dependencies Check
if ! command -v convert &> /dev/null; then echo "Fehler: ImageMagick (convert) fehlt."; exit 1; fi
if ! command -v AtomicParsley &> /dev/null; then echo "Fehler: AtomicParsley fehlt."; exit 1; fi
if ! command -v ffprobe &> /dev/null; then echo "Fehler: ffprobe fehlt."; exit 1; fi

# Hilfsfunktion
get_tag() {
    ffprobe -v error -show_entries format_tags="$2" -of default=noprint_wrappers=1:nokey=1 "$1"
}

# Dateien suchen
# Fall 1: Exclude UND Include sind gesetzt
# Logik: (Muss Include enthalten) UND (Darf Exclude NICHT enthalten)
if [[ -n "$EXCLUDE_STR" && -n "$INCLUDE_STR" ]]; then
    files=( *$~INCLUDE_STR*.(#i)$~EXTENSIONS~*$~EXCLUDE_STR* )
    echo "Filter aktiv: Nur '*$INCLUDE_STR*', aber ohne '*$EXCLUDE_STR*'"

# Fall 2: Nur Exclude ist gesetzt
# Logik: (Alles) UND (Darf Exclude NICHT enthalten)
elif [[ -n "$EXCLUDE_STR" ]]; then
    files=( *.(#i)$~EXTENSIONS~*$~EXCLUDE_STR* )
    echo "Filter aktiv: Ignoriere '*$EXCLUDE_STR*'"

# Fall 3: Nur Include ist gesetzt
# Logik: (Muss Include enthalten)
elif [[ -n "$INCLUDE_STR" ]]; then
    files=( *$~INCLUDE_STR*.(#i)$~EXTENSIONS )
    echo "Filter aktiv: Nur '*$INCLUDE_STR*'"

# Fall 4: Keines ist gesetzt
else
    files=( *.(#i)$~EXTENSIONS )
    echo "Kein Filter aktiv'"

fi

if (( ${#files} == 0 )); then echo "Keine Dateien gefunden."; exit 0; fi

echo "Prüfe ${#files} Dateien auf fehlende Cover..."
echo "---------------------------------------------------"

for file in "${files[@]}"; do
    basename="${file:r:t}"

    # 1. Prüfen: Hat die Datei schon ein Cover?
    # Wir leiten stderr um, um Warnungen zu unterdrücken
    has_cover=$(AtomicParsley "$file" -T 1 2>/dev/null | grep "covr")
    
    if [[ -n "$has_cover" ]]; then
        # continue
    fi

    # 2. Metadaten lesen
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

    if [[ -z "$artist" ]]; then echo "artist unset"; else echo "artist set"; fi
    
    echo "Generiere Cover für: $basename"
    echo "  -> Text: $title ($artist)"

    if [[ "$DRY_RUN" == "true" ]]; then continue; fi

    # 3. Temporärer Dateinamen für Artwork Bild

    safe_name="${basename//[^a-zA-Z0-9]/_}"
    cover_file="/tmp/cover_${safe_name}.png"

    # 4. Bild mit ImageMagick erstellen (mit automatischem Umbruch!)

    WIDTH=540
    HEIGHT=720
    TEXT_WIDTH=$((WIDTH - 90))

    if [[ -z "$artist" ]]; then
        magick -size ${WIDTH}x${HEIGHT} xc:grey66 \
            -colorspace sRGB -interlace Plane \
            -density 72 -units PixelsPerInch \
            -gravity center \
            \( -background none -fill "white" -font "System-Font-Semibold" -pointsize 55 \
                -size ${TEXT_WIDTH}x caption:"$title" \) \
            -geometry +0-200 -composite \
            "$cover_file"

    else
        magick -size ${WIDTH}x${HEIGHT} xc:grey66 \
            -colorspace sRGB -interlace Plane \
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

    # 5. Bild schreiben mit AtomicParsley

    AtomicParsley "$file" --artwork REMOVE_ALL --artwork "$cover_file" --overWrite > /dev/null
    
    if [[ $? -eq 0 ]]; then
        echo "     [OK] Cover eingebettet."
    else
        echo "     [ERROR] Fehler beim Einbetten."
    fi

    # Aufräumen
    rm -f "$cover_file"
done

echo "\nFertig."