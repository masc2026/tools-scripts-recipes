# Beispiel mit Dummy Daten für den Stick für Testlauf im `--try` Mode

## ⚠️ ACHTUNG: Verzeichnis enthält Demo-Schlüssel (Dummy Keys)

**NICHT FÜR ECHTE VERBINDUNGEN VERWENDEN!**

Der Ordner [./keys](./dummy_sshconfig/keys/) enthält generierte **Dummy Test-Schlüssel** für Demonstrationszwecke.

Die Datei [.env](./dummy_sshconfig/.env) enthält die Passphrases.

Die Dateien **nur** verwenden, um das Skript `setup-ssh-connections.zsh` trocken (im `--try` Mode) zu testen. 

Für echte Server eigene, sichere Schlüssel generieren und Konfiguration an das Netzwerk und die Hosts anpassen. 

Key Paar Genereierung zum Beispiel so:

```bash
KEYS_DIR=<stickpath>"/sshconfig/keys"
ssh-keygen -t ed25519 -f "$KEYS_DIR/host_user" -C "host_user"
```

Dann einen Eintrag `host_user` mit dem verwendeten Passphrase im [.env](./.env) erstellen.

## dummy Testlauf

[./dummmy_sshconfig](./dummy_sshconfig) auf den Stick kopieren.

Im Skript `setup_ssh_config.zsh` den stick Pfad `<stickpath>` richtig setzen:

```bash
local stick="<stickpath>/dummy_sshconfig"
```

`--try` Run im Verzeichnis `~/Projekte/github/tools-scripts-recipes/sshconfig`:

```bash
./setup-ssh-connections.zsh --try  
```

Log:

```bash
🔵 Lade Passphrasen vom Stick...
    [TRY] mkdir -p /home/user/.ssh
    [TRY] chmod 700 /home/user/.ssh
    [TRY] touch './config_tmp.txt' (kein Backup nötig)
🟢 host=host01 user=userX ssh=ssh host01-userX
🟢 SSH-Agent aktiv (PID:   7587).
    [TRY] 🔵 Erstelle Eintrag in keyring:
    [TRY]    echo 4711... | secret-tool store \
    [TRY]      --label="Passwort zum Entsperren von: /home/user/.ssh/id_host01_userX" \
    [TRY]      xdg:schema org.freedesktop.Secret.Generic \
    [TRY]      unique "ssh-store:/home/user/.ssh/id_host01_userX"

    [TRY] 🔵 cp '/run/media/user/stickname/dummy_sshconfig/keys/host01_userX' '/home/user/.ssh/id_host01_userX'
    [TRY] 🔵 chmod 600 '/home/user/.ssh/id_host01_userX'
    [TRY] 🔵 cp '/run/media/user/stickname/dummy_sshconfig/keys/host01_userX.pub' '/home/user/.ssh/id_host01_userX.pub'
    [TRY] 🔵 Erstelle Eintrag in ./config_tmp.txt:
             Host host01-userX
               HostName 192.168.2.101
               User userX
               IdentitiesOnly yes
               IdentityFile /home/user/.ssh/id_host01_userX
               AddKeysToAgent yes
🟢 host=host01 user=userY ssh=ssh host01-userY
🟢 SSH-Agent aktiv (PID:   7587).
    [TRY] 🔵 Erstelle Eintrag in keyring:
    [TRY]    echo 4712... | secret-tool store \
    [TRY]      --label="Passwort zum Entsperren von: /home/user/.ssh/id_host01_userY" \
    [TRY]      xdg:schema org.freedesktop.Secret.Generic \
    [TRY]      unique "ssh-store:/home/user/.ssh/id_host01_userY"

    [TRY] 🔵 cp '/run/media/user/stickname/dummy_sshconfig/keys/host01_userY' '/home/user/.ssh/id_host01_userY'
    [TRY] 🔵 chmod 600 '/home/user/.ssh/id_host01_userY'
    [TRY] 🔵 cp '/run/media/user/stickname/dummy_sshconfig/keys/host01_userY.pub' '/home/user/.ssh/id_host01_userY.pub'
    [TRY] 🔵 Erstelle Eintrag in ./config_tmp.txt:
             Host host01-userY
               HostName 192.168.2.101
               User userY
               IdentitiesOnly yes
               IdentityFile /home/user/.ssh/id_host01_userY
               AddKeysToAgent yes
🟢 host=host02 user=userU ssh=ssh host02-userU
🟢 SSH-Agent aktiv (PID:   7587).
    [TRY] 🔵 Erstelle Eintrag in keyring:
    [TRY]    echo 4713... | secret-tool store \
    [TRY]      --label="Passwort zum Entsperren von: /home/user/.ssh/id_host02_userU" \
    [TRY]      xdg:schema org.freedesktop.Secret.Generic \
    [TRY]      unique "ssh-store:/home/user/.ssh/id_host02_userU"

    [TRY] 🔵 cp '/run/media/user/stickname/dummy_sshconfig/keys/host02_userU' '/home/user/.ssh/id_host02_userU'
    [TRY] 🔵 chmod 600 '/home/user/.ssh/id_host02_userU'
    [TRY] 🔵 cp '/run/media/user/stickname/dummy_sshconfig/keys/host02_userU.pub' '/home/user/.ssh/id_host02_userU.pub'
    [TRY] 🔵 Erstelle Eintrag in ./config_tmp.txt:
             Host host02-userU
               HostName 192.168.2.102
               User userU
               IdentitiesOnly yes
               IdentityFile /home/user/.ssh/id_host02_userU
               AddKeysToAgent yes
    [TRY] 🔵 Backup am Ziel: /home/user/.ssh/config → /home/user/.ssh/config.20260112_172646
    [TRY] 🔵 Kopiere ./config_tmp.txt → /home/user/.ssh/config
```