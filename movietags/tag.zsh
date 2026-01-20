#!/bin/zsh

# --- Konfiguration ---
# Pfad zur globalen Datenbank (ggf. Pfad anpassen!)
INVENTAR_DATEI="~/Projekte/github/tools-scripts-recipes/movietags/filme_inventory.json"
INVENTAR_DATEI=${~INVENTAR_DATEI}
EXTENSIONS="(mp4|m4v|mov|mpeg)"

# Standardwerte
DRY_RUN="false"
FORCE="false"
USE_DB_ONLY="false"

# Argumente prüfen
if [[ "${@}" =~ "--dry-run" ]]; then
    DRY_RUN="true"
    echo "--- DRY RUN MODUS ---"
fi

if [[ "${@}" =~ "--force" ]]; then
    FORCE="true"
    echo "--- FORCE MODUS AKTIV ---"
fi

if [[ "${@}" =~ "--db-only" ]]; then
    USE_DB_ONLY="true"
    echo "--- DB-ONLY MODUS: Lese Metadaten aus JSON (ignoriere Dateinamen) ---"
fi

setopt extendedglob
setopt nullglob

# Dependencies Check
DEPENDENCIES=(ffprobe AtomicParsley ffmpeg jq) 

for cmd in "${DEPENDENCIES[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "FEHLER: Der Befehl '$cmd' wurde nicht gefunden."
        exit 1
    fi
done

# --- SCHRITT 0: Inventar laden ---
typeset -A db_entries
db_loaded="false"

if [[ -f "$INVENTAR_DATEI" ]]; then
    echo "Lade Inventar: $INVENTAR_DATEI"
    # Wir laden basename -> ganzes JSON Objekt in ein Array
    while IFS=$'\t' read -r key json_line; do
        db_entries[$key]=$json_line
    done < <(jq -r '.[] | "\(.filebasename)\t\(.|tostring)"' "$INVENTAR_DATEI")
    db_loaded="true"
else
    echo "Warnung: Inventar-Datei nicht gefunden."
    if [[ "$USE_DB_ONLY" == "true" ]]; then
        echo "Fehler: --db-only erfordert eine Inventar-Datei."
        exit 1
    fi
fi

# Hilfsfunktion: Wert aus geladener DB holen
get_tag_inventory() {
    local file_basename="$1"
    local field="$2" 
    
    if [[ "$db_loaded" == "false" ]]; then return; fi
    local entry="${db_entries[$file_basename]}"
    
    if [[ -n "$entry" ]]; then
        # Wert mit jq aus dem String parsen
        echo "$entry" | jq -r "$field // empty"
    fi
}

