#!/usr/bin/env zsh

set -e

try_mode=false
[[ "$1" == "--try" ]] && try_mode=true

EMOJI_OK="🟢"
EMOJI_WARN="🟡"
EMOJI_ERR="🔴"
EMOJI_INFO="🔵"

if [[ "$LANG" == *".UTF-8"* ]]; then
    sym_ok=$EMOJI_OK
    sym_warn=$EMOJI_WARN
    sym_err=$EMOJI_ERR
    sym_info=$EMOJI_INFO
else
    sym_ok="OK: "
    sym_warn="WARN: "
    sym_err="ERR: "
    sym_info="INFO: "
fi

## Hier den Stick Pfad anpassen:
local stick="/run/media/fama/Ventoy/sshconfig"

## Hier den Pfad zum Konfigurationsfile setzen:
local json_file="${stick}/ssh_config.json"

## Hier den Pfad zum .env File setzen:
local env_path_stick="${stick}/.env"

local ssh_config_file

get_secret_safe() {
    local key_path="$1"
    local exit_status=0

    if [[ -z "$SSH_TTY" ]] || [[ -n "$DISPLAY" ]]; then
        secret-tool lookup unique "ssh-store:${key_path}" 2>/dev/null
        return $?
    else
        timeout 1.5s secret-tool lookup unique "ssh-store:${key_path}" 2>/dev/null
        exit_status=$?
        return $exit_status
    fi
}

check_default_keyring_ready() {
    dbus-send --session --print-reply \
        --dest=org.freedesktop.secrets \
        /org/freedesktop/secrets/aliases/default \
        org.freedesktop.DBus.Properties.Get \
        string:'org.freedesktop.Secret.Collection' \
        string:'Label' >/dev/null 2>&1
    
    local check_default_keyring_ready_status=$?
    
    if [[ $check_default_keyring_ready_status -eq 0 ]]; then
        return 0 # Alles bestens, Default existiert.
    else
        return 1 # Kein Default-Keyring gesetzt/vorhanden.
    fi
}

ensure_ssh_agent_ready() {
    # 1. Prüfen, ob die Variable überhaupt gesetzt ist
    if [[ -z "$SSH_AUTH_SOCK" ]]; then
        echo "${sym_err} SSH_AUTH_SOCK ist nicht gesetzt."
        return 1
    fi

    # 2. Der Weckruf: ssh-add -l
    # Das startet den Agenten per Socket Activation, falls er schläft.
    # Wir ignorieren stdout, uns interessiert nur der Return Code.
    ssh-add -l >/dev/null 2>&1
    local ensure_ssh_agent_ready_status=$?

    # Status 2 = Fataler Fehler (Verbindung nicht möglich)
    if [[ $ensure_ssh_agent_ready_status -eq 2 ]]; then
        echo "${sym_err} Kein Zugriff auf SSH-Agent möglich (Socket tot?)."
        return 1
    fi

    # 3. Jetzt, wo er sicher läuft, holen wir die PID für das Log
    # Wir nehmen fuser, da lsof manchmal fehlt. Fallback auf pgrep/ss.
    local agent_pid=""
    if command -v fuser >/dev/null; then
        agent_pid=$(fuser "$SSH_AUTH_SOCK" 2>/dev/null)
    fi
    
    # Falls fuser leer war (oder nicht installiert), Versuch über ss (Socket Statistics)
    if [[ -z "$agent_pid" ]]; then
        # Extrahiert die PID aus der SS-Ausgabe
        agent_pid=$(ss -a -x src "$SSH_AUTH_SOCK" -p | grep -oP 'pid=\K\d+' | head -n1)
    fi

    # Status 0 (Keys da) oder 1 (Leer) ist beides ein Erfolg für den Agent-Start
    if [[ -n "$agent_pid" ]]; then
        echo "${sym_ok} SSH-Agent aktiv (PID: $agent_pid)."
    else
        echo "${sym_ok} SSH-Agent aktiv (PID konnte nicht ermittelt werden)."
    fi

    return 0
}

