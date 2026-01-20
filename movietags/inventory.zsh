#!/bin/zsh

# return : =1 in case of error else =0

zmodload zsh/zutil

# Globbing-Einstellungen
setopt EXTENDED_GLOB
setopt NULL_GLOB
unsetopt NOMATCH

typeset my_marker="⚪"

source "${0:A:h}/src/utils.zsh"

typeset flag_test_run
typeset flag_dry_run
typeset flag_force
typeset flag_update_paths
typeset -a arg_infile

typeset flag_help
typeset  flag_verbose

local usage=(
    "Verwendung: $0 [OPTIONEN]"
    ""
    "Optionen:"
    "  -h,  --help           Zeigt diese Hilfe an und beendet das Skript"
    "  -v,  --verbose        Log an"
    "  -fo, --force          Überschreibt Daten, wenn schon Daten zur Film-Datei in der Dtenbank stehen"
    "  -up, --update-paths   Versucht die Film-Datei Pfade zu aktualisieren, wenn sich nur die Endung (mp4 / m4v) geändert hat"
    "  -tr, --test-run       Startet den Testmodus mit Test Film-Dateien und verwendet Testverzeichnisse"
    "  -dr, --dry-run        Simuliert den Durchlauf, ohne Dateien zu verändern"
    "  -in, --infile <arg>   Eingabe Film-Datei ansonsten stdin"
)

zparseopts -D -F -K -- \
    {h,-help}=flag_help \
    {v,-verbose}=flag_verbose \
    {fo,-force}=flag_force \
    {up,-update-paths}=flag_update_paths \
    {tr,-test-run}=flag_test_run \
    {dr,-dry-run}=flag_dry_run \
    {in,-infile}:=arg_infile 2>/dev/null || {
        print -l >&2 "Fehler: Ungültige Argumente übergeben."
        print -l >&2 "${usage[@]}"
        return 1
    }

### Initialize

local test_run="false"
local dry_run="false"
local force="false"
local update_paths="false"
local in_file

if [[ -n "$flag_help" ]]; then
    print -l >&2 "${usage[@]}"
    return 0
fi

if [[ -n "${flag_verbose:-}" ]]; then
    NO_PRINT="false"
else
    NO_PRINT="true"
fi

if [[ -n "$flag_test_run" ]]; then
    test_run="true"
fi

if [[ -n "$flag_dry_run" ]]; then
    dry_run="true"
fi

if [[ -n "$flag_force" ]]; then
    force="true"
fi

if [[ -n "$flag_update_paths" ]]; then
    update_paths="true"
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
    init_inventory "${TEST_INVENTORY_DB}"
else
    check_dependencies jq
    init_inventory "${INVENTORY_DB}"
fi

util.print "Inventar Datei: $INVENTAR_DATEI"
util.print "Pfad: $TAG_DIR"
util.print "Zeitstempel: $TIMESTAMP"

integer next_nr=1
max_found=0
updates_made="false"

### Run

