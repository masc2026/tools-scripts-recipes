#!/bin/zsh

if ! command -v jq &> /dev/null; then
    echo "Fehler: 'jq' wird benötigt."
    exit 1
fi

KEY_FILE="keys/Chrysotoxum.json"

TITLE=$(jq -r '.metadata.title' "$KEY_FILE")
DESC=$(jq -r '.metadata.description' "$KEY_FILE")

echo "\e[1;34m==========================================\e[0m"
echo "\e[1;32m  $TITLE\e[0m"
echo "\e[0;90m  $DESC\e[0m"
echo "\e[1;34m==========================================\e[0m\n"

CURRENT_NODE="1"

while true; do
    # Aktueller Knoten aus der JSON
    NODE_DATA=$(jq -r ".steps.\"$CURRENT_NODE\"" "$KEY_FILE")

    if [[ "$NODE_DATA" == "null" ]]; then
        echo "Fehler: Schritt '$CURRENT_NODE' existiert in der JSON-Datei nicht."
        exit 1
    fi

    # Lese die einzelnen Felder aus
    FRAGE=$(echo "$NODE_DATA" | jq -r '.frage')
    OPT_1=$(echo "$NODE_DATA" | jq -r '.option_1')
    ZIEL_1=$(echo "$NODE_DATA" | jq -r '.ziel_1')
    OPT_2=$(echo "$NODE_DATA" | jq -r '.option_2')
    ZIEL_2=$(echo "$NODE_DATA" | jq -r '.ziel_2')

    # Ausgabe für den Nutzer
    echo "\e[1mSchritt $CURRENT_NODE:\e[0m $FRAGE"
    echo "  [1] $OPT_1"
    echo "  [2] $OPT_2"
    
    # Eingabeaufforderung in zsh
    read -r "CHOICE?Deine Wahl (1 oder 2): "
    echo "" # Leerzeile für die Übersichtlichkeit

    # Entscheidung verarbeiten
    if [[ "$CHOICE" == "1" ]]; then
        NEXT_STEP="$ZIEL_1"
    elif [[ "$CHOICE" == "2" ]]; then
        NEXT_STEP="$ZIEL_2"
    else
        echo "\e[31mUngültige Eingabe. Bitte wähle 1 oder 2.\e[0m\n"
        continue
    fi

    if [[ ! "$NEXT_STEP" =~ ^[0-9]+$ ]]; then
        echo "\e[32m🎉 Bestimmung erfolgreich: $NEXT_STEP\e[0m"
        break
    else
        CURRENT_NODE="$NEXT_STEP"
    fi
done