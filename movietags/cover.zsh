#!/bin/zsh

# return : =1 in case of error else =0

zmodload zsh/zutil

# Globbing-Einstellungen
setopt EXTENDED_GLOB
setopt NULL_GLOB
unsetopt NOMATCH

my_marker="🟣"

source "${0:A:h}/src/utils.zsh"

typeset flag_test_run
typeset flag_dry_run
typeset flag_force
typeset flag_cover_only
typeset -a arg_layout
typeset -a arg_infile

typeset flag_verbose
typeset flag_help

typeset usage=(
    "Verwendung: $0 [OPTIONEN]"
    ""
    "Optionen:"
    "  -h,  --help           Zeigt diese Hilfe an und beendet das Skript"
    "  -v,  --verbose        Log an"
    "  -fo, --force          Erzwingt das Neuladen/Überschreiben vorhandener Cover"
    "  -co, --cover-only     Erstellt Cover aber schreibt sie nicht in die Film-Datei"
    "  -tr, --test-run       Startet den Testmodus mit Test Film-Dateien und verwendet Testverzeichnisse"
    "  -dr, --dry-run        Simuliert den Durchlauf, ohne Dateien zu verändern"
    "  -lo, --layout <arg>   Gibt das zu verwendende layout (FHD | Portrait | Square | Landscape) für Cover an"
    "  -in, --infile <arg>   Eingabe Film-Datei ansonsten stdin"
)

zparseopts -D -F -K -- \
    {h,-help}=flag_help \
    {v,-verbose}=flag_verbose \
    {fo,-force}=flag_force \
    {co,-cover-only}=flag_cover_only \
    {tr,-test-run}=flag_test_run \
    {dr,-dry-run}=flag_dry_run \
    {lo,-layout}:=arg_layout \
    {in,-infile}:=arg_infile 2>/dev/null || {
        print -l >&2 "Fehler: Ungültige Argumente übergeben."
        print -l >&2 "${usage[@]}"
        return 1
    }

### Initialize

typeset test_run="false"
typeset dry_run="false"
typeset force="false"
typeset cover_only="false"
typeset layout="Landscape"
typeset in_file=""

if [[ -n "$flag_help" ]]; then
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

if [[ -n "${flag_cover_only:-}" ]]; then
    cover_only="true"
fi

