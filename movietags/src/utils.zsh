# utils.zsh

source "${0:A:h}/globals.zsh"

# -------------------------------------------------------------------
# Funktionen
# -------------------------------------------------------------------

# Gibt nur was aus, wenn die Variable NO_PRINT auf false gesetzt ist
util.print() {
    if [[ "$NO_PRINT" == "false" ]]; then
        print >&2 "$@"
    fi
}

# Gibt nur was aus, wenn die Variable NO_PRINT auf false gesetzt ist
util.printf() {
    if [[ "$NO_PRINT" == "false" ]]; then
        printf "$@" >&2
    fi
}

gen_test_movies() {
    local test_dir="${TEST_DIR}"
    local src_m4v="${test_dir}/test.m4v"
    local src_mp4="${test_dir}/test.mp4"

    # Array mit allen Test-Dateinamen (ohne Dateiendung)
    testcases=(
        # Fall 1: "Einzelwerk" (Nur Titel, keine Show, keine Staffel/Episode)
        # über Filename parsen nicht unterscheidbar zu Fall 2.2
        "Sunshine and Clouds"
        "Unkown Artist - Sunshine and Clouds"
        "Sunshine and Clouds_2002"
        "Unkown Artist - Sunshine and Clouds_2002"
        
        # Fall 2.1: "Serie/Mehrteiler" (Ohne Titel) (Mit Show, Staffel, Episode)
        "Unkown Artist - London Sights_01_11_27_2002"
        "London Sights_01_11_27_2002"
        
        # Fall 2.1: "Serie/Mehrteiler" (Mit Titel) (Mit Show, Titel, Staffel, Episode)
        "Unkown Artist - London Sights . Sunshine and Clouds_01_11_27_2002"
        "London Sights . Sunshine and Clouds_01_11_27_2002"
        "Unkown Artist - London Sights . Sunshine and Clouds_01_11_27"
        "London Sights . Sunshine and Clouds_01_11_27"
        
        # Fall 2.2: Show (Ohne Staffel/Episode und Ohne Titel)
        # über Filename parsen nicht unterscheidbar zu Fall 1
        "Unkown Artist - London Sights_2002"
        "London Sights_2002"
        "Unkown Artist - London Sights"
        "London Sights"
        
        # Fall 2.2: Show (Ohne Staffel/Episode, aber Mit Titel)
        "Unkown Artist - London Sights . Sunshine and Clouds_2002"
        "London Sights . Sunshine and Clouds_2002"
        "Unkown Artist - London Sights . Sunshine and Clouds"
        "London Sights . Sunshine and Clouds"
    )

    testcases_descr=(
        "Sunshine and Clouds                                                1.1: Kein Artist, kein Year"
        "Unkown Artist - Sunshine and Clouds                                1.2: Mit Artist, kein Year"
        "Sunshine and Clouds_2002                                           1.3: Kein Artist, mit Year"
        "Unkown Artist - Sunshine and Clouds_2002                           1.4: Mit Artist, mit Year"
        "Unkown Artist - London Sights_01_11_27_2002                        2.1.1.1: Mit Artist, mit Year"
        "London Sights_01_11_27_2002                                        2.1.1.2: Kein Artist, mit Year"
        "Unkown Artist - London Sights . Sunshine and Clouds_01_11_27_2002  2.1.2.1: Mit Artist, mit Year"
        "London Sights . Sunshine and Clouds_01_11_27_2002                  2.1.2.2: Kein Artist, mit Year"
        "Unkown Artist - London Sights . Sunshine and Clouds_01_11_27       2.1.2.3: Mit Artist, kein Year"
        "London Sights . Sunshine and Clouds_01_11_27                       2.1.2.4: Kein Artist, kein Year"
        "Unkown Artist - London Sights_2002                                 2.2.x.1: Mit Artist, mit Year"
        "London Sights_2002                                                 2.2.x.2: Kein Artist, mit Year"
        "Unkown Artist - London Sights                                      2.2.x.3: Mit Artist, kein Year"
        "London Sights                                                      2.2.x.4: Kein Artist, kein Year"
        "Unkown Artist - London Sights . Sunshine and Clouds_2002           2.2.x.1: Mit Artist, mit Year"
        "London Sights . Sunshine and Clouds_2002                           2.2.x.2: Kein Artist, mit Year"
        "Unkown Artist - London Sights . Sunshine and Clouds                2.2.x.3: Mit Artist, kein Year"
        "London Sights . Sunshine and Clouds                                2.2.x.4: Kein Artist, kein Year"
    )

    for i in {1..${#testcases[@]}}; do
        local tc=$testcases[$i]
        local desc=$testcases_descr[$i]

        util.print "Erstelle Testfall $i - $desc"
      
        cp "$src_m4v" "${test_dir}/movies/${tc}.m4v" && print -r -- "${test_dir}/movies/${tc}.m4v"(:A)
        cp "$src_mp4" "${test_dir}/movies/${tc}.mp4" && print -r -- "${test_dir}/movies/${tc}.mp4"(:A)
    done
    return 0
}

# Diese Funktion wird vom Hauptskript aufgerufen, wenn es bereit ist
init_inventory() {
    INVENTAR_DATEI="${1:-${INVENTORY_DB}}"
    INVENTAR_DATEI=${INVENTAR_DATEI:a}
    if [[ -f "$INVENTAR_DATEI" ]]; then
        util.print "Lade Inventar: $INVENTAR_DATEI"
        while IFS=$'\t' read -r key json_line; do
            DB_ENTRIES[$key]=$json_line
        done < <(jq -r '.[] | "\(.filebasename)\t\(.|tostring)"' "$INVENTAR_DATEI")
        DB_LOADED="true"
    else
        util.print "Fehler: Inventar-Datei nicht gefunden."
    fi
}

check_dependencies() {
    if command -v AtomicParsley &> /dev/null; then
        AP_CMD="AtomicParsley"
    elif command -v atomicparsley &> /dev/null; then
        AP_CMD="atomicparsley"
    else
        # Fallback
        AP_CMD="atomicparsley" 
    fi

    local deps=(ffprobe "$AP_CMD" ffmpeg)
    
    deps+=("$@")

    util.print "Prüfe Abhängigkeiten..."
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            util.print "Fehler: Der Befehl '$cmd' wurde nicht gefunden."
            util.print "Bitte installieren (z.B. sudo pacman -S $cmd oder brew install $cmd)."
            exit 1
        fi
    done
    util.print "Alle Abhängigkeiten gefunden."
}

# Hilfsfunktion: deep claen der verwendeten Meta Daten mit AtomicParsley
# (ffprobe Werte: title artist show season_number episode_sort date description)
deep_clean_tags() {
    # Die Zieldatei wird als erstes Argument übergeben
    local target_file="$1"

    if [[ -z "$target_file" || ! -f "$target_file" ]]; then
        util.print "Fehler: Keine gültige Datei an deep_clean_tags übergeben."
        return 1
    fi
  
    local clean_args=()
    
    # Title
    clean_args+=( --manualAtomRemove "moov.udta.meta.ilst.©nam" )
    
    # Artist
    clean_args+=( --manualAtomRemove "moov.udta.meta.ilst.©ART" )
    
    # Show
    clean_args+=( --manualAtomRemove "moov.udta.meta.ilst.tvsh" )
    
    # Description
    clean_args+=( --manualAtomRemove "moov.udta.meta.ilst.©des" ) # Short Desc
    clean_args+=( --manualAtomRemove "moov.udta.meta.ilst.desc" ) # Long Desc
    
    # Year
    clean_args+=( --manualAtomRemove "moov.udta.meta.ilst.©day" )

    # Season
    clean_args+=( --manualAtomRemove "moov.udta.meta.ilst.tvsn" )

    # Episode Sort/Number (tves) entfernen
    clean_args+=( --manualAtomRemove "moov.udta.meta.ilst.tves" )

    "$AP_CMD" "$target_file" "${clean_args[@]}" --overWrite > /dev/null
    
    if [[ $? -eq 0 ]]; then
        util.print "Metadaten bereinigt."
    fi
}

# Hilfsfunktion: Wert aus geladener DB holen
get_tag_inventory() {
    local file_basename="$1"
    local field="$2" 
    
    if [[ "$DB_LOADED" == "false" ]]; then return; fi
    local entry="${DB_ENTRIES[$file_basename]}"
    
    if [[ -n "$entry" ]]; then
        # Wert mit jq aus dem String parsen
        echo "$entry" | jq -r "$field // empty"
    fi
}

# Hilfsfunktion für ffprobe (liefert leeren String zurück, wenn Tag fehlt, und den Wert oder 1 falls cover existiert)
# tag Werte: title artist show season_number episode_sort date description cover
get_tag() {
    local file="$1"
    local tag="$2"
    local result

    if [[ "$tag" == "cover" ]]; then
        local out
        out=$(ffprobe -v quiet -select_streams v -show_entries stream_disposition=attached_pic -of default=noprint_wrappers=1 "$file" 2>/dev/null)
        if [[ "$out" == *"attached_pic=1"* ]]; then
            result="1"
        else
            result=""
        fi
    else
        result=$(ffprobe -v error -show_entries format_tags="$tag" -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null)
    fi
    print -n -- "$result"
}

# Hilfsfunktion: Description zusammenbauen (aus Regie + Darsteller)
build_description() {
    local file_basename="$1"
    
    if [[ "$DB_LOADED" == "false" ]]; then return; fi
    local entry="${DB_ENTRIES[$file_basename]}"
    
    if [[ -n "$entry" ]]; then
        # Text mit jq String Interpolation bauen
        echo "$entry" | jq -r '
            ("Regie:\n" + (.regisseur.name // "-")),
            "Darsteller:",
            (.darsteller[] | "\(.actor) als \(.rolle)")
        ' | paste -sd '\n' - # paste verbindet die Zeilen wieder sauber
        # Hinweis: jq gibt bei Array-Iteration jede Zeile einzeln aus, paste fügt sie zusammen
    fi
}
