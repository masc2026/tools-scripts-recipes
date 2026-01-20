#!/bin/zsh

zmodload zsh/zutil

# Globbing-Einstellungen
setopt EXTENDED_GLOB
setopt NULL_GLOB
unsetopt NOMATCH

source "${0:A:h}/../src/utils.zsh"

export TIMESTAMP=$(print -P '%D{%Y%m%d_%H%M%S}')

if ! command -v "parallel" &> /dev/null; then
    util.print "Fehler: parallel wurde nicht gefunden."
    exit 1
fi

${TEST_DIR}/gen_mov.zsh | parallel -j 16 "${TAG_DIR}/tag.zsh -in {} | ${COVER_DIR}/cover.zsh --layout Landscape" > /dev/null
#${TEST_DIR}/gen_mov.zsh | parallel -j 16 "${TAG_DIR}/tag.zsh -in {} | ${COVER_DIR}/cover.zsh --layout Portrait" > /dev/null
#${TEST_DIR}/gen_mov.zsh | parallel -j 16 "${TAG_DIR}/tag.zsh -in {} | ${COVER_DIR}/cover.zsh --layout Square" > /dev/null
#${TEST_DIR}/gen_mov.zsh | parallel -j 16 "${TAG_DIR}/tag.zsh -in {} | ${COVER_DIR}/cover.zsh --layout FHD" > /dev/null


#${INVENTORY_DIR}/inventory.zsh --test-run > /dev/null