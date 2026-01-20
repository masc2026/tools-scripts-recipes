#!/bin/zsh

zmodload zsh/zutil

# Globbing-Einstellungen
setopt EXTENDED_GLOB
setopt NULL_GLOB
unsetopt NOMATCH

source "${0:A:h}/../src/utils.zsh"

rm -rf "${TEST_MOVIES_DIR:?}"
mkdir -p "${TEST_MOVIES_DIR:?}"
rm -f ${TEST_INVENTORY_DB:?}
touch ${TEST_INVENTORY_DB:?}
gen_test_movies
