# Automatisierung der SSH-Verbindungen

Das Skript `setup_ssh_connections.zsh` richtet passwortlose SSH-Verbindungen auf einem Linux Rechner ein. Es kopiert SSH-Schlüssel, erstellt die `~/.ssh/config` Datei und speichert die Passphrasen für die Schlüssel im System-Schlüsselbund (Keyring).

Über `~/.ssh/config` stehen dann für alle konfigurierte Hosts, User und Anbindungen eigene Bezeichner zur Verfügung:

**Beispiel:**

```bash
% ssh host01-lan-userX
Linux host01 6.12.62+rpt-rpi-2712 #1 SMP PREEMPT Debian 1:6.12.62-1+rpt1 (2025-12-18) aarch64

The programs included with the Debian GNU/Linux system are free software;
t
...
Last login: Mon Jan 12 15:32:14 2026 from 192.168.2.120
userX@host01:~ $ 
```

Siehe Dummy [Beispiel](./example/README.md) mit [Dummy Daten](./example/dummy_sshconfig/) für den Stick.

## Funktion

* Kopiert private und öffentliche Schlüssel vom USB-Stick in das Verzeichnis `~/.ssh/`.
* Setzt die richtigen Dateirechte.
* Erzeugt eine SSH-Konfigurationsdatei (`config`) basierend auf einer JSON-Vorlage.
* Kopiert `config` nach `~/.ssh/` und erstellt davor ein Backup eines bestehenden `~/.ssh/config`.
* Hinterlegt die Passphrasen der Schlüssel im System-Schlüsselbund (`secret-tool`), damit man sie nicht ständig eintippen muss.

## Vorbedingungen auf dem Computer

1. **Grafisch** am Desktop anmelden (nicht nur per SSH).
2. Schlüsselbund prüfen:
    * Programm **"Passwörter und Verschlüsselung"** (Seahorse) öffnen.
    * Links nach **"Login"** oder **"Standard-Schlüsselbund"** oder ähnlichem.
    * Sicherstellen, dass er existiert und **nicht gesperrt** (geschlossen) ist.
    * Rechtsklick und **"Zur Vorgabe machen"** (Set as default) wählen.
3. Falls kein Schlüsselbund existiert: einen neuen über das `+` Symbol erstellen und ihn als Vorgabe (default) wählen.

## Installation der Werkzeuge

Benötigte Pakete installieren.

**Debian / Raspberry Pi OS:**

```bash
sudo apt update
sudo apt install zsh jq libsecret-tools seahorse
```

**Arch Linux:**

```bash
sudo pacman -S zsh jq libsecret seahorse
```

## Vorbereitung des USB-Sticks

1. USB-Stick am Zielrechner einstecken.
2. Sicherstellen, dass die Struktur auf dem Stick so aussieht:

**Beispiel:**

```text
<Stick Pfad>/sshconfig
├── .env                          # Enthält die Passphrasen (Variable=Passwort)
├── ssh_config_RechnerA.json      # Konfiguration für Rechner A
├── ssh_config_RechnerB.json      # Konfiguration für Rechner B
└── keys                          # Ordner mit Schlüsseln
    ├── host01_userX
    ├── host01_userX.pub
    ├── host01_userY
    ├── host01_userY.pub
    ├── host02_userU
    ├── host02_userU.pub
    ├── host02_userV
    └── host02_userV.pub
```

## Konfigurationsdatei (JSON)

Die JSON-Datei auf dem Stick steuert das Skript. Sie legt fest, welche Computer erreichbar sind und welche Schlüssel das Skript kopiert.

**Struktur der Datei:**

* **config**: Ein temporärer Dateiname für das Skript (kann so bleiben).
* **host01** (Beispiel): Der Name des Ziel Rechners der `ssh` Verbindung.
* **addresses**: Die Hostname oder Adressen des Ziel Rechners.
* Einträge ohne Unterstrich (z.B. `"lan": "192.168.2.101"`) nutzt das Skript als `HostName` für die SSH-Verbindung.
* Einträge mit Unterstrich (z.B. `"_direct"`) ignoriert das Skript für die Konfiguration (dienen nur zur Info).


* **user**: Die Benutzerkonten für die Verbindung (z.B. "otti" oder "fama").
* **privatekeyfile / publickeyfile**: Der Pfad zu den Schlüsseldateien auf dem Stick (relativ zum Ordner `sshconfig`).

**Beispiel:**

