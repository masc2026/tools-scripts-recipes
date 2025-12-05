#!/bin/zsh

# --- Konfiguration ---
EXTENSIONS="(mp4|m4v|mov|mpeg)"
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
DEPENDENCIES=(ffprobe AtomicParsley ffmpeg)

for cmd in "${DEPENDENCIES[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "FEHLER: Der Befehl '$cmd' wurde nicht gefunden."
        echo "Bitte installieren (z.B. mit 'brew install $cmd')."
        exit 1
    fi
done

# Hilfsfunktion für ffprobe
get_tag() {
    local file="$1"
    local tag="$2"

    if [[ "$tag" == "cover" ]]; then
        # Spezialfall: Prüft auf Videostreams, die als Cover markiert sind (attached_pic)
        # Gibt "1" zurück, wenn ein Cover gefunden wurde, sonst nichts.
        ffprobe -v error -select_streams v \
            -show_entries stream=disposition:attached_pic \
            -of default=noprint_wrappers=1:nokey=1 "$file" | grep -m 1 "1"
    else
        # Standardfall: Liest normale Text-Tags (Artist, Title, etc.)
        ffprobe -v error -show_entries format_tags="$tag" \
            -of default=noprint_wrappers=1:nokey=1 "$file"
    fi
}

# Dateien suchen (deine Logik)
if [[ -n "$EXCLUDE_STR" && -n "$INCLUDE_STR" ]]; then
    files=( *$~INCLUDE_STR*.(#i)$~EXTENSIONS~*$~EXCLUDE_STR* )
    echo "Filter aktiv: Nur '*$INCLUDE_STR*', aber ohne '*$EXCLUDE_STR*'"
elif [[ -n "$EXCLUDE_STR" ]]; then
    files=( *.(#i)$~EXTENSIONS~*$~EXCLUDE_STR* )
    echo "Filter aktiv: Ignoriere '*$EXCLUDE_STR*'"
elif [[ -n "$INCLUDE_STR" ]]; then
    files=( *$~INCLUDE_STR*.(#i)$~EXTENSIONS )
    echo "Filter aktiv: Nur '*$INCLUDE_STR*'"
else
    files=( *.(#i)$~EXTENSIONS )
    echo "Kein Filter aktiv"
fi

if (( ${#files} == 0 )); then echo "Keine Dateien gefunden."; exit 0; fi

echo "Prüfe ${#files} Dateien..."
echo "---------------------------------------------------"

for file in "${files[@]}"; do
    basename="${file:r}"
    extension="${file:e}"
    
    # Variablen resetten
    new_artist="" new_show="" new_title="" new_season="" new_episode="" new_total=""
    match_found="false"

    # --- MUSTER ERKENNUNG im File Namen (Strict: [^_.-]+) ---

    # 1. Artist - Show . Title_S_E_Total
    if [[ "$basename" =~ "^([^_.-]+) - ([^_.-]+) \. ([^_.-]+)_([0-9]+)_([0-9]+)_([0-9]+)$" ]]; then
        new_artist="${match[1]}"; new_show="${match[2]}"; new_title="${match[3]}"
        new_season="${match[4]}"; new_episode="${match[5]}"; new_total="${match[6]}"
        match_found="true"; pattern_name="Artist - Show . Title_S_E_Total"

    # 2. Artist - Title_S_E_Total (Show=Title Fallback)
    elif [[ "$basename" =~ "^([^_.-]+) - ([^_.-]+)_([0-9]+)_([0-9]+)_([0-9]+)$" ]]; then
        new_artist="${match[1]}"; new_title="${match[2]}"; new_show="${new_title}"
        new_season="${match[3]}"; new_episode="${match[4]}"; new_total="${match[5]}"
        match_found="true"; pattern_name="Artist - Title_S_E_Total"

    # 3. Title_S_E_Total (Show=Title Fallback)
    elif [[ "$basename" =~ "^([^_.-]+)_([0-9]+)_([0-9]+)_([0-9]+)$" ]]; then
        new_title="${match[1]}"; new_show="${new_title}"
        new_season="${match[2]}"; new_episode="${match[3]}"; new_total="${match[4]}"
        match_found="true"; pattern_name="Title_S_E_Total"
    
    # 7. Artist - Show . Title (NEU eingefügt, da spezifischer als 5)
    elif [[ "$basename" =~ "^([^_.-]+) - ([^_.-]+) \. ([^_.-]+)$" ]]; then
        new_artist="${match[1]}"; new_show="${match[2]}"; new_title="${match[3]}"
        match_found="true"; pattern_name="Artist - Show . Title"

    # 4. Show . Title
    elif [[ "$basename" =~ "^([^_.-]+) \. ([^_.-]+)$" ]]; then
        new_show="${match[1]}"; new_title="${match[2]}"
        match_found="true"; pattern_name="Show . Title"

    # 5. Artist - Title
    elif [[ "$basename" =~ "^([^_.-]+) - ([^_.-]+)$" ]]; then
        new_artist="${match[1]}"; new_title="${match[2]}"
        match_found="true"; pattern_name="Artist - Title"

    # 6. Title (Gefährlich allgemein, daher ganz unten)
    elif [[ "$basename" =~ "^([^_.-]+)$" ]]; then
        new_title="${match[1]}"
        match_found="true"; pattern_name="Title Only"
    fi

    if [[ "$match_found" == "false" ]]; then
        [[ "$DRY_RUN" == "true" ]] && echo "[SKIP] Kein Muster passt: $file"
        continue
    fi
   
    has_cover=$(AtomicParsley "$file" -T 1 2>/dev/null | grep "covr")
    ex_artist=$(get_tag "$file" "artist")
    ex_show=$(get_tag "$file" "show")
    ex_title=$(get_tag "$file" "title")
    ex_season=$(get_tag "$file" "season_number")
    ex_episode=$(get_tag "$file" "episode_sort")
   
    ap_args=()
    update_info=""

    # Artist
    # Logik: Wenn (Feld leer ODER Force an) UND (Neuer Wert da)
    if [[ ( -z "$ex_artist" || "$FORCE" == "true" ) && -n "$new_artist" ]]; then
        ap_args+=( --artist "$new_artist" )
        update_info+="Artist "
    fi

    # Show (TVShowName)
    if [[ ( -z "$ex_show" || "$FORCE" == "true" ) && -n "$new_show" ]]; then
        ap_args+=( --TVShowName "$new_show" )
        update_info+="Show "
    fi

    # Title
    if [[ ( -z "$ex_title" || "$FORCE" == "true" ) && -n "$new_title" ]]; then
        ap_args+=( --title "$new_title" )
        update_info+="Title "
    fi

    # Season & Episode
    write_season="false"
    
    # Hier prüfen wir auch auf Force
    if [[ ( -z "$ex_season" || "$FORCE" == "true" ) && -n "$new_season" ]]; then
        ap_args+=( --TVSeasonNum "$new_season" )
        write_season="true"; update_info+="Season "
    fi
    
    if [[ ( -z "$ex_episode" || "$FORCE" == "true" ) && -n "$new_episode" ]]; then
        ap_args+=( --TVEpisodeNum "$new_episode" )
        write_season="true"; update_info+="Episode "
    fi

    # Zusatzinfos für Serien
    if [[ "$write_season" == "true" ]]; then
        ap_args+=( --stik value=10 )
        
        if [[ -n "$new_total" ]]; then
            ap_args+=( --tracknum "$new_episode/$new_total" )
            ap_args+=( --description "Staffel $new_season, Episode $new_episode von $new_total" )
        else
            ap_args+=( --tracknum "$new_episode" )
        fi
    fi

    if (( ${#ap_args} == 0 )); then
        if [[ "$FORCE" == "true" ]]; then
             [[ "$DRY_RUN" == "true" ]] && echo "[SKIP] Trotz Force: Keine Daten aus Dateinamen extrahierbar."
             continue
        else
             continue
        fi
    fi

    echo "Datei: $file"
    echo "  -> Muster: $pattern_name"

    if [[ "$FORCE" == "true" ]]; then
        echo "  -> Update: $update_info (FORCE: Überschreibe)"
        echo "---------------------------------------------------"
        printf "DATEI:  %s\n" "$basename"
        printf "MUSTER: %s\n\n" "$pattern_name"
        printf "  %-10s | %-30s | %s\n" "TAG" "ALT" "NEU"
        echo "  -----------------------------------------------------------------------"
        printf "  %-10s | %-30s | %s\n" "Artist"  "${ex_artist:--}"  "${new_artist}"
        printf "  %-10s | %-30s | %s\n" "Show"    "${ex_show:--}"    "${new_show}"
        printf "  %-10s | %-30s | %s\n" "Titel"   "${ex_title:--}"   "${new_title}"
        printf "  %-10s | %-30s | %s\n" "Staffel" "${ex_season:--}"  "${new_season}"
        printf "  %-10s | %-30s | %s\n" "Episode" "${ex_episode:--}" "${new_episode}"
        echo ""
    else
        echo "  -> Update: $update_info"
        echo "---------------------------------------------------"
        printf "DATEI:  %s\n" "$basename"
        printf "MUSTER: %s\n\n" "$pattern_name"
        printf "  %-10s | %-30s | %s\n" "TAG" "ALT" "NEU"
        echo "  -----------------------------------------------------------------------"
        printf "  %-10s | %-30s | %s\n" "Artist"  "${ex_artist:--}"  "${new_artist}"
        printf "  %-10s | %-30s | %s\n" "Show"    "${ex_show:--}"    "${new_show}"
        printf "  %-10s | %-30s | %s\n" "Titel"   "${ex_title:--}"   "${new_title}"
        printf "  %-10s | %-30s | %s\n" "Staffel" "${ex_season:--}"  "${new_season}"
        printf "  %-10s | %-30s | %s\n" "Episode" "${ex_episode:--}" "${new_episode}"
        echo ""
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  [DRY-RUN] Würde AtomicParsley starten."
        continue
    fi

    # --- AUSFÜHRUNG ---

    # 1. AtomicParsley ausführen und Output auffangen
    output=$(AtomicParsley "$file" "${ap_args[@]}" --overWrite 2>&1)
    exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        echo "     [OK] Aktualisiert."
    else
        # Fehleranalyse: Ist es ein falsches Format oder zu wenig Platz?
        # Wir suchen nach den typischen Fehlermeldungen
        if echo "$output" | grep -q -E "bad mpeg4 file|insufficient space"; then
            echo "     [WARNUNG] AtomicParsley gescheitert (Kein MP4-Container oder zu wenig Platz)."
            echo "     -> Starte FFmpeg Reparatur (Remux nach .m4v)..."

            temp_fixed="${file:r}_fixed.m4v"
           
            # FFmpeg Remux
            ffmpeg -hide_banner -loglevel error \
                -i "$file" \
                -map 0 \
                -c copy \
                -dn \
                -f mp4 -movflags +faststart \
                "$temp_fixed"
            
            if [[ $? -eq 0 ]]; then
                mv "$temp_fixed" "${file:r}.m4v"
                
                # Wenn die Endung vorher anders war (z.B. .mpeg), Original löschen
                if [[ "${file}" != "${file:r}.m4v" ]]; then
                    rm "$file"
                fi
                echo "     [OK] Datei repariert zu .m4v. Bitte Skript erneut laufen lassen für Tags!"
            else
                echo "     [ERROR] Auch FFmpeg Reparatur gescheitert."
                rm -f "$temp_fixed"
            fi
        else
            echo "     [ERROR] Unbekannter AtomicParsley Fehler:"
            echo "$output"
        fi
    fi

done

echo "\nFertig."