# Hilfsfunktion: Description aus DB bauen (Regie + Darsteller)
build_description() {
    local file_basename="$1"
    
    if [[ "$db_loaded" == "false" ]]; then return; fi
    local entry="${db_entries[$file_basename]}"
    
    if [[ -n "$entry" ]]; then
        # Text mit jq String Interpolation bauen
        echo "$entry" | jq -r '
            ("Regie:\n" + (.regisseur.name // "-") + "\n\n"),
            "Darsteller:",
            (.darsteller[] | "\(.actor) als \(.rolle)")
        ' | paste -sd '\n' - # paste verbindet die Zeilen wieder sauber
        # Hinweis: jq gibt bei Array-Iteration jede Zeile einzeln aus, paste fügt sie zusammen
    fi
}

# Hilfsfunktion für ffprobe
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

# Dateien suchen
files=()

# FALL A: Input kommt aus einer Pipe
if [[ ! -t 0 ]]; then
    echo "Modus: Pipe Input..."
    while IFS= read -r line; do
        [[ -n "$line" ]] && files+=("$line")
    done

# FALL B: Lokales Verzeichnis
else
    echo "Modus: Lokales Verzeichnis..."
    if [[ -n "$EXCLUDE_STR" && -n "$INCLUDE_STR" ]]; then
        files=( *$~INCLUDE_STR*.(#i)$~EXTENSIONS~*$~EXCLUDE_STR* )
    elif [[ -n "$EXCLUDE_STR" ]]; then
        files=( *.(#i)$~EXTENSIONS~*$~EXCLUDE_STR* )
    elif [[ -n "$INCLUDE_STR" ]]; then
        files=( *$~INCLUDE_STR*.(#i)$~EXTENSIONS )
    else
        files=( *.(#i)$~EXTENSIONS )
    fi
fi

if (( ${#files} == 0 )); then echo "Keine Dateien gefunden."; exit 0; fi

echo "Prüfe ${#files} Dateien..."
echo "---------------------------------------------------"

for file in "${files[@]}"; do
    basename="${file:t:r}" # Ohne Pfad, ohne Endung
    filename="${file:t}"   # Ohne Pfad, mit Endung (Key für DB!)
    extension="${file:e}"

    # Variablen resetten
    new_artist="" new_show="" new_title="" new_season="" new_episode="" new_total=""
    new_year="" new_desc=""
    match_found="false"

    # --- DATENQUELLE WÄHLEN ---

    if [[ "$USE_DB_ONLY" == "true" ]]; then
        # 1. MODUS: NUR DB LESEN
        pattern_name="Database Lookup"
        
        # Prüfen ob Eintrag existiert
        if [[ -z "${db_entries[$filename]}" ]]; then
            [[ "$DRY_RUN" == "true" ]] && echo "[SKIP] '$filename' nicht in DB gefunden."
            continue
        fi
        
        match_found="true"
        new_title=$(get_tag_inventory "$filename" ".titel.de")
        new_artist=$(get_tag_inventory "$filename" ".artist")
        new_show=$(get_tag_inventory "$filename" ".show")
        new_year=$(get_tag_inventory "$filename" ".jahr")
        # Description generieren
        new_desc=$(build_description "$filename")
        
        # Episoden Infos (falls vorhanden)
        new_episode=$(get_tag_inventory "$filename" ".episode")
        # new_season/total müssten im JSON stehen, falls wir sie wollen. 
        # Hier nehmen wir an, dass sie ggf. leer bleiben wenn nicht in DB.

    else
        # 2. MODUS: DATEINAMEN ANALYSE (Regex)
        
        # 1. Artist - Show . Title_S_E_Total
        if [[ "$basename" =~ "^([^_.-]+) - ([^_.-]+) \. ([^_.-]+)_([0-9]+)_([0-9]+)_([0-9]+)$" ]]; then
            new_artist="${match[1]}"; new_show="${match[2]}"; new_title="${match[3]}"
            new_season="${match[4]}"; new_episode="${match[5]}"; new_total="${match[6]}"
            match_found="true"; pattern_name="Artist - Show . Title_S_E_Total"

        # 2. Artist - Title_S_E_Total
        elif [[ "$basename" =~ "^([^_.-]+) - ([^_.-]+)_([0-9]+)_([0-9]+)_([0-9]+)$" ]]; then
            new_artist="${match[1]}"; new_title="${match[2]}"; new_show="${new_title}"
            new_season="${match[3]}"; new_episode="${match[4]}"; new_total="${match[5]}"
            match_found="true"; pattern_name="Artist - Title_S_E_Total"

        # 3. Title_S_E_Total
        elif [[ "$basename" =~ "^([^_.-]+)_([0-9]+)_([0-9]+)_([0-9]+)$" ]]; then
            new_title="${match[1]}"; new_show="${new_title}"
            new_season="${match[2]}"; new_episode="${match[3]}"; new_total="${match[4]}"
            match_found="true"; pattern_name="Title_S_E_Total"
        
        # 7. Artist - Show . Title
        elif [[ "$basename" =~ "^([^_.-]+) - ([^_.-]+) \. ([^_.-]+)$" ]]; then
            new_artist="${match[1]}"; new_show="${match[2]}"; new_title="${match[3]}"
            match_found="true"; pattern_name="Artist - Show . Title"

        # 4. Show . Title
        elif [[ "$basename" =~ "^([^_.-]+) \. ([^_.-]+)$" ]]; then
            new_show="${match[1]}"; new_title="${match[2]}"
            match_found="true"; pattern_name="Show . Title"

        # 7. Show . Title_S_E_Total
        elif [[ "$basename" =~ "^([^_.-]+) \. ([^_.-]+)_([0-9]+)_([0-9]+)_([0-9]+)$" ]]; then
            new_show="${match[1]}"; new_title="${match[2]}"
            new_season="${match[3]}"; new_episode="${match[4]}"; new_total="${match[5]}"
            match_found="true"; pattern_name="Show . Title_S_E_Total"

        # 5. Artist - Title
        elif [[ "$basename" =~ "^([^_.-]+) - ([^_.-]+)$" ]]; then
            new_artist="${match[1]}"; new_title="${match[2]}"
            match_found="true"; pattern_name="Artist - Title"

        # 6. Title
        elif [[ "$basename" =~ "^([^_.-]+)$" ]]; then
            new_title="${match[1]}"
            match_found="true"; pattern_name="Title Only"
        fi
        
        # Im normalen Modus holen wir das Jahr TROTZDEM aus der DB (als Zusatz)
        new_year=$(get_tag_inventory "$filename" ".jahr")
    fi

    if [[ "$match_found" == "false" ]]; then
        [[ "$DRY_RUN" == "true" ]] && echo "[SKIP] Kein Muster passt: $file"
        continue
    fi
    
    # --- BESTEHENDE DATEN PRÜFEN ---
    ex_artist=$(get_tag "$file" "artist")
    ex_show=$(get_tag "$file" "show")
    ex_title=$(get_tag "$file" "title")
    ex_season=$(get_tag "$file" "season_number")
    ex_episode=$(get_tag "$file" "episode_sort")
    ex_year=$(get_tag "$file" "date"); ex_year="${ex_year:0:4}"
    ex_desc=$(get_tag "$file" "description") # Wir lesen auch die alte Description
   
    ap_args=()
    update_info=""

    # --- ARGUMENTE BAUEN ---

    # Artist
    if [[ ( -z "$ex_artist" || "$FORCE" == "true" ) && -n "$new_artist" ]]; then
        ap_args+=( --artist "$new_artist" )
        update_info+="Artist "
    fi

    # Show
    if [[ ( -z "$ex_show" || "$FORCE" == "true" ) && -n "$new_show" ]]; then
        ap_args+=( --TVShowName "$new_show" )
        update_info+="Show "
    fi

    # Title
    if [[ ( -z "$ex_title" || "$FORCE" == "true" ) && -n "$new_title" ]]; then
        ap_args+=( --title "$new_title" )
        update_info+="Title "
    fi
    
    # Jahr
    if [[ ( -z "$ex_year" || "$FORCE" == "true" ) && -n "$new_year" ]]; then
        ap_args+=( --year "$new_year" )
        update_info+="Jahr "
    fi
    
    # Description (Nur im DB-Modus oder wenn explizit gewünscht)
    # Hier prüfen wir: Ist neue Desc da? Und (Alt leer oder Force)
    if [[ ( -z "$ex_desc" || "$FORCE" == "true" ) && -n "$new_desc" ]]; then
        ap_args+=( --description "$new_desc" )
        update_info+="Desc "
    fi

    # Season & Episode
    write_season="false"
    
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
            # Falls wir KEINE DB-Description haben, bauen wir eine einfache:
            if [[ -z "$new_desc" ]]; then
                 ap_args+=( --description "Staffel $new_season, Episode $new_episode von $new_total" )
            fi
        else
            ap_args+=( --tracknum "$new_episode" )
        fi
    fi

    # --- ENTSCHEIDUNG ---

    if (( ${#ap_args} == 0 )); then
        continue
    fi

    echo "Datei: $file"
    echo "  -> Muster: $pattern_name"

    force_txt=""
    [[ "$FORCE" == "true" ]] && force_txt="(FORCE)"
    
    echo "  -> Update: $update_info $force_txt"
    echo "---------------------------------------------------"
    printf "DATEI:  %s\n" "$basename"
    printf "  %-10s | %-30s | %s\n" "TAG" "ALT" "NEU"
    echo "  -----------------------------------------------------------------------"
    printf "  %-10s | %-30s | %s\n" "Artist"  "${ex_artist:--}"  "${new_artist}"
    printf "  %-10s | %-30s | %s\n" "Show"    "${ex_show:--}"    "${new_show}"
    printf "  %-10s | %-30s | %s\n" "Titel"   "${ex_title:--}"   "${new_title}"
    printf "  %-10s | %-30s | %s\n" "Jahr"    "${ex_year:--}"    "${new_year}"
    printf "  %-10s | %-30s | %s\n" "Desc"    "${${ex_desc//$'\n'/ }:0:20}..."  "${${new_desc//$'\n'/ }:0:20}..."
    printf "  %-10s | %-30s | %s\n" "Staffel" "${ex_season:--}"  "${new_season}"
    printf "  %-10s | %-30s | %s\n" "Episode" "${ex_episode:--}" "${new_episode}"
    echo ""

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  [DRY-RUN] Würde AtomicParsley starten."
        continue
    fi

    # --- AUSFÜHRUNG ---

    output=$(AtomicParsley "$file" "${ap_args[@]}" --overWrite 2>&1)
    exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        echo "     [OK] Aktualisiert."
    else
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
                if [[ "${file}" != "${file:r}.m4v" ]]; then rm "$file"; fi
                echo "     [OK] Datei repariert zu .m4v. Bitte Skript erneut laufen lassen!"
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