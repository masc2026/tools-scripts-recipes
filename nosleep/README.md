# NoSleep Utility

Tool, das den Ruhezustand (Sleep/Idle) auf Linux (Arch, Debian) und macOS verhindert.

## 1. Shell-Funktion (.zshrc)

In `~/.zshrc` einfügen:

```bash
# nosleep: Verhindert den Ruhezustand des Systems
nosleep () {
    local lf=/tmp/nosleep.pid
    
    # Betriebssystem-Erkennung
    local is_mac=false
    [[ "$OSTYPE" == "darwin"* ]] && is_mac=true

    case "$1" in
        (start) 
            if [[ -f $lf ]] && kill -0 $(cat $lf) 2> /dev/null; then
                echo "Läuft bereits (PID $(cat $lf))"
                return
            fi
            
            if [ "$is_mac" = true ]; then
                # macOS: Verwendet caffeinate (i=idle, m=disk, s=system)
                nohup caffeinate -ims > /dev/null 2>&1 &
            else
                # Linux: Verwendet systemd-inhibit
                #
                # nohup            : Befehl läuft weiter, auch wenn das Terminal oder SSH schließt.
                # systemd-inhibit  : Verhindert den Ruhezustand des Systems.
                # sleep infinity   : Platzhalter-Befehl, der dauerhaft läuft und die Sperre aktiv hält.
                # > /dev/null 2>&1 : Versteckt alle Text- und Fehlerausgaben.
                # & (am Ende)      : Als job in den Hintergrund schicken.
                nohup systemd-inhibit --what=sleep:idle --why="SSH session active" sleep infinity > /dev/null 2>&1 &
            fi
            
            echo $! > $lf
            echo "nosleep gestartet (PID $!)"
            ;;
        (stop) 
            if [[ -f $lf ]]; then
                kill $(cat $lf) 2> /dev/null && echo "nosleep beendet"
                rm -f $lf
            else
                echo "Kein aktiver nosleep-Prozess gefunden."
            fi
            ;;
        (status) 
            if [[ -f $lf ]] && kill -0 $(cat $lf) 2> /dev/null; then
                echo "Aktiv (PID $(cat $lf))"
            else
                echo "Nicht aktiv"
            fi
            ;;
        (*) 
            echo "Benutzung: nosleep {start|stop|status}" 
            ;;
    esac
}
```

## 2. Polkit-Regel (Nur für Linux)

Polkit-Regel damit `systemd-inhibit` auf Arch oder Debian ohne Passwortabfrage funktioniert:

1. Datei erstellen:
   ```bash
   sudo nano /etc/polkit-1/rules.d/10-nosleep.rules
   ```

2. Inhalt einfügen:
   ```javascript
   polkit.addRule(function(action, subject) {
       if (action.id == "org.freedesktop.login1.inhibit-block-sleep" &&
           subject.user == "<user>") {
           return polkit.Result.YES;
       }
   });
   ```

## 3. Usage

`.zshrc` neu laden (`source ~/.zshrc`):

- **Starten:** `nosleep start`
- **Beenden:** `nosleep stop`
- **Status prüfen:** `nosleep status`
