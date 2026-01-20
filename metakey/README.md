# macOS-Style Keybindings für Linux (keyd)

Emulation des macOS-Tastaturlayouts (Command-Taste für Copy/Paste) auf Linux mit `keyd` für die Shortcuts.

## Setup

### Arch Linux

```bash
sudo pacman -S keyd evtest libinput
```

### Debian (Trixie)

```bash
sudo apt update
sudo apt install keyd evtest libinput-bin
```

## Konfiguration

1. **Datei kopieren**:
Kopieren der bereitgestellten Konfiguration in das Systemverzeichnis:
```bash
sudo cp ./keyd/default.conf /etc/keyd/default.conf
```

2. **Dienst aktivieren**:
Starten und Aktivieren des Hintergrunddienstes:
```bash
sudo systemctl enable --now keyd
```

3. **GNOME-Interferenzen beheben**:
Deaktivieren der Windows-Taste (Overlay-Key) in GNOME, damit sie für `keyd` frei wird:
```bash
gsettings set org.gnome.mutter overlay-key ''
```

## Diagnose und Fehlerbehebung

### Signale prüfen

Falls Tasten nicht reagieren, Input-Events test. **Wichtig:** Vorher den `keyd`-Dienst stoppen, da dieser die Signale exklusiv abfängt.

```bash
sudo systemctl stop keyd
sudo evtest
```

Wähle in `evtest` die Tastatur aus (z. B. "Cherry GmbH" oder "Apple Internal Keyboard"). Beim Drücken der Windows-/Command-Taste muss `KEY_LEFTMETA` erscheinen.

Danach Dienst wieder starten:

```bash
sudo systemctl start keyd
```

#### Beispiel: Apple MacBook Air 2020 mit `arch`:

```text
No device specified, trying to scan all of /dev/input/event*
Available devices:
...
/dev/input/event12:	Apple Inc. Apple Internal Keyboard / Trackpad
...
Select the device event number [0-13]: 12
Input driver version is 1.0.1
Input device ID: bus 0x3 vendor 0x5ac product 0x280 version 0x101
Input device name: "Apple Inc. Apple Internal Keyboard / Trackpad"
Supported events:
  Event type 0 (EV_SYN)
  Event type 1 (EV_KEY)
    Event code 1 (KEY_ESC)
...
    Event code 464 (KEY_FN)
  Event type 4 (EV_MSC)
    Event code 4 (MSC_SCAN)
  Event type 17 (EV_LED)
    Event code 0 (LED_NUML) state 0
...
    Event code 4 (LED_KANA) state 0
Key repeat handling:
  Repeat type 20 (EV_REP)
    Repeat code 0 (REP_DELAY)
      Value    250
    Repeat code 1 (REP_PERIOD)
      Value     33
Properties:
Testing ... (interrupt to exit)
...
Event: time 1770444032.596241, type 4 (EV_MSC), code 4 (MSC_SCAN), value 700e3
Event: time 1770444032.596241, type 1 (EV_KEY), code 125 (KEY_LEFTMETA), value 1
...
Event: time 1770444034.887908, type 4 (EV_MSC), code 4 (MSC_SCAN), value 700e7
Event: time 1770444034.887908, type 1 (EV_KEY), code 126 (KEY_RIGHTMETA), value 1
...
```

#### Beispiel: Apple MacBook Pro 2015 mit `debian`:

