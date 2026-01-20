#!/bin/zsh
# Arch Linux Update Checker (ChatGPT-4o generiert mit ein paar Anpassungen)
# Nutzt eine eigene temporäre Paketdatenbank
# Zeigt Repo, Beschreibung
# Lokale System-Datenbank bleibt unverändert

## Hinweis: die temporäre DB muss wieder gelöscht werden.

# Paketinfo aus TMP-DB holen
get_pkg_info() {
  local pkg="$1" oldver="$2" newver="$3"
  local info repo groups desc secflag

  info=$(LC_ALL=C pacman --dbpath "$TMPDB" -Si "$pkg")
  repo=$(echo "$info" | awk '/^Repository/ {print $3}')
  desc=$(echo "$info" | awk '/^Description/ {$1=""; print substr($0,2)}')

  printf "\033[1;36m%s\033[0m%s\n" "$pkg" "$secflag"
  printf "    Version: %s → %s\n" "$oldver" "$newver"
  printf "    Repo: %s\n" "${repo:--}"
  printf "    %s\n\n" "$desc"
}

# 1. Temp-DB anlegen
TMPDB=$(mktemp -d /tmp/arch-update-check.XXXXXX)
# trap 'rm -rf "$TMPDB"' EXIT INT TERM

# 2. lokale DB reinkopieren und Rechte setzen
sudo mkdir -p "$TMPDB"/local
sudo cp -a /var/lib/pacman/local/* "$TMPDB"/local/
sudo chmod -R a+rwx "$TMPDB"

# 3. Sync-DB nur in $TMPDB, ohne System-DB anzutasten
sudo pacman --dbpath "$TMPDB" -Sy --quiet

# 4. Updates auslesen und in Zsh-Array packen
UPDATES=("${(@f)$(pacman --dbpath "$TMPDB" -Qu | awk '{print $1, $2, $4}')}")

if (( $#UPDATES == 0 || ( $#UPDATES == 1 && ${#UPDATES[1]} == 0 ) )); then
  echo "✅ Keine Updates verfügbar."
  exit 0
fi

echo

echo "📦 Verfügbare Updates:"
echo

for entry in "${UPDATES[@]}"; do
  get_pkg_info ${(z)entry}
done

# Nachfrage zum Update
read -q "REPLY?➡️  Jetzt aktualisieren? [y/N] "
echo
if [[ "$REPLY" == [yY] ]]; then
  sudo pacman -Syu
else
  echo "❌ Update abgebrochen."
fi

