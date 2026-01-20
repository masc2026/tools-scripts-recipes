# globals.zsh

set -euo pipefail

GLOBALS_DIR="${0:A:h}"
GLOBALS_DIR="${GLOBALS_DIR:a}"

MAIN_DIR="${GLOBALS_DIR}/.."
MAIN_DIR="${MAIN_DIR:a}"

TAG_DIR="${MAIN_DIR}"
TAG_DIR="${TAG_DIR:a}"

COVER_DIR="${MAIN_DIR}"
COVER_DIR="${COVER_DIR:a}"

INVENTORY_DIR="${MAIN_DIR}"
INVENTORY_DIR="${INVENTORY_DIR:a}"

SRC_DIR="${GLOBALS_DIR}/../src"
SRC_DIR="${SRC_DIR:a}"

TEST_DIR="${GLOBALS_DIR}/../test"
TEST_DIR="${TEST_DIR:a}"

TEST_MOVIES_DIR="${TEST_DIR}/movies"
TEST_MOVIES_DIR="${TEST_MOVIES_DIR:a}"

TEST_INVENTORY_DB="${TEST_MOVIES_DIR}/filme_inventory.json"
TEST_INVENTORY_DB="${TEST_INVENTORY_DB:a}"

INVENTORY_DB="${MAIN_DIR}/filme_inventory.json"
INVENTORY_DB="${INVENTORY_DB:a}"

NO_PRINT="${NO_PRINT:-true}"
EXTENSIONS="(mp4|m4v)"

# export TIMESTAMP=$(print -P '%D{%Y%m%d_%H%M%S}')
[[ -z "${TIMESTAMP:-}" ]] && print -v TIMESTAMP -P '%D{%Y%m%d_%H%M%S}'

# 3. Globale Datenstrukturen
typeset -g -A DB_ENTRIES
typeset -g DB_LOADED="false"
typeset -g AP_CMD=""
typeset -g INVENTAR_DATEI=""

# print -l -- "-----------------------------------"
# print -l -- "GLOBALS_DIR       : $GLOBALS_DIR"
# print -l -- "MAIN_DIR          : $MAIN_DIR"
# print -l -- "TAG_DIR           : $TAG_DIR"
# print -l -- "COVER_DIR         : $COVER_DIR"
# print -l -- "INVENTORY_DIR     : $INVENTORY_DIR"
# print -l -- "SRC_DIR           : $SRC_DIR"
# print -l -- "TEST_DIR          : $TEST_DIR"
# print -l -- "TEST_MOVIES_DIR   : $TEST_MOVIES_DIR"
# print -l -- "TEST_INVENTORY_DB : $TEST_INVENTORY_DB"
# print -l -- "INVENTORY_DB      : $INVENTORY_DB"
# print -l -- "TIMESTAMP         : $TIMESTAMP"
# print -l -- "NO_PRINT          : $NO_PRINT"
# print -l -- "-----------------------------------"