if (( $#arg_layout )); then
    layout=${arg_layout[-1]}
fi

echo $arg_layout
echo $layout

if (( $#arg_infile )); then
    in_file=${arg_infile[-1]}
fi

if [[ "$test_run" == "true" ]]; then
    if [[ ! -d "${TEST_MOVIES_DIR}" || ! -f "${TEST_INVENTORY_DB}" ]]; then
        print >&2 "${my_marker} Keine Testumgebung vorhanden."
        exit -1
    fi
    check_dependencies magick
else
    check_dependencies magick
fi

util.print "Gewähltes layout: $layout"
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
            if ! cover.run "$in_file"; then
                util.print "Warnung: Bearbeitung von $in_file wurde abgebrochen."
                r_code=1
            fi
        elif [[ ! -t 0 ]]; then
            util.print "File Source by Stdin"
            while IFS= read -r file; do
                [[ -z "$file" ]] && continue
                print >&2 "${my_marker} File: $file"
                if ! cover.run "$file"; then
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
            if ! cover.run "$file"; then
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
cover.run() {
    local file="$1"
    local print_r_file="$1"
    local integer r_code=0

    basename="${file:t:r}"
    extension="${file:e}"

    util.print "Filmdatei: $file"

    () {
        has_cover=$(get_tag "$file" "cover")
        title=$(get_tag "$file" "title")
        show=$(get_tag "$file" "show")
        season_number=$(get_tag "$file" "season_number")
        episode_sort=$(get_tag "$file" "episode_sort")
        artist=$(get_tag "$file" "artist")
        year=$(get_tag "$file" "date")
        descr=$(get_tag "$file" "description")

        util.print "Filmdatei: $file"

        util.printf "DATEI:          %s\n" "$basename"
        util.printf "  %-14s %s\n" "Cover vorh.:" "${${has_cover:+ja}:-nein}"
        util.printf "  %-14s %s\n" "Titel:"       "${title:--}"
        util.printf "  %-14s %s\n" "Show:"        "${show:--}"
        util.printf "  %-14s %s\n" "Staffel:"     "${season_number:--}"
        util.printf "  %-14s %s\n" "Episode:"     "${episode_sort:--}"
        util.printf "  %-14s %s\n" "Artist:"      "${artist:--}"
        util.printf "  %-14s %s\n" "Jahr:"      "${year:--}"
        util.print ""

        if [[ -n "$has_cover" ]] && [[ "$force" == "false" ]]; then
            [[ "$dry_run" == "true" ]] && util.print "[SKIP] Cover bereits vorhanden: $basename"
            if [[ "$cover_only" == "false" ]]; then
                return 0
            fi
        fi
        
        if [[ -n "$has_cover" && "$force" == "true" && "$cover_only" == "false" ]]; then
            util.print "  [force] Überschreibe existierendes Cover."
        fi

        util.print "Generiere Cover für: $basename"
        util.print "     Text: $title ${artist:+($artist)}"

        if [[ "$dry_run" == "true" && "$cover_only" == "false" ]]; then
            util.print "  [DRY-RUN] Würde ImageMagick und AtomicParsley starten."
            return 0
        elif [[ "$dry_run" == "false" && "$cover_only" == "true" ]]; then
            util.print "  [DRY-RUN] Würde AtomicParsley starten."
        fi

        safe_name="${basename//[^a-zA-Z0-9]/_}"
        cover_dir="${INVENTORY_DB:h}/cover/$TIMESTAMP"
        mkdir -p $cover_dir
        cover_file="$cover_dir/cover_${safe_name}.png"

        # Basis-Referenzwert
        base_width=540
        base_height=750
        case "$layout" in
            "FHD")
                util.print "  [INFO] Lade layout: 1920x1080 (FHD)"
                width=1920
                height=1080
                fs_show=$((  45 * width / base_width ))
                fs_season_episode=$((  35 * width / base_width ))
                fs_artist=$(( 35 * width / base_width ))
                fs_year=$((   30 * width / base_width ))
                area_width_pct=70
                area_height_pct=90
                ;;

            "Portrait")
                util.print "  [INFO] Lade layout: 540x750 (Portrait)"
                width=540
                height=750
                fs_show=$((  45 * width / base_width ))
                fs_season_episode=$((  50 * width / base_width ))
                fs_artist=$(( 35 * width / base_width ))
                fs_year=$((   45 * width / base_width ))
                area_width_pct=80
                area_height_pct=65
                ;;

            "Square")
                util.print "  [INFO] Lade layout: 750x750 (Square)"
                width=750
                height=750
                fs_show=$((  45 * width / base_width ))
                fs_season_episode=$((  45 * width / base_width ))
                fs_artist=$(( 35 * width / base_width ))
                fs_year=$((   45 * width / base_width ))
                area_width_pct=80
                area_height_pct=70
                ;;

            "Landscape")
                util.print "  [INFO] Lade layout: 750x540 (Landscape)"
                width=750
                height=540
                fs_show=$((  35 * width / base_width ))
                fs_season_episode=$((  40 * width / base_width ))
                fs_artist=$(( 35 * width / base_width ))
                fs_year=$((   45 * width / base_width ))
                area_width_pct=70
                area_height_pct=90
                ;;

            *)
                # Fallback
                util.print "  [ERROR] Unbekanntes layout '$layout'. Breche ab."
                return 2
                ;;
        esac

        # --- Basis-Dimensionen berechnen ---
        text_width=$(( width * area_width_pct / 100 ))
        
        # Maximaler Abstand vom Zentrum nach oben/unten
        max_y_offset=$(( height * area_height_pct / 200 )) 

        # --- Dynamische Lücken (Gaps) basierend auf Skalierung ---
        gap_top_upper=$(( 10 * width / base_width ))
        gap_lower_bottom=$(( 10 * width / base_width ))

        # --- Äußere Textzeilen positionieren ---
        off_top=$(( max_y_offset - (fs_season_episode / 2) ))
        off_bottom=$(( max_y_offset - (fs_artist / 2) ))

        # --- Innere Textzeilen positionieren (von den Rändern nach innen arbeiten) ---
        off_middle=$(( off_top - ( (fs_season_episode + fs_show) / 2 ) - gap_top_upper ))
        off_lower=$(( off_bottom - ( (fs_artist + fs_year) / 2 ) - gap_lower_bottom ))

        # --- Berechnung für den optionalen Title (zwischen Season/Episode und Year) - CASE A ---
        gap_title=$(( 20 * width / base_width ))

        # Y-Koordinaten der Ränder (0 ist in der Mitte, - ist oben, + ist unten)
        # Unterkante von Season/Episode:
        y_bottom_se=$(( -off_middle + (  fs_season_episode / 2) ))
        # Oberkante von Year:
        y_top_year=$(( off_lower - (fs_year / 2) ))

        # Verfügbare Höhe für den Title
        title_height_case_a=$(( y_top_year - y_bottom_se - (2 * gap_title) ))

        # Vertikale Mitte zwischen Season/Episode und Year
        off_title_case_a=$(( (y_bottom_se + y_top_year) / 2 ))

        # Vorzeichen sicherstellen, damit ImageMagick nicht über +0+-10 stolpert
        if (( off_title_case_a >= 0 )); then
            geom_title_case_a="+0+${off_title_case_a}"
        else
            geom_title_case_a="+0${off_title_case_a}"
        fi
        # -----------------------------------------------------------------------------
        # --- Berechnung für den optionalen Title (zwischen Show und Year) - CASE B ---
        # Unterkante von Show (Show nutzt fs_show und liegt bei -off_top):
        y_bottom_show=$(( -off_top + (fs_show / 2) ))

        # Verfügbare Höhe für den Title (y_top_year ist aus CASE A bekannt)
        title_height_case_b=$(( y_top_year - y_bottom_show - (2 * gap_title) ))

        # Vertikale Mitte zwischen Show und Year
        off_title_case_b=$(( (y_bottom_show + y_top_year) / 2 ))

        # Vorzeichen sicherstellen, damit ImageMagick nicht über +0+-10 stolpert
        if (( off_title_case_b >= 0 )); then
            geom_title_case_b="+0+${off_title_case_b}"
        else
            geom_title_case_b="+0${off_title_case_b}"
        fi

        # -----------------------------------------------------------------------------
        # --- Berechnung für den optionalen Title (zwischen Top und Year) - CASE C ---
        # Unterkante ist -off_top:
        y_bottom=$(( -off_top + 0 ))

        # Verfügbare Höhe für den Title (y_top_year ist aus CASE A bekannt)
        title_height_case_c=$(( y_top_year - y_bottom - (2 * gap_title) ))

        # Vertikale Mitte zwischen Show und Year
        off_title_case_c=$(( (y_bottom + y_top_year) / 2 ))

        # Vorzeichen sicherstellen, damit ImageMagick nicht über +0+-10 stolpert
        if (( off_title_case_c >= 0 )); then
            geom_title_case_c="+0+${off_title_case_c}"
        else
            geom_title_case_c="+0${off_title_case_c}"
        fi
        # -----------------------------------------------------------------------------

        # Font-Definition basierend auf dem OS
        if [[ "$OSTYPE" == "darwin"* ]]; then
            font_bold="System-Font-Semibold"
            font_medium="System-Font-Medium"
        else
            # Für Arch Linux (GNOME Standardfonts)
            font_bold="Liberation-Sans-Bold"
            font_medium="Liberation-Sans"
        fi
        () {
            # Fall 1: "Einzelwerk" - Keine Show und keine ( Staffel und Episode ) 
            if [[ -z "$show" && ( -z "$season_number" || -z "$episode_sort" ) ]]; then
                util.print "Fall 1: Einzelwerk erkannt (show='$show', season_number='$season_number', episode_sort='$episode_sort')"
                util.print "   title='$title', artist='$artist', year='$year'"
                
                if [[ -z "$artist" && -z "$year" ]]; then
                    util.print "     Fall 1.1: Kein Artist, kein Year"
                    magick -size ${width}x${height} xc:grey66 \
                        -depth 8 \
                        -colorspace sRGB \
                        -density 72 -units PixelsPerInch \
                        -gravity center \
                        \( -background none -fill "white" -font "$font_bold" +pointsize \
                            -size ${text_width}x${title_height_case_c} caption:"$title" \) \
                        -geometry ${geom_title_case_c} -composite \
                        "$cover_file"
                    return
                fi
                if [[ -n "$artist" && -z "$year" ]]; then
                    util.print "     Fall 1.2: Mit Artist ('$artist'), kein Year"
                    magick -size ${width}x${height} xc:grey66 \
                        -depth 8 \
                        -colorspace sRGB \
                        -density 72 -units PixelsPerInch \
                        -gravity center \
                        \( -background none -fill "white" -font "$font_bold" +pointsize \
                            -size ${text_width}x${title_height_case_c} caption:"$title" \) \
                        -geometry ${geom_title_case_c} -composite \
                        \( -background none -fill "brown" -font "$font_medium" -pointsize $fs_artist \
                            -size ${text_width}x caption:"$artist" \) \
                        -geometry +0+${off_bottom} -composite \
                        "$cover_file"
                    return
                fi
                if [[ -z "$artist" && -n "$year" ]]; then
                    util.print "     Fall 1.3: Kein Artist, mit Year ('$year')"
                    magick -size ${width}x${height} xc:grey66 \
                        -depth 8 \
                        -colorspace sRGB \
                        -density 72 -units PixelsPerInch \
                        -gravity center \
                        \( -background none -fill "white" -font "$font_bold" +pointsize \
                            -size ${text_width}x${title_height_case_c} caption:"$title" \) \
                        -geometry ${geom_title_case_c} -composite \
                        \( -background none -fill "green" -font "$font_medium" -pointsize $fs_year \
                            -size ${text_width}x caption:"$year" \) \
                        -geometry +0+${off_lower} -composite \
                        "$cover_file"
                    return
                fi
                if [[ -n "$artist" && -n "$year" ]]; then
                    util.print "     Fall 1.4: Mit Artist ('$artist') und Year ('$year')"
                    magick -size ${width}x${height} xc:grey66 \
                        -depth 8 \
                        -colorspace sRGB \
                        -density 72 -units PixelsPerInch \
                        -gravity center \
                        \( -background none -fill "white" -font "$font_bold" +pointsize \
                            -size ${text_width}x${title_height_case_c} caption:"$title" \) \
                        -geometry ${geom_title_case_c} -composite \
                        \( -background none -fill "green" -font "$font_medium" -pointsize $fs_year \
                            -size ${text_width}x caption:"$year" \) \
                        -geometry +0+${off_lower} -composite \
                        \( -background none -fill "brown" -font "$font_medium" -pointsize $fs_artist \
                            -size ${text_width}x caption:"$artist" \) \
                        -geometry +0+${off_bottom} -composite \
                        "$cover_file"
                    return
                fi
            fi

            # Fall 2: "Mehrteiler oder Serie" Show oder ( Staffel und Episode ) 
            if [[ -n "$show" || ( -n "$season_number" && -n "$episode_sort" ) ]]; then
                util.print "Fall 2: Mehrteiler/Serie erkannt (show='$show', season_number='$season_number', episode_sort='$episode_sort')"
                
                # Fall 2.1: Show und Season und Episode
                if [[ -n "$show" && -n "$season_number" && -n "$episode_sort" ]]; then
                    util.print "     Fall 2.1: Show ('$show') UND Season/Episode ('$season_number/$episode_sort') vorhanden"
                    
                    # Fall 2.1.1: kein Title
                    if [[ -z "$title" ]]; then
                        util.print "       Fall 2.1.1: Kein Title"
                        
                        # Fall 2.1.1.1: Artist und Year
                        if [[ -n "$artist" && -n "$year" ]]; then
                            util.print "         Fall 2.1.1.1: Mit Artist ('$artist') und Year ('$year')"
                            magick -size ${width}x${height} xc:grey66 \
                                -depth 8 \
                                -colorspace sRGB \
                                -density 72 -units PixelsPerInch \
                                -gravity center \
                                \( -background none -fill "white" -font "$font_bold" -pointsize $fs_show \
                                    -size ${text_width}x caption:"$show" \) \
                                -geometry +0-${off_top} -composite \
                                \( -background none -fill "SteelBlue4" -font "$font_bold" -pointsize $fs_season_episode \
                                    -size ${text_width}x caption:"$season_number/$episode_sort" \) \
                                -geometry +0-${off_middle} -composite \
                                \( -background none -fill "green" -font "$font_medium" -pointsize $fs_year \
                                    -size ${text_width}x caption:"$year" \) \
                                -geometry +0+${off_lower} -composite \
                                \( -background none -fill "brown" -font "$font_medium" -pointsize $fs_artist \
                                    -size ${text_width}x caption:"$artist" \) \
                                -geometry +0+${off_bottom} -composite \
                                "$cover_file"
                            return
                        fi
                        # Fall 2.1.1.2: Artist und kein Year (Logik in Original war z="$artist" && n="$year")
                        # Korrigiert basierend auf deinem alten if-Block, wo du nach kein Artist und mit Year suchtest:
                        if [[ -z "$artist" && -n "$year" ]]; then
                            util.print "         Fall 2.1.1.2: Kein Artist, mit Year ('$year')"
                            magick -size ${width}x${height} xc:grey66 \
                                -depth 8 \
                                -colorspace sRGB \
                                -density 72 -units PixelsPerInch \
                                -gravity center \
                                \( -background none -fill "white" -font "$font_bold" -pointsize $fs_show \
                                    -size ${text_width}x caption:"$show" \) \
                                -geometry +0-${off_top} -composite \
                                \( -background none -fill "SteelBlue4" -font "$font_bold" -pointsize $fs_season_episode \
                                    -size ${text_width}x caption:"$season_number/$episode_sort" \) \
                                -geometry +0-${off_middle} -composite \
                                \( -background none -fill "green" -font "$font_medium" -pointsize $fs_year \
                                    -size ${text_width}x caption:"$year" \) \
                                -geometry +0+${off_lower} -composite \
                                "$cover_file"
                            return
                        fi
                    fi
                    
                    # Fall 2.1.2: Title
                    if [[ -n "$title" ]]; then
                        util.print "       Fall 2.1.2: Mit Title ('$title')"
                        
                        # Fall 2.1.2.1: Artist, Year
                        if [[ -n "$artist" && -n "$year" ]]; then
                            util.print "         Fall 2.1.2.1: Mit Artist ('$artist') und Year ('$year')"
                            magick -size ${width}x${height} xc:grey66 \
                                -depth 8 \
                                -colorspace sRGB \
                                -density 72 -units PixelsPerInch \
                                -gravity center \
                                \( -background none -fill "white" -font "$font_bold" -pointsize $fs_show \
                                    -size ${text_width}x caption:"$show" \) \
                                -geometry +0-${off_top} -composite \
                                \( -background none -fill "SteelBlue4" -font "$font_bold" -pointsize $fs_season_episode \
                                    -size ${text_width}x caption:"$season_number/$episode_sort" \) \
                                -geometry +0-${off_middle} -composite \
                                \( -background none -fill "white" -font "$font_bold" +pointsize \
                                    -size ${text_width}x${title_height_case_a} caption:"$title" \) \
                                -geometry ${geom_title_case_a} -composite \
                                \( -background none -fill "green" -font "$font_medium" -pointsize $fs_year \
                                    -size ${text_width}x caption:"$year" \) \
                                -geometry +0+${off_lower} -composite \
                                \( -background none -fill "brown" -font "$font_medium" -pointsize $fs_artist \
                                    -size ${text_width}x caption:"$artist" \) \
                                -geometry +0+${off_bottom} -composite \
                                "$cover_file"
                            return
                        fi
                        # Fall 2.1.2.2: kein Artist, Year
                        if [[ -z "$artist" && -n "$year" ]]; then
                            util.print "         Fall 2.1.2.2: Kein Artist, mit Year ('$year')"
                            magick -size ${width}x${height} xc:grey66 \
                                -depth 8 \
                                -colorspace sRGB \
                                -density 72 -units PixelsPerInch \
                                -gravity center \
                                \( -background none -fill "white" -font "$font_bold" -pointsize $fs_show \
                                    -size ${text_width}x caption:"$show" \) \
                                -geometry +0-${off_top} -composite \
                                \( -background none -fill "SteelBlue4" -font "$font_bold" -pointsize $fs_season_episode \
                                    -size ${text_width}x caption:"$season_number/$episode_sort" \) \
                                -geometry +0-${off_middle} -composite \
                                \( -background none -fill "white" -font "$font_bold" +pointsize \
                                    -size ${text_width}x${title_height_case_a} caption:"$title" \) \
                                -geometry ${geom_title_case_a} -composite \
                                \( -background none -fill "green" -font "$font_medium" -pointsize $fs_year \
                                    -size ${text_width}x caption:"$year" \) \
                                -geometry +0+${off_lower} -composite \
                                "$cover_file"
                            return
                        fi
                        # Fall 2.1.2.3: Artist, kein Year (Logik & Variable korrigiert)
                        if [[ -n "$artist" && -z "$year" ]]; then
                            util.print "         Fall 2.1.2.3: Mit Artist ('$artist'), kein Year"
                            magick -size ${width}x${height} xc:grey66 \
                                -depth 8 \
                                -colorspace sRGB \
                                -density 72 -units PixelsPerInch \
                                -gravity center \
                                \( -background none -fill "white" -font "$font_bold" -pointsize $fs_show \
                                    -size ${text_width}x caption:"$show" \) \
                                -geometry +0-${off_top} -composite \
                                \( -background none -fill "SteelBlue4" -font "$font_bold" -pointsize $fs_season_episode \
                                    -size ${text_width}x caption:"$season_number/$episode_sort" \) \
                                -geometry +0-${off_middle} -composite \
                                \( -background none -fill "white" -font "$font_bold" +pointsize \
                                    -size ${text_width}x${title_height_case_a} caption:"$title" \) \
                                -geometry ${geom_title_case_a} -composite \
                                \( -background none -fill "brown" -font "$font_medium" -pointsize $fs_artist \
                                    -size ${text_width}x caption:"$artist" \) \
                                -geometry +0+${off_bottom} -composite \
                                "$cover_file"
                            return
                        fi
                        # Fall 2.1.2.4: kein Artist, kein Year
                        if [[ -z "$artist" && -z "$year" ]]; then
                            util.print "         Fall 2.1.2.4: Kein Artist, kein Year"
                            magick -size ${width}x${height} xc:grey66 \
                                -depth 8 \
                                -colorspace sRGB \
                                -density 72 -units PixelsPerInch \
                                -gravity center \
                                \( -background none -fill "white" -font "$font_bold" -pointsize $fs_show \
                                    -size ${text_width}x caption:"$show" \) \
                                -geometry +0-${off_top} -composite \
                                \( -background none -fill "SteelBlue4" -font "$font_bold" -pointsize $fs_season_episode \
                                    -size ${text_width}x caption:"$season_number/$episode_sort" \) \
                                -geometry +0-${off_middle} -composite \
                                \( -background none -fill "white" -font "$font_bold" +pointsize \
                                    -size ${text_width}x${title_height_case_a} caption:"$title" \) \
                                -geometry ${geom_title_case_a} -composite \
                                "$cover_file"
                            return
                        fi
                    fi
                fi

                # Fall 2.2: Show und keine ( Staffel und Episode ) 
                if [[ -n "$show" && ( -z "$season_number" || -z "$episode_sort" ) ]]; then
                    util.print "     Fall 2.2: Show ('$show') vorhanden, aber Season/Episode fehlen"
                    
                    # Fall 2.2.1/2: Title Handling
                    if [[ -z "$title" ]]; then
                        util.print "       Fall 2.2.1: Kein Title vorhanden. Setze title=show ('$show')"
                        title="$show"
                    else
                        util.print "       Fall 2.2.2: Title ('$title') ist bereits vorhanden."
                    fi
                    
                    # Fall 2.2.x.1: Artist, Year
                    if [[ -n "$artist" && -n "$year" ]]; then
                        util.print "         Fall 2.2.x.1: Mit Artist ('$artist') und Year ('$year')"
                        magick -size ${width}x${height} xc:grey66 \
                            -depth 8 \
                            -colorspace sRGB \
                            -density 72 -units PixelsPerInch \
                            -gravity center \
                            \( -background none -fill "white" -font "$font_bold" -pointsize $fs_show \
                                -size ${text_width}x caption:"$show" \) \
                            -geometry +0-${off_top} -composite \
                            \( -background none -fill "white" -font "$font_bold" +pointsize \
                                -size ${text_width}x${title_height_case_b} caption:"$title" \) \
                            -geometry ${geom_title_case_b} -composite \
                            \( -background none -fill "green" -font "$font_medium" -pointsize $fs_year \
                                -size ${text_width}x caption:"$year" \) \
                            -geometry +0+${off_lower} -composite \
                            \( -background none -fill "brown" -font "$font_medium" -pointsize $fs_artist \
                                -size ${text_width}x caption:"$artist" \) \
                            -geometry +0+${off_bottom} -composite \
                            "$cover_file"
                        return
                    fi
                    # Fall 2.2.x.2: kein Artist, Year
                    if [[ -z "$artist" && -n "$year" ]]; then
                        util.print "         Fall 2.2.x.2: Kein Artist, mit Year ('$year')"
                        magick -size ${width}x${height} xc:grey66 \
                            -depth 8 \
                            -colorspace sRGB \
                            -density 72 -units PixelsPerInch \
                            -gravity center \
                            \( -background none -fill "white" -font "$font_bold" -pointsize $fs_show \
                                -size ${text_width}x caption:"$show" \) \
                            -geometry +0-${off_top} -composite \
                            \( -background none -fill "white" -font "$font_bold" +pointsize \
                                -size ${text_width}x${title_height_case_b} caption:"$title" \) \
                            -geometry ${geom_title_case_b} -composite \
                            \( -background none -fill "green" -font "$font_medium" -pointsize $fs_year \
                                -size ${text_width}x caption:"$year" \) \
                            -geometry +0+${off_lower} -composite \
                            "$cover_file"
                        return
                    fi
                    # Fall 2.2.x.3: Artist, kein Year (Logik & Variable korrigiert)
                    if [[ -n "$artist" && -z "$year" ]]; then
                        util.print "         Fall 2.2.x.3: Mit Artist ('$artist'), kein Year"
                        magick -size ${width}x${height} xc:grey66 \
                            -depth 8 \
                            -colorspace sRGB \
                            -density 72 -units PixelsPerInch \
                            -gravity center \
                            \( -background none -fill "white" -font "$font_bold" -pointsize $fs_show \
                                -size ${text_width}x caption:"$show" \) \
                            -geometry +0-${off_top} -composite \
                            \( -background none -fill "white" -font "$font_bold" +pointsize \
                                -size ${text_width}x${title_height_case_b} caption:"$title" \) \
                            -geometry ${geom_title_case_b} -composite \
                            \( -background none -fill "brown" -font "$font_medium" -pointsize $fs_artist \
                                -size ${text_width}x caption:"$artist" \) \
                            -geometry +0+${off_bottom} -composite \
                            "$cover_file"
                        return                    
                    fi
                    # Fall 2.2.x.4: kein Artist, kein Year
                    if [[ -z "$artist" && -z "$year" ]]; then
                        util.print "         Fall 2.2.x.4: Kein Artist, kein Year"
                        magick -size ${width}x${height} xc:grey66 \
                            -depth 8 \
                            -colorspace sRGB \
                            -density 72 -units PixelsPerInch \
                            -gravity center \
                            \( -background none -fill "white" -font "$font_bold" -pointsize $fs_show \
                                -size ${text_width}x caption:"$show" \) \
                            -geometry +0-${off_top} -composite \
                            \( -background none -fill "white" -font "$font_bold" +pointsize \
                                -size ${text_width}x${title_height_case_b} caption:"$title" \) \
                            -geometry ${geom_title_case_b} -composite \
                            "$cover_file"
                        return
                    fi      
                fi
            fi

            # Fall 3: "Film Information nicht ausreichend" - Keine Show und kein Titel 
            if [[ -z "$show" && -z "$title" ]]; then
                util.print "[ERROR] Fall 3: Weder Show noch Title vorhanden. Metadaten nicht ausreichend."
                return
            fi

            # Fall 4: (Fehler in der Programm Logik)
            util.print "[ERROR] Fall 4: Unbekannter Zustand. (show='$show', title='$title', season='$season_number', episode='$episode_sort', artist='$artist', year='$year')"
        }
  
        if [[ -e "$cover_file" ]]; then
            util.print "Cover erstellt: $cover_file "
        else
            util.print "[ERROR] Kein Cover erstellt: $cover_file "
            return 1
        fi

        if [[ "$dry_run" == "false" && "$cover_only" == "true" ]]; then
            return 0
        fi

        # Bild schreiben mit AtomicParsley oder ffmpeg

        if "$AP_CMD" "$file" --artwork REMOVE_ALL --artwork "$cover_file" --overWrite >/dev/null 2>&1; then
            util.print "     [OK] Cover eingebettet (AtomicParsley)."
            return 0
        else
            util.print "     [WARNUNG] AtomicParsley fehlgeschlagen (zu wenig Header-Platz oder .mov Container)."
            util.print "        Starte FFmpeg Fallback (Reparatur & Umwandlung in .m4v)..."
            
            local target_dir="${file:h}/$TIMESTAMP"
            mkdir -p "$target_dir"
            
            local target_file="${target_dir}/${file:t:r}.m4v"

            ffmpeg -hide_banner -loglevel quiet \
                -i "$file" -i "$cover_file" \
                -map "0:v" -map "0:a?" -map "0:s?" \
                -map 1 \
                -c copy \
                -dn \
                -f mp4 \
                -movflags +faststart \
                -disposition:v:1 attached_pic \
                "$target_file"
                
            if [[ $? -eq 0 ]]; then
                local deprecated_file="${file:h}/DEPRECATED_${file:t}.old"
                mv "$file" "$deprecated_file"
                
                util.print "     [OK] Cover eingebettet & repariert in: $target_file"
                util.print "     [INFO] Originaldatei umbenannt in: $deprecated_file"
                util.print "     [INFO] ⚠️ Der Dateiname und der Eintrag in der JSON DB muss ggf. auf .m4v angepasst werden!"
                util.print "     [INFO] ⚠️ Es könnte sein, dass Metadaten aus der bisherigen Datei nicht übernommen wurden!"
                print_r_file="$target_file"
                return 2
            else
                util.print "     [ERROR] Auch FFmpeg ist gescheitert."
                rm -f "$target_file"
                return 1
            fi
        fi
    } || r_code=$?

    print -r -- "$print_r_file"

    return $r_code
}

main "$@"

exit $?