# Überprüfen, ob jq vorhanden ist
if ! command -v jq &> /dev/null; then
    echo "${sym_err} 'jq' wurde nicht gefunden. 'jq' installieren." >&2
    exit 1
fi

# Überprüfen, ob secret-tool vorhanden ist
if ! command -v secret-tool &> /dev/null; then
    echo "${sym_err} 'secret-tool' wurde nicht gefunden. 'libsecret-tools' installieren." >&2
    exit 1
fi

# Überprüfe das JSON File auf dem Stick 
if [[ -f "$json_file" ]]; then
  ssh_config_file=$(jq -r '.ssh.config' "$json_file")
else
  echo "${sym_err} $json_file nicht gefunden "
  exit 1
fi

# Überprüfe das .env File
if [[ -f "$env_path_stick" ]]; then
  echo "${sym_info} Lade Passphrasen vom Stick..."
  source "$env_path_stick"
elif [[ -f "$env_path_local" ]]; then
  echo "${sym_warn} Lade lokale .env Datei..."
  source "$env_path_local"
else
  echo "${sym_err} Keine .env Datei gefunden (weder lokal noch auf Stick)."
  exit 1
fi

# Erstelle den .ssh Ordner
if $try_mode; then
echo "    [TRY] mkdir -p $HOME/.ssh"
echo "    [TRY] chmod 700 $HOME/.ssh"
else
  mkdir -p $HOME/.ssh
  chmod 700 $HOME/.ssh
fi

local timestamp=$(date +%Y%m%d_%H%M%S)
local backup_file="${ssh_config_file}.${timestamp}"

# Erstelle ein Backup für das config file im Skript Ordner
if [[ -f "$ssh_config_file" ]]; then
  if $try_mode; then
echo "    [TRY] cp '$ssh_config_file' '$backup_file'"
echo "    [TRY] rm -f '$ssh_config_file'"
echo "    [TRY] touch '$ssh_config_file'"
  else
    cp "$ssh_config_file" "$backup_file"
    rm -f "$ssh_config_file"
    touch "$ssh_config_file"
    echo "Backup erstellt: $backup_file"
  fi
else
  if $try_mode; then
echo "    [TRY] touch '$ssh_config_file' (kein Backup nötig)"
  else
    touch "$ssh_config_file"
  fi
fi

# Erstelle die ssh Konfiguration mit den ssh config und key files und die keyring Einträge
for host in $(jq -r '.ssh | keys_unsorted[] | select(. != "config")' "$json_file"); do
  for user in $(jq -r ".ssh[\"$host\"].user | keys_unsorted[]" "$json_file"); do
    echo "${sym_ok} host=$host user=$user"
    private_keyfile_src=$stick/$(jq -r ".ssh[\"$host\"].user[\"$user\"].privatekeyfile" "$json_file")
    public_keyfile_src=$stick/$(jq -r ".ssh[\"$host\"].user[\"$user\"].publickeyfile" "$json_file")
    port=$(jq -r "(.ssh[\"$host\"].user[\"$user\"].port // \"22\")" "$json_file")
    has_passphrase=$(jq -r "(.ssh[\"$host\"].user[\"$user\"].passphrase // 0)" "$json_file")
    private_keyfile_dest="$HOME/.ssh/id_${host}_${user}"
    public_keyfile_dest="$HOME/.ssh/id_${host}_${user}.pub"
    ssh_config_file_dest="$HOME/.ssh/config"
    
    env_key="${host}_${user}"
    pass_phrase="${(P)env_key}"

    if $try_mode; then

      if [[ "$has_passphrase" == "1" ]]; then
        # 1. Validiere ssh agenten

        if ! ensure_ssh_agent_ready; then
echo "    [TRY] ${sym_err} Problem mit SSH-Agent."
            exit 1
        fi

        # 2. Validiere Schlüsselbund
        
        if ! check_default_keyring_ready; then
