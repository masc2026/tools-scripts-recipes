#!/bin/zsh

# return : =1 in case of error else =0

zmodload zsh/zutil

# Globbing-Einstellungen
setopt EXTENDED_GLOB
setopt NULL_GLOB
unsetopt NOMATCH

typeset my_marker="🟤"

source "${0:A:h}/src/utils.zsh"

typeset  flag_test_run
typeset  flag_dry_run
typeset  flag_force
typeset  flag_fforce
typeset  flag_db_only
typeset  -a arg_infile

typeset  flag_help
typeset  flag_verbose

typeset usage=(
    "Verwendung: $0 [OPTIONEN]"
    ""
    "Optionen:"
    "  -h,  --help           Zeigt diese Hilfe an und beendet das Skript"
    "  -v,  --verbose        Log an"
    "  -fo, --force          Erzwingt das Überschreiben von Metadaten"
    "  -ff, --fforce         Erzwingt Löschen und Überschreiben von Metadaten"
    "  -do, --db-only        Liest Info für Metadaten aus der JSON Datenbank ansonsten werden Infos aus Datenamen verwendet"
    "  -tr, --test-run       Startet den Testmodus mit Test Film-Dateien und verwendet Testverzeichnisse"
    "  -dr, --dry-run        Simuliert den Durchlauf, ohne Dateien zu verändern"
    "  -in, --infile <arg>   Eingabe Film-Datei ansonsten stdin"
)

zparseopts -D -F -K -- \
    {h,-help}=flag_help \
    {v,-verbose}=flag_verbose \
    {fo,-force}=flag_force \
    {ff,-fforce}=flag_fforce \
    {co,-db-only}=flag_db_only \
    {tr,-test-run}=flag_test_run \
    {dr,-dry-run}=flag_dry_run \
    {in,-infile}:=arg_infile 2>/dev/null || {
        print -l >&2 "Fehler: Ungültige Argumente übergeben."
        print -l >&2 "${usage[@]}"
        return 1
    }

### Initialize

typeset test_run="false"
typeset dry_run="false"
typeset force="false"
typeset fforce="false"
typeset use_db_only="false"
typeset in_file=""

if [[ -n "${flag_help:-}" ]]; then
    print -l >&2 "${usage[@]}"
    return 0
fi

if [[ -n "${flag_verbose:-}" ]]; then
    NO_PRINT="false"
else
    NO_PRINT="true"
fi

if [[ -n "${flag_test_run:-}" ]]; then
    test_run="true"
fi

if [[ -n "${flag_dry_run:-}" ]]; then
    dry_run="true"
fi

if [[ -n "${flag_force:-}" ]]; then
    force="true"
fi

if [[ -n "${flag_fforce:-}" ]]; then
    fforce="true"
fi

if [[ -n "${flag_db_only:-}" ]]; then
    use_db_only="true"
fi