```json
{
    "ssh": {
        "config": "./config_tmp.txt",
        "host01": {
            "group" : "Raspberry Pi",
            "addresses": {
                "_name": "rspb02",
                "lan" : "192.168.2.101",
                "_direct" : "10.10.10.3"
            },
            "user": {
                "userX": {
                    "privatekeyfile": "keys/host01_userX",
                    "publickeyfile": "keys/host01_userX.pub"
                },
                "userY": {
                    "privatekeyfile": "keys/host01_userY",
                    "publickeyfile": "keys/host01_userY.pub"
                }
            }
        },
        "host02": {
            ...
        }
    }
}
```

## Passwort-Datei (.env)

Die Datei `.env` speichert die Passwörter (Passphrasen) für die privaten Schlüssel. Das Skript liest diese Passwörter aus und speichert sie im System-Schlüsselbund.

* Speichere die Datei direkt im Ordner `sshconfig` auf dem Stick.
* Baue den Namen der Variable aus dem **Hostnamen** (aus dem JSON) und dem **Benutzernamen** zusammen.
* Trenne beide mit einem Unterstrich `_`.

**Muster:** `HOSTNAME_USER="Passphrase"`

**Beispiel:**
Wenn im JSON unter `host01` der User `userX` steht, sucht das Skript nach:

```bash
host01_userX="geheimesPasswort123"
```

für den Passphrase das File `keys/host01_userX`.

## `.zshrc` anpassen

Am Ende der Datei `~/.zshrc` einfügen:

```bash
# SSH Agent Socket Konfiguration
# Prüft, ob ein Socket existiert und setzt die Variable entsprechend.
# Priorität: 1. Neuer GCR-Standard (Arch, Debian Trixie)
#            2. Alter Keyring-Standard (Legacy)
if [ -n "$XDG_RUNTIME_DIR" ]; then
    if [ -S "$XDG_RUNTIME_DIR/gcr/ssh" ]; then
        export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/gcr/ssh"
    elif [ -S "$XDG_RUNTIME_DIR/keyring/ssh" ]; then
        export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/keyring/ssh"
    fi
fi
```

Terminal neu starten oder `source ~/.zshrc` eingeben.

## Skript anpassen

Skript `setup_ssh_connections.zsh` auf den Zielrechner kopieren. Darin die Zeilen am Anfang anpassen:

1. **Pfad zum Stick:**

    Prüfe, wo der Stick eingehängt (gemountet) ist.

    **Beispiel:**

    ```bash
     local stick="/run/media/user/stickname/sshconfig"
    ```

2. **JSON-Datei wählen:**

    Die passende Konfigurationsdatei für den **aktuellen** Rechner auswählen.

    ```bash
    # Beispiel für Rechner A:
    local json_file="${stick}/ssh_config_RechnerA.json"
    ```

## Ausführen

`try`-Modus, um Fehler zu finden, ohne etwas zu verändern.

### 1. Skript im Testlauf starten

Skript mit der Option `--try` ausführen:

```bash
./setup_ssh_connections.zsh --try
```

Das Skript zeigt an, was es tun würde (markiert mit `[TRY]`).

* Rote Fehlermeldungen (🔴).
* Fehler beheben (siehe unten).
* Testlauf wiederholen, bis alles grün (🟢) oder gelb (🟡) ist.
* Info Marker (🔵)

### 2. Skript starten

Wenn der Testlauf sauber durchläuft, starte das Skript ohne Option:

```bash
./setup_ssh_connections.zsh
```

## Probleme lösen 

**Beispiele:**

* **Fehler: "Kein Login Schlüsselbund gefunden"**
    * "Passwörter und Verschlüsselung" öffnen (Seahorse).
    * Schlüsselbund "Login" erstellen oder auswählen und zur "Vorgabe" (default) machen.

* **Fehler: "Keyring ist gesperrt!"**
    * Der Schlüsselbund ist abgeschlossen. Am Desktop entsperren.

* **Fehler: "SSH_AUTH_SOCK ist nicht gesetzt"**
    * Ist SSH_AUTH_SOCK in `.zshrc` gesetzt und geladen?

* **Fehler: "Dateien x y z nicht gefunden"**
    * Ist der Stick eingesteckt?
    * Liegen die Dateien mit Leserechten im Ordner `sshconfig` auf dem Stick?
    * Ist der Pfad zum USB-Stick im Skript (`local stick=...`) richtig eingetragen?
    * Ist die Konfiguration im Skript (`local json_file=...`) richtig eingetragen?
    * Ist die richtige Konfiguration ausgewählt?