# return : =1 falls ein Fehler auftrat, sonst =0
main() {
    if [[ "$test_run" == "false" ]]; then
        if [[ -n $in_file ]]; then
            util.print "File Source by Arg"
            print >&2 "${my_marker} File: $in_file"
            inventory.init
            if ! inventory.step "$in_file"; then
                util.print "Warnung: Bearbeitung von $in_file wurde abgebrochen."
            fi
            if ! inventory.push; then
                util.print "Warnung: Bearbeitung von $file wurde abgebrochen."
            fi
        elif [[ ! -t 0 ]]; then
            util.print "File Source by Stdin"
            inventory.init
            while IFS= read -r file; do
                [[ -z "$file" ]] && continue
                print >&2 "${my_marker} File: $file"
                if ! inventory.step "$file"; then
                    util.print "Warnung: Bearbeitung von $file wurde abgebrochen."
                fi
            done
            if ! inventory.push; then
                util.print "Warnung: Bearbeitung von $file wurde abgebrochen."
            fi
        else
            util.print "No files"
        fi
    else
        inventory.init
        if [[ -n $in_file ]]; then
            util.print "File Source by Arg (Test Mode)"
            print >&2 "${my_marker} File: $in_file"
            inventory.init
            if ! inventory.step "$in_file"; then
                util.print "Warnung: Bearbeitung von $in_file wurde abgebrochen."
            fi
            if ! inventory.push; then
                util.print "Warnung: Bearbeitung von $file wurde abgebrochen."
            fi
        elif if [[ ! -t 0 ]]; then
            util.print "File Source by Stdin (Test Mode)"
            while IFS= read -r file; do
                [[ -z "$file" ]] && continue
                print >&2 "${my_marker} File: $file"
                if ! inventory.step "$file"; then
                    util.print "Warnung: Bearbeitung von $file wurde abgebrochen."
                fi
            done
        else
            util.print "File Source Test Movies by Stdin (Test Mode)"
            while IFS= read -r file; do
                [[ -z "$file" ]] && continue
                print >&2 "${my_marker} File: $file"
                if ! inventory.step "$file"; then
                    util.print "Warnung: Bearbeitung von $file wurde abgebrochen."
                    r_code=1
                fi
            done < <(print -l -- "${TEST_MOVIES_DIR}"/*.${~EXTENSIONS}(N))
        fi
        if ! inventory.push; then
            util.print "Warnung: Bearbeitung von $file wurde abgebrochen."
            r_code=1
        fi
    fi
    util.print "Fertig."
}

inventory.init() {
    max_found=$(jq '[.[] .nr] | max // 0' "$INVENTAR_DATEI")
    next_nr=$((max_found + 1))
}

# return : >0 in case of error else =0 and file to stdout
inventory.step() {
    local file="$1"
    local -i r_code=0

    # Absoluter Pfad der Datei
    abs_path="${file:A}"
    # Dateiname (Key für die DB)
    basename="${file:t}" 
    is_known="false"
    () {
        if [[ -n "${DB_ENTRIES[$basename]:-}" ]]; then
            is_known="true"
            util.print "Known : $basename"
        else
            local clean_name=""
            
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS: iconv
                clean_name=$(echo -n "$basename" | iconv -f UTF-8-MAC -t UTF-8)
            else
                # Linux (Arch): uconv
                clean_name=$(uconv -x any-nfc <<< "$basename")
            fi
            
            if [[ -n "${DB_ENTRIES[$clean_name]:-}" ]]; then
                basename="$clean_name"
                is_known="true"
                util.print "Known (after conv): $basename"
            else
                util.print "Unkown: $basename"
            fi
        fi

        if [[ "$update_paths" == "true" && "$is_known" == "false" ]]; then
            util.print "Skip (Neu/Unbekannt): $basename"
            return 0
        fi

        if [[ "$update_paths" == "true" ]]; then
            existing_json="${DB_ENTRIES[$basename]}"
            old_path=$(echo "$existing_json" | jq -r '.datei')
            
            if [[ "$old_path" != "$abs_path" ]]; then
                util.print "[PATH UPDATE] $basename"
                if [[ "$dry_run" == "false" ]]; then
                    updated_json=$(echo "$existing_json" | jq -c --arg p "$abs_path" '.datei = $p')
                    DB_ENTRIES[$basename]=$updated_json
                    updates_made="true"
                fi
            fi
            return 0
        fi

        if [[ "$is_known" == "true" && "$force" == "false" ]]; then
            return 0
        fi

        m_title=$(get_tag "$file" "title")
        m_artist=$(get_tag "$file" "artist")
        m_show=$(get_tag "$file" "show")
        m_season=$(get_tag "$file" "season_number")
        m_episode=$(get_tag "$file" "episode_sort")
        m_year=$(get_tag "$file" "date")

        if [[ "$is_known" == "true" ]]; then
            action="[UPDATE/force]"
            util.print "$action $basename"
            util.print "    -> Title: $m_title | Artist: $m_artist"

            if [[ "$dry_run" == "true" ]]; then return; fi

            json_obj=$(echo "${DB_ENTRIES[$basename]}" | jq -c \
                --arg datei "$abs_path" \
                --arg artist "$m_artist" \
                --arg show "$m_show" \
                --arg title "$m_title" \
                --arg ep "$m_episode" \
                --arg se "$m_season" \
                --arg yr "$m_year" \
                '.datei = $datei | 
                .artist = $artist | 
                .show = $show | 
                .titel.de = $title | 
                .episode = $ep |
                .year = $yr |
                .season = $se')
        else
            action="[NEU]"
            util.print "$action $basename"
            util.print "    -> Title: $m_title | Artist: $m_artist"
            
            if [[ "$dry_run" == "true" ]]; then return; fi

            current_nr=$next_nr
            ((next_nr++))

            json_obj=$(jq -n -c \
            --argjson nr "$current_nr" \
            --arg datei "$abs_path" \
            --arg base "$basename" \
            --arg artist "$m_artist" \
            --arg show "$m_show" \
            --arg title "$m_title" \
            --arg ep "$m_episode" \
            --arg se "$m_season" \
            --arg yr "$m_year" \
            '{
                nr: $nr,
                datei: $datei,
                filebasename: $base,
                artist: $artist,
                show: $show,
                regisseur: { name: "" },
                titel: { de: $title, orig: "" },
                episode: $ep,
                season: $se,
                jahr: $yr,
                darsteller: [{"rolle": "", "actor": ""}]
            }')
        fi
        DB_ENTRIES[$basename]=$json_obj
        updates_made="true"
    } || r_code=$?

    return $r_code
}

inventory.push() {
    if [[ "$dry_run" == "true" ]]; then
        util.print "DRY RUN BEENDET. Keine Änderungen gespeichert."
        return 0
    fi

    if [[ "$updates_made" == "false" ]]; then
        util.print "Keine Änderungen nötig. Datenbank ist aktuell."
        return 0
    fi

    temp_json="${INVENTAR_DATEI}.tmp"

    printf "%s\n" "${DB_ENTRIES[@]}" | jq -s 'sort_by(.nr)' > "$temp_json"

    if [[ -s "$temp_json" ]]; then
        # --- BACKUP ERSTELLEN ---
        if [[ -f "$INVENTAR_DATEI" ]]; then
            local timestamp=$(date +"%Y%m%d_%H%M%S")
            
            local backup_dir="${INVENTAR_DATEI:r}"
            
            mkdir -p "$backup_dir"
            
            local backup_datei="${backup_dir}/${INVENTAR_DATEI:t:r}_${timestamp}.${INVENTAR_DATEI:e}"
            
            cp "$INVENTAR_DATEI" "$backup_datei"
            util.print "Backup erstellt in: $backup_datei"
        fi
        # ------------------------

        mv "$temp_json" "$INVENTAR_DATEI"
        util.print "Datenbank gespeichert ($INVENTAR_DATEI)."
        util.print "Gesamteinträge: ${#DB_ENTRIES}"
        return 0
    else
        util.print "FEHLER: Temp-Datei leer. Abbruch."
        rm -f "$temp_json"
        return 1
    fi
}

main "$@"

exit $?