```text
No device specified, trying to scan all of /dev/input/event*
Available devices:
...
/dev/input/event7:	Apple Inc. Apple Internal Keyboard / Trackpad
...
Select the device event number [0-15]: 7
Input driver version is 1.0.1
Input device ID: bus 0x3 vendor 0x5ac product 0x273 version 0x110
Input device name: "Apple Inc. Apple Internal Keyboard / Trackpad"
Supported events:
  Event type 0 (EV_SYN)
  Event type 1 (EV_KEY)
    Event code 1 (KEY_ESC)
...
    Event code 464 (KEY_FN)
  Event type 4 (EV_MSC)
    Event code 4 (MSC_SCAN)
  Event type 17 (EV_LED)
    Event code 0 (LED_NUML) state 0
...
    Event code 4 (LED_KANA) state 0
Key repeat handling:
  Repeat type 20 (EV_REP)
    Repeat code 0 (REP_DELAY)
      Value    250
    Repeat code 1 (REP_PERIOD)
      Value     33
Properties:
Testing ... (interrupt to exit)
...
Event: time 1767683962.879406, type 4 (EV_MSC), code 4 (MSC_SCAN), value 700e3
Event: time 1767683962.879406, type 1 (EV_KEY), code 125 (KEY_LEFTMETA), value 1
...
Event: time 1767683962.975414, type 4 (EV_MSC), code 4 (MSC_SCAN), value 700e3
Event: time 1767683962.975414, type 1 (EV_KEY), code 125 (KEY_LEFTMETA), value 0
...
```

#### Beispiel: PC Hardware mit `arch`:

```text
No device specified, trying to scan all of /dev/input/event*
Available devices:
...
/dev/input/event2:	Cherry GmbH CHERRY Corded Device
...
Select the device event number [0-15]: 2
Input driver version is 1.0.1
Input device ID: bus 0x3 vendor 0x46a product 0xc098 version 0x111
Input device name: "Cherry GmbH CHERRY Corded Device"
Supported events:
  Event type 0 (EV_SYN)
  Event type 1 (EV_KEY)
    Event code 1 (KEY_ESC)
...
    Event code 240 (KEY_UNKNOWN)
  Event type 4 (EV_MSC)
    Event code 4 (MSC_SCAN)
  Event type 17 (EV_LED)
    Event code 0 (LED_NUML) state 0
    Event code 1 (LED_CAPSL) state 0
    Event code 2 (LED_SCROLLL) state 0
Key repeat handling:
  Repeat type 20 (EV_REP)
    Repeat code 0 (REP_DELAY)
      Value    250
    Repeat code 1 (REP_PERIOD)
      Value     33
Properties:
Testing ... (interrupt to exit)
...
...
Event: time 1767684113.769284, type 4 (EV_MSC), code 4 (MSC_SCAN), value 700e3
Event: time 1767684113.769284, type 1 (EV_KEY), code 125 (KEY_LEFTMETA), value 1
...
Event: time 1767684113.841605, type 4 (EV_MSC), code 4 (MSC_SCAN), value 700e3
Event: time 1767684113.841605, type 1 (EV_KEY), code 125 (KEY_LEFTMETA), value 0
...
```

### Nur IDs finden

ID für die Sektion `[ids]` mit `lsusb` (funktioniert auch mit MacBook interner Tastatur):

```bash
lsusb
```

Die ID (z. B. `046a:c098`) kann in die `/etc/keyd/default.conf` eingetragen werden.

### `keyd` Monitor

Prüfen ob `keyd` was verarbeitet:

```bash
sudo keyd monitor
```

Zeigt an, welche Taste gedrückt und in welchen Befehl (z. B. `C-insert`) es übersetzt wird.

Erwartete Eventfolge für `Win+C` (`⌘C` bzw. `<Super>c`) Drücken und Loslassen:

```bash
keyd virtual keyboard ... leftcontrol down
keyd virtual keyboard ... insert down
keyd virtual keyboard ... insert up
```

Erwartete Eventfolge für `Win+V` (`⌘V` bzw. `<Super>v`) Drücken und Loslassen:

```bash
keyd virtual keyboard ... leftcontrol down
keyd virtual keyboard ... leftshift down
keyd virtual keyboard ... leftcontrol up
keyd virtual keyboard ... insert down
keyd virtual keyboard ... insert up
keyd virtual keyboard ... leftshift up
keyd virtual keyboard ... leftcontrol down
keyd virtual keyboard ... leftcontrol up
```