if (( $#arg_infile )); then
    in_file=${arg_infile[-1]}
fi

if [[ "$test_run" == "true" ]]; then
    if [[ ! -d "${TEST_MOVIES_DIR}" || ! -f "${TEST_INVENTORY_DB}" ]]; then
        print >&2 "${my_marker} Keine Testumgebung vorhanden."
        exit -1
    fi
    check_dependencies jq
    if [[ "$use_db_only" == "true" ]]; then
        init_inventory "${TEST_INVENTORY_DB}"
    fi 
else
    check_dependencies jq
    if [[ "$use_db_only" == "true" ]]; then
        init_inventory "${INVENTORY_DB}"
    fi
fi

util.print "Inventar Datei: $INVENTAR_DATEI"
util.print "Pfad: $TAG_DIR"
util.print "Zeitstempel: $TIMESTAMP"

### Run

# return : =1 falls ein Fehler auftrat, sonst =0
main() {
    local -i r_code=0

    if [[ "$test_run" == "false" ]]; then
        if [[ -n $in_file ]]; then
            util.print "File Source by Arg"
            print >&2 "${my_marker} File: $in_file"
            if ! tag.run "$in_file"; then
                util.print "Warnung: Bearbeitung von $in_file wurde abgebrochen."
                r_code=1
            fi
        elif [[ ! -t 0 ]]; then
            util.print "File Source by Stdin"
            while IFS= read -r file; do
                [[ -z "$file" ]] && continue
                print >&2 "${my_marker} File: $file"
                if ! tag.run "$file"; then
                    util.print "Warnung: Bearbeitung von $file wurde abgebrochen."
                    r_code=1
                fi
            done
        else
            util.print "No files"
        fi
    else
        util.print "File Source by Stdin (Test Mode)"
        while IFS= read -r file; do
            [[ -z "$file" ]] && continue
            print >&2 "${my_marker} File: $file"
            if ! tag.run "$file"; then
                util.print "Warnung: Bearbeitung von $file wurde abgebrochen."
                r_code=1
            fi
        done < <(print -l -- "${TEST_MOVIES_DIR}"/*.${~EXTENSIONS}(N))
    fi
    
    util.print "Fertig."

    return $r_code
}

### Functions

# return : >0 falls ein Fehler auftrat, sonst =0
# stdout : Absoluter Pfad der bearbeiteten Datei:
#          = Übergabepfad ($1) falls Datei unverändert
#          = Neu erstellte Datei bei Remux und Format Konvertierung 
tag.run() {
    local file="$1"
    local print_r_file="$1"
    local integer r_code=0

    basename="${file:t:r}" # Ohne Pfad, ohne Endung
    filename="${file:t}"   # Ohne Pfad, mit Endung (Key für DB!)
    extension="${file:e}"

    # Variablen resetten
    new_artist="" new_show="" new_title="" new_season="" new_episode="" new_total=""
    new_year="" new_desc=""
    match_found="false"

    util.print "Filmdatei: $file"

    () {
        if [[ "$use_db_only" == "true" ]]; then
            util.print "Infos aus der DB lesen"
        
            # Prüfen ob ein Eintrag existiert
            new_datei=$(get_tag_inventory "$filename" ".datei")

            if [[ -z "${new_datei}" ]]; then
                [[ "$dry_run" == "true" ]] && util.print "[SKIP] '$filename' nicht in DB gefunden."
                r_code=0
                return
            fi
            
            new_title=$(get_tag_inventory "$filename" ".titel.de")
            new_artist=$(get_tag_inventory "$filename" ".artist")
            new_show=$(get_tag_inventory "$filename" ".show")
            new_year=$(get_tag_inventory "$filename" ".jahr")
            new_desc=$(build_description "$filename")
            new_episode=$(get_tag_inventory "$filename" ".episode")
            new_season=$(get_tag_inventory "$filename" ".season")

            match_found="true"
        fi
        if [[ "$use_db_only" == "false" ]]; then
            util.print "Infos aus dem Datienamen extrahieren"

            # 1. Artist - Show . Title_S_E_Total(_YYYY)
            if [[ "$basename" =~ "^([^_.-]+) - ([^_.-]+) \. ([^_.-]+)_([0-9]+)_([0-9]+)_([0-9]+)(_([0-9]{4}))?$" ]]; then
                util.print "Muster: 1. Artist - Show . Title_S_E_Total(_YYYY)"
                new_artist="${match[1]}"; new_show="${match[2]}"; new_title="${match[3]}"
                new_season="${match[4]}"; new_episode="${match[5]}"; new_total="${match[6]}"
                new_year="${match[8]}"
                match_found="true"

            # 2. Artist - Show_S_E_Total(_YYYY)
            elif [[ "$basename" =~ "^([^_.-]+) - ([^_.-]+)_([0-9]+)_([0-9]+)_([0-9]+)(_([0-9]{4}))?$" ]]; then
                util.print "Muster: 2. Artist - Show_S_E_Total(_YYYY)"
                new_artist="${match[1]}"; new_show="${match[2]}"
                new_season="${match[3]}"; new_episode="${match[4]}"; new_total="${match[5]}"
                new_year="${match[7]}"
                match_found="true"

            # 3. Show_S_E_Total(_YYYY)
            elif [[ "$basename" =~ "^([^_.-]+)_([0-9]+)_([0-9]+)_([0-9]+)(_([0-9]{4}))?$" ]]; then
                util.print "Muster: 3. Show_S_E_Total(_YYYY)"
                new_show="${match[1]}";
                new_season="${match[2]}"; new_episode="${match[3]}"; new_total="${match[4]}"
                new_year="${match[6]}"
                match_found="true"
            
            # 4. Artist - Show . Title(_YYYY)
            elif [[ "$basename" =~ "^([^_.-]+) - ([^_.-]+) \. ([^_.-]+)(_([0-9]{4}))?$" ]]; then
                util.print "Muster: 4. Artist - Show . Title(_YYYY)"
                new_artist="${match[1]}"; new_show="${match[2]}"; new_title="${match[3]}"
                new_year="${match[5]}"
                match_found="true"

            # 5. Show . Title(_YYYY)
            elif [[ "$basename" =~ "^([^_.-]+) \. ([^_.-]+)(_([0-9]{4}))?$" ]]; then
                util.print "Muster: 5. Show . Title(_YYYY)"
                new_show="${match[1]}"; new_title="${match[2]}"
                new_year="${match[4]}"
                match_found="true"

            # 6. Show . Title_S_E_Total(_YYYY) (Duplikat-Index korrigiert)
            elif [[ "$basename" =~ "^([^_.-]+) \. ([^_.-]+)_([0-9]+)_([0-9]+)_([0-9]+)(_([0-9]{4}))?$" ]]; then
                util.print "Muster: 6. Show . Title_S_E_Total(_YYYY) (Duplikat-Index korrigiert)"
                new_show="${match[1]}"; new_title="${match[2]}"
                new_season="${match[3]}"; new_episode="${match[4]}"; new_total="${match[5]}"
                new_year="${match[7]}"
                match_found="true"

            # 7. Artist - Title(_YYYY)
            elif [[ "$basename" =~ "^([^_.-]+) - ([^_.-]+)(_([0-9]{4}))?$" ]]; then
                util.print "Muster: 7. Artist - Title(_YYYY)"
                new_artist="${match[1]}"; new_title="${match[2]}"
                new_year="${match[4]}"
                match_found="true"

            # 8. Title(_YYYY)
            elif [[ "$basename" =~ "^([^_.-]+)(_([0-9]{4}))?$" ]]; then
                util.print "Muster: 8. Title(_YYYY)"
                new_title="${match[1]}"
                new_year="${match[3]}"
                match_found="true"
            fi
        fi

        if [[ "$match_found" == "false" ]]; then
            [[ "$dry_run" == "true" ]] && util.print "[SKIP] Kein Muster passt: $file"
            r_code=0
            return
        fi
        
        ex_artist=$(get_tag "$file" "artist")
        ex_show=$(get_tag "$file" "show")
        ex_title=$(get_tag "$file" "title")
        ex_season=$(get_tag "$file" "season_number")
        ex_episode=$(get_tag "$file" "episode_sort")
        ex_year=$(get_tag "$file" "date"); ex_year="${ex_year:0:4}"
        ex_desc=$(get_tag "$file" "description") # Wir lesen auch die alte Description
    
        if [[ "$fforce" == "true" ]]; then
            deep_clean_tags "${file}"
        fi

        ap_args=()
        update_info=""

        # ---- Start: Argumente String für atomicparsley bauen

        if [[ ( -z "$ex_artist" || "$force" == "true" || "$fforce" == "true" ) && ( -n "$new_artist" || "$fforce" == "true" ) ]]; then
            ap_args+=( --artist "$new_artist" )
            update_info+="Artist "
        fi

        if [[ ( -z "$ex_show" || "$force" == "true" || "$fforce" == "true" ) && ( -n "$new_show" || "$fforce" == "true" ) ]]; then
            ap_args+=( --TVShowName "$new_show" )
            update_info+="Show "
        fi

        if [[ ( -z "$ex_title" || "$force" == "true" || "$fforce" == "true" ) && ( -n "$new_title" || "$fforce" == "true" ) ]]; then
            ap_args+=( --title "$new_title" )
            update_info+="Title "
        fi
        
        if [[ ( -z "$ex_year" || "$force" == "true" || "$fforce" == "true" ) && ( -n "$new_year" || "$fforce" == "true" ) ]]; then
            ap_args+=( --year "$new_year" )
            update_info+="Jahr "
        fi
        
        if [[ ( -z "$ex_desc" || "$force" == "true" || "$fforce" == "true" ) && ( -n "$new_desc" || "$fforce" == "true" ) ]]; then
            ap_args+=( --description "$new_desc" )
            update_info+="Desc "
        fi

        write_season="false"
        
        if [[ ( -z "$ex_season" || "$force" == "true" || "$fforce" == "true" ) && ( -n "$new_season" || "$fforce" == "true" ) ]]; then
            ap_args+=( --TVSeasonNum "$new_season" )
            write_season="true"; update_info+="Season "
        fi
        
        if [[ ( -z "$ex_episode" || "$force" == "true" || "$fforce" == "true" ) && ( -n "$new_episode" || "$fforce" == "true" ) ]]; then
            ap_args+=( --TVEpisodeNum "$new_episode" )
            write_season="true"; update_info+="Episode "
        fi

        is_tv_show="false"
        
        if [[ "$update_info" == *"Show"* ]] || [[ "$update_info" == *"Season"* ]] || [[ "$update_info" == *"Episode"* ]]; then
            is_tv_show="true"
        fi

        if [[ "$is_tv_show" == "true" ]]; then
            ap_args+=( --stik "TV Show" )
            if [[ -n "$new_episode" ]]; then
                if [[ -n "$new_total" ]]; then
                    ap_args+=( --tracknum "$new_episode/$new_total" )
                else
                    ap_args+=( --tracknum "$new_episode" )
                fi
                if [[ -z "$new_desc" && -z "$ex_desc" ]]; then
                    local s_txt="${new_season:-?}"
                    ap_args+=( --description "Staffel $s_txt, Episode $new_episode" )
                    if [[ -n "$new_total" ]]; then
                        unset 'ap_args[${#ap_args[@]}-1]' 
                        unset 'ap_args[${#ap_args[@]}-1]' 
                        ap_args+=( --description "Staffel $s_txt, Episode $new_episode von $new_total" )
                    fi
                fi
            fi
        else
            :
        fi

        # ---- Ende: Argumente String für atomicparsley bauen

        if (( ${#ap_args} == 0 )); then
            return 0
        fi

        util.print "  -> Update: $update_info"
        util.print "---------------------------------------------------"
        util.printf "DATEI:  %s\n" "$basename"
        util.printf "  %-10s | %-30s | %s\n" "TAG" "ALT" "NEU"
        util.print "  -----------------------------------------------------------------------"
        util.printf "  %-10s | %-30s | %s\n" "Artist"  "${ex_artist:--}"  "${new_artist}"
        util.printf "  %-10s | %-30s | %s\n" "Show"    "${ex_show:--}"    "${new_show}"
        util.printf "  %-10s | %-30s | %s\n" "Titel"   "${ex_title:--}"   "${new_title}"
        util.printf "  %-10s | %-30s | %s\n" "Jahr"    "${ex_year:--}"    "${new_year}"
        util.printf "  %-10s | %-30s | %s\n" "Desc"    "${${ex_desc//$'\n'/ }:0:20}..."  "${${new_desc//$'\n'/ }:0:20}..."
        util.printf "  %-10s | %-30s | %s\n" "Staffel" "${ex_season:--}"  "${new_season}"
        util.printf "  %-10s | %-30s | %s\n" "Episode" "${ex_episode:--}" "${new_episode}"
        util.print ""

        if [[ "$dry_run" == "true" ]]; then
            util.print "  [DRY-RUN] Würde AtomicParsley starten."
            return 0
        fi

        output=$("$AP_CMD" "$file" "${ap_args[@]}" --overWrite 2>&1)
        exit_code=$?
        if [[ $exit_code -eq 0 ]]; then
            # 1. Metadaten lesen bzw, Cover check
            has_cover=$(get_tag "$file" "cover")
            title=$(get_tag "$file" "title")
            show=$(get_tag "$file" "show")
            season_number=$(get_tag "$file" "season_number")
            episode_sort=$(get_tag "$file" "episode_sort")
            artist=$(get_tag "$file" "artist")
            year=$(get_tag "$file" "date")
            descr=$(get_tag "$file" "description")

            util.print "     [OK] Aktualisiert:"
            util.printf "DATEI:  %s\n" "$basename"
            util.printf "  %-14s %s\n" "Cover vorh.:" "${${has_cover:+ja}:-nein}"
            util.printf "  %-14s %s\n" "Titel:"       "${title:--}"
            util.printf "  %-14s %s\n" "Show:"        "${show:--}"
            util.printf "  %-14s %s\n" "Staffel:"     "${season_number:--}"
            util.printf "  %-14s %s\n" "Episode:"     "${episode_sort:--}"
            util.printf "  %-14s %s\n" "Artist:"      "${artist:--}"
            util.printf "  %-14s %s\n" "Jahr:"      "${year:--}"
            util.print ""
            return 0
        else
            if [[ "$output" =~ "bad mpeg4 file|insufficient space" ]]; then
                util.print "     [WARNUNG] AtomicParsley gescheitert (Kein MP4-Container oder zu wenig Platz)."
                util.print "     -> Starte FFmpeg Reparatur (Remux nach .m4v)..."
                local temp_fixed="${file:r}.m4v"
            
                ffmpeg -hide_banner -loglevel error \
                    -i "$file" \
                    -map 0 \
                    -c copy \
                    -dn \
                    -f mp4 -movflags +faststart \
                    "$temp_fixed"
                
                if [[ $? -eq 0 ]]; then
                    # 1. Zielverzeichnis (Timestamp-Ordner) erstellen
                    local target_dir="${file:h}/$TIMESTAMP"
                    mkdir -p "$target_dir"
                    
                    # 2. Zieldatei im neuen Ordner definieren (gleicher Name, .m4v)
                    local target_file="${target_dir}/${file:t:r}.m4v"
                    
                    # 3. Reparierte Datei in den Timestamp-Ordner verschieben
                    mv "$temp_fixed" "$target_file"
                    
                    # 4. Ursprüngliche Datei als DEPRECATED markieren (.old)
                    # ${file:h} hält den Pfad, ${file:t} liefert den Dateinamen inkl. alter Endung
                    local deprecated_file="${file:h}/DEPRECATED_${file:t}.old"
                    mv "$file" "$deprecated_file"
                    
                    util.print "     [OK] Datei repariert und verschoben nach: $target_file"
                    util.print "     [INFO] Originaldatei umbenannt in: $deprecated_file"
                    util.print "     [INFO] ⚠️ Der Dateiname und der Eintrag in der JSON DB muss ggf. auf .m4v angepasst werden!"
                    util.print "     [INFO] Starte AtomicParsley auf der neuen Datei erneut"

                    output=$("$AP_CMD" "$target_file" "${ap_args[@]}" --overWrite 2>&1)
                    exit_code=$?
                    if [[ $exit_code -eq 0 ]]; then
                        # 1. Metadaten lesen bzw, Cover check
                        has_cover=$(get_tag "$target_file" "cover")
                        title=$(get_tag "$target_file" "title")
                        show=$(get_tag "$target_file" "show")
                        season_number=$(get_tag "$target_file" "season_number")
                        episode_sort=$(get_tag "$target_file" "episode_sort")
                        artist=$(get_tag "$target_file" "artist")
                        year=$(get_tag "$target_file" "date")
                        descr=$(get_tag "$target_file" "description")

                        util.print "     [OK] Aktualisiert:"
                        util.printf "DATEI:  %s\n" "$target_file"
                        util.printf "  %-14s %s\n" "Cover vorh.:" "${${has_cover:+ja}:-nein}"
                        util.printf "  %-14s %s\n" "Titel:"       "${title:--}"
                        util.printf "  %-14s %s\n" "Show:"        "${show:--}"
                        util.printf "  %-14s %s\n" "Staffel:"     "${season_number:--}"
                        util.printf "  %-14s %s\n" "Episode:"     "${episode_sort:--}"
                        util.printf "  %-14s %s\n" "Artist:"      "${artist:--}"
                        util.printf "  %-14s %s\n" "Jahr:"      "${year:--}"
                        util.print ""
                        print_r_file="$target_file"
                        return 2
                    else
                        util.print "     [ERROR] Auch nach der FFmpeg Reparatur wurden die Metadaten nicht geschrieben."
                        return 3
                    fi
                else
                    util.print "     [ERROR] Auch FFmpeg Reparatur gescheitert."
                    rm -f "$temp_fixed"
                    return 4
                fi
            else
                util.print "     [ERROR] Unbekannter AtomicParsley Fehler:"
                util.print "$output"
                return 5
            fi
        fi
    } || r_code=$?

    print -r -- "$print_r_file"

    return $r_code
}

main "$@"

exit $?