echo "    [TRY] ${sym_err} Kein Login Schlüsselbund gefunden."
            exit 1
        fi

        # 3. Validiere keyring Einträge
        unset existing_secret
        local existing_secret
        unset get_secret_safe_status
        local get_secret_safe_status

        existing_secret=$(get_secret_safe "$private_keyfile_dest") && get_secret_safe_status=0 || get_secret_safe_status=$?

        if [[ $get_secret_safe_status -eq 124 ]]; then
echo "    [TRY] ${sym_err} Keyring ist gesperrt!"
            exit 1
        fi

        if [[ -n "$existing_secret" ]]; then
echo "    [TRY] ${sym_warn} Passphrase für ${private_keyfile_dest} ist bereits im secret-tool vorhanden."
        else
          if [[ -n "$pass_phrase" ]]; then
echo "    [TRY] ${sym_info} Erstelle Eintrag in keyring:"
echo "    [TRY]    echo "${pass_phrase:0:5}..." | secret-tool store \\"
echo "    [TRY]      --label=\"Passwort zum Entsperren von: ${private_keyfile_dest}\" \\"
echo "    [TRY]      xdg:schema org.freedesktop.Secret.Generic \\"
echo "    [TRY]      unique \"ssh-store:${private_keyfile_dest}\""
          echo ""
          else
echo "    [TRY] ${sym_err} Keine Passphrase für ${env_key} in .env gefunden und kein bestehender Eintrag im secret-tool."
          fi
        fi
      else
echo "    [TRY] ${sym_warn} Für ${private_keyfile_dest} wird kein Passphrase gebraucht."      
      fi

      # 4. Validiere Quelldateien
      if [[ ! -f "$private_keyfile_src" ]]; then
echo "    [TRY] ${sym_err} Private Key Source fehlt: $private_keyfile_src"
      elif [[ -f "$private_keyfile_dest" ]]; then
echo "    [TRY] ${sym_warn} Private Key Quelle bereits vorhanden: $private_keyfile_dest"
      else
echo "    [TRY] ${sym_info} cp '$private_keyfile_src' '$private_keyfile_dest'"
echo "    [TRY] ${sym_info} chmod 600 '$private_keyfile_dest'"
      fi

      # 5. Validiere Public Key Files
      if [[ ! -f "$public_keyfile_src" ]]; then
echo "    [TRY] ${sym_err} Public Key Source fehlt: $public_keyfile_src"
      elif [[ -f "$public_keyfile_dest" ]]; then
echo "    [TRY] ${sym_warn} Public Key Quelle bereits vorhanden: $public_keyfile_dest"
      else
echo "    [TRY] ${sym_info} cp '$public_keyfile_src' '$public_keyfile_dest'"
      fi
echo "    [TRY] ${sym_info} Erstelle Eintrag in $ssh_config_file:"
      jq -r ".ssh[\"$host\"].addresses | to_entries[] | select(.key | startswith(\"_\") | not) | \"\(.key) \(.value)\"" "$json_file" | while read -r addr_name addr_ip; do
echo "             Host ${host}-${user}-${addr_name}"
echo "               HostName ${addr_ip}"
echo "               Port $port"
echo "               User $user"
echo "               IdentitiesOnly yes"
echo "               IdentityFile $private_keyfile_dest"
echo "               AddKeysToAgent yes"
      done
    else
      if [[ "$has_passphrase" == "1" ]]; then
        # 1. Validiere ssh agenten
        
        if ! ensure_ssh_agent_ready; then
            echo "${sym_err} Problem mit SSH-Agent."
            exit 1
        fi

        # 2. Validiere Schlüsselbund
        
        if ! check_default_keyring_ready; then
            echo " ${sym_err} Kein Login Schlüsselbund gefunden."
            exit 1
        fi

        # 3. Validiere keyring Einträge

        unset existing_secret
        local existing_secret
        unset get_secret_safe_status
        local get_secret_safe_status

        existing_secret=$(get_secret_safe "$private_keyfile_dest") && get_secret_safe_status=0 || get_secret_safe_status=$?

        if [[ $get_secret_safe_status -eq 124 ]]; then
            echo "${sym_err} Keyring ist gesperrt!"
            exit 1
        fi
        if [[ -n "$existing_secret" ]]; then
          echo "${sym_warn} Passphrase für ${private_keyfile_dest} ist bereits im secret-tool vorhanden. Überspringe Speicherung."
        else
          # Nur speichern, wenn eine Passphrase in .env gefunden wurde und noch nichts im Store ist
          if [[ -n "$pass_phrase" ]]; then
            echo "Speichere neue Passphrase für ${env_key} im secret-tool..."
            echo "$pass_phrase" | secret-tool store \
              --label="Passwort zum Entsperren von: ${private_keyfile_dest}" \
              xdg:schema org.freedesktop.Secret.Generic \
              unique "ssh-store:${private_keyfile_dest}"
          else
            echo "${sym_err} Keine Passphrase für ${env_key} in .env gefunden und kein bestehender Eintrag im secret-tool."
          fi
        fi
      else
        echo "${sym_warn} Für ${private_keyfile_dest} wird kein Passphrase gebraucht."  
      fi

      # 4. Validiere Quelldateien
      
      if [[ ! -f "$private_keyfile_src" ]]; then
        echo "    ${sym_err} Quelldatei fehlt: $private_keyfile_src"
      elif [[ -f "$private_keyfile_dest" ]]; then
        echo "    ${sym_warn} Private Key bereits vorhanden: $private_keyfile_dest"
      else
        cp "$private_keyfile_src" "$private_keyfile_dest"
        chmod 600 "$private_keyfile_dest"
        echo "    ${sym_ok} Private Key kopiert."
      fi

      # 5. Validiere Public Key Files

      if [[ ! -f "$public_keyfile_src" ]]; then
        echo "    ${sym_err} Quelldatei fehlt: $public_keyfile_src"
      elif [[ -f "$public_keyfile_dest" ]]; then
        echo "    ${sym_warn} Public Key bereits vorhanden: $public_keyfile_dest"
      else
        cp "$public_keyfile_src" "$public_keyfile_dest"
        echo "    ${sym_ok} Public Key kopiert."
      fi

      jq -r ".ssh[\"$host\"].addresses | to_entries[] | select(.key | startswith(\"_\") | not) | \"\(.key) \(.value)\"" "$json_file" | while read -r addr_name addr_ip; do
        echo "Host ${host}-${user}-${addr_name}" >> "$ssh_config_file"
        echo "  HostName ${addr_ip}" >> "$ssh_config_file"
        echo "  Port $port" >> "$ssh_config_file"
        echo "  User $user" >> "$ssh_config_file"
        echo "  IdentitiesOnly yes" >> "$ssh_config_file"
        echo "  IdentityFile $private_keyfile_dest" >> "$ssh_config_file"
        echo "  AddKeysToAgent yes" >> "$ssh_config_file"
        echo "" >> "$ssh_config_file"
      done
    fi
  done
done

local timestamp=$(date +%Y%m%d_%H%M%S)
local backup_dest="${ssh_config_file_dest}.${timestamp}"

if [[ -f "$ssh_config_file_dest" ]]; then
  if $try_mode; then
echo "    [TRY] ${sym_info} Backup am Ziel: $ssh_config_file_dest → $backup_dest"
echo "    [TRY] ${sym_info} Kopiere $ssh_config_file → $ssh_config_file_dest"
  else
    # Backup der existierenden Ziel-Datei
    cp "$ssh_config_file_dest" "$backup_dest"
    # Eigentlicher Kopiervorgang
    cp "$ssh_config_file" "$ssh_config_file_dest"
    echo "Backup der Ziel-Config erstellt: $backup_dest"
  fi
else
  if $try_mode; then
echo "    [TRY] ${sym_info} Kopiere $ssh_config_file → $ssh_config_file_dest (kein Backup nötig)"
  else
    cp "$ssh_config_file" "$ssh_config_file_dest"
  fi
fi