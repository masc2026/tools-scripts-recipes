#!/bin/zsh

zmodload zsh/zutil

# Globbing-Einstellungen
setopt EXTENDED_GLOB
setopt NULL_GLOB
unsetopt NOMATCH

source "${0:A:h}/../src/utils.zsh"

export TIMESTAMP=$(print -P '%D{%Y%m%d_%H%M%S}')

${TEST_DIR}/gen_mov.zsh > /dev/null
${TAG_DIR}/tag.zsh --test-run > /dev/null
${COVER_DIR}/cover.zsh --test-run --layout Landscape > /dev/null
#${COVER_DIR}/cover.zsh --test-run --layout Portrait > /dev/null
#${COVER_DIR}/cover.zsh --test-run --layout Square > /dev/null
#${COVER_DIR}/cover.zsh --test-run --layout FHD > /dev/null

#${INVENTORY_DIR}/inventory.zsh --test-run > /dev/null