# Movie Files Inventarisierung und Metadata Tool

Inventarisierung, Metadaten-Anreicherung und Cover-Erstellung für lokale Videosammlungen. Die Tools sorgen für eine korrekte Darstellung in der Apple TV App (macOS/iPadOS).

## Voraussetzungen

  * **Betriebssystem:** macOS oder Linux
  * **Shell:** Zsh (Z Shell)
  * **Tools:**
      * `jq` (JSON-Verarbeitung)
      * `python3` (ab Version 3.9 empfohlen)
      * `ffmpeg` (inkl. `ffprobe`)
      * `atomicparsley` (Metadaten schreiben)
      * `imagemagick` (Cover erstellen)
  * **API-Zugriff:** Google AI Studio Key (Gemini) – *nur für `metadata.py` nötig*

## Installation

Installation der System-Abhängigkeiten:

**macOS (Homebrew):**

```bash
brew install jq python ffmpeg atomicparsley imagemagick
```

**Linux (Debian/Ubuntu/Arch):**

```bash
# Beispiel für Debian/Ubuntu
sudo apt install jq python3 ffmpeg atomicparsley imagemagick
```

Installation der Python-Bibliothek (nur für KI-Anreicherung):

```bash
pip install google-generativeai
```

## Empfohlener Workflow

Die Skripte bauen logisch aufeinander auf.

Für die **initiale Erfassung** oder eine vollständige Neubearbeitung aller Dateien wird folgende Reihenfolge empfohlen:

1.  **`tag.zsh`**: Extrahiert Basis-Informationen (Titel, Show, Staffel) aus dem Dateinamen und schreibt sie als Metadaten in die Datei.
2.  **`inventory.zsh`**: Liest die Metadaten aus den Dateien und legt neue Einträge in der JSON-Datenbank an.
3.  **`metadata.py`**: Analysiert die Datenbank und ergänzt fehlende Informationen (Jahr, Originaltitel, Darsteller) via KI.
4.  **`tag.zsh --force --db-only`**: Schreibt die nun vollständigten Daten mit Infos aus der Datenbank zurück in die Datei.
5.  **`cover.zsh`**: Generiert basierend auf den finalen Metadaten ein Cover und bettet es ein.

### Vorgehen bei neuen Dateien (Inkrementell)

Wenn nur einzelne Dateien hinzugekommen sind, wird die Verwendung von Filtern (Pipe-Methode) empfohlen, um zeitintensive Lese-/Schreibvorgänge auf der Festplatte zu minimieren.

**Beispiel (Neue Dateien "Tatort . Hinz..." und "Tatort . Kunz..." verarbeiten.):**

**1. Testlauf (Dry Run):**

```bash
# 1. Basis-Tags aus Dateinamen schreiben
print -l /Pfad/zu/Tatort*.(Hinz|Kunz)*.mp4 | ./tag.zsh --dry-run

# 2. In Datenbank aufnehmen
print -l /Pfad/zu/Tatort*.(Hinz|Kunz)*.mp4 | ./inventory.zsh --dry-run

# 3. KI-Daten ergänzen (nur für die übergebenen Dateien)
print -l /Pfad/zu/Tatort*.(Hinz|Kunz)*.mp4 | python metadata.py --dry-run

# 4. Angereicherte Daten (z.B. Jahr, Comment) in Datei schreiben
print -l /Pfad/zu/Tatort*.(Hinz|Kunz)*.mp4 | ./tag.zsh --dry-run --db-only --force

# 5. Cover erstellen
print -l /Pfad/zu/Tatort*.(Hinz|Kunz)*.mp4 | ./cover.zsh --dry-run --force
```

**2. Ausführung (Live):**

Wenn die Ausgaben korrekt erscheinen, `--dry-run` entfernen und die Befehle nacheinander ausführen.

### Workflow mit `process_movies()` zusammenfassen

```bash
process_movies() {
    local args="$@"
    local files=("${(@f)$(<&0)}")
    if (( ${#files} == 0 )); then 
        echo "Fehler: Keine Dateien übergeben."
        echo "Nutzung: print -l ... | process_movies [--dry-run]"
        return 1
    fi
    echo "Verarbeite ${#files} Dateien..."
    echo "\n=== SCHRITT 1: BASIS TAGS ==="
    print -l $files | ./tag.zsh $args || return 1
    echo "\n=== SCHRITT 2: INVENTAR ==="
    print -l $files | ./inventory.zsh $args || return 1
    echo "\n=== SCHRITT 3: KI METADATA ==="
    print -l $files | python metadata.py $args || return 1
    echo "\n=== SCHRITT 4: TAG UPDATE (DB) ==="
    print -l $files | ./tag.zsh $args --db-only --force || return 1
    echo "\n=== SCHRITT 5: COVER ==="
    print -l $files | ./cover.zsh $args --force || return 1
    echo "\n=== FERTIG ==="
}
```

**Beispiel (alle 'Tatort\*' Dateien, die in den letzten drei Tagen hinzu kamen):**

```bash
# Testlauf
print -l /Pfad/zu/Tatort*(.c-3) | process_movies --dry-run
# Ausführen
print -l /Pfad/zu/Tatort*(.c-3) | process_movies
```

## Verwendung der Zsh-Skripte

Die Skripte `tag.zsh`, `cover.zsh` und `inventory.zsh` unterstützen zwei Arbeitsmodi zur Dateiauswahl.

### Modi der Dateiauswahl

**A. Konfigurations-Modus (Aktuelles Verzeichnis)**
Das Skript wird ohne Dateipfade aufgerufen. Es verarbeitet alle Dateien im aktuellen Verzeichnis, die den Filtern im Skript entsprechen.

  * **Konfiguration:** Variablen `EXTENSIONS`, `INCLUDE_STR` und `EXCLUDE_STR` im Skriptkopf anpassen.
  * **Aufruf:** `./tag.zsh`

**B. Pipe-Modus (Gezielte Auswahl)**
Dateipfade werden über die Standardeingabe (stdin) übergeben. Dies ignoriert die Filter-Variablen im Skript.

  * **Aufruf:** `print -l /Pfad/zu/Dateien* | ./skript.zsh`

### Optionen

Alle Zsh-Skripte unterstützen folgende Argumente:

  * `--dry-run`: Simuliert den Vorgang und zeigt geplante Änderungen an (keine Schreibzugriffe).
  * `--force`: Erzwingt das Überschreiben bereits vorhandener Werte/Cover.

Das `tag.zsh` Skript unterstützt zudem das Flag `--db-only`

  * `--db-only` : Wenn es nicht gesetzt ist, werden die Basis-Informationen aus dem Dateinamen extrahiert. Wenn es gesetzt ist, werden Informationen aus der Datenbank gelesen.

-----

### 1\. Tags schreiben (`tag.zsh`)

Wenn `--db-only` _nicht_ gesetzt: analysiert Dateinamen anhand definierter Muster (z.B. "Artist - Show . Title") und schreibt iTunes-konforme Tags (Artist, Show, Staffel, Episode, Titel).

**Unterstützte Muster für Dateinamen:**

```
Artist - Show . Title_S_E_Total
Artist - Title_S_E_Total
Title_S_E_Total
Artist - Show . Title
Show . Title
Artist - Title
Title
```

Wenn `--db-only` gesetzt: liest Daten aus der Datenbank und schreibt iTunes-konforme Tags (Artist, Show, Staffel, Episode, Titel, Comment).

**Beispiel (Mehrere Dateien per Pipe testen):**

```zsh
print -l /Volumes/HD16/Movies/*Tatort*.mp4 | ./tag.zsh --dry-run
```

### 2\. Cover erstellen (`cover.zsh`)

Liest Titel und Artist aus den Metadaten der Datei, generiert mit ImageMagick ein Cover-Bild und bettet dieses ein.

**Beispiel (Einzelne Datei erzwingen):**

```zsh
print -l "/Volumes/HD16/Home Videos/Urlaub.mp4" | ./cover.zsh --force
```

**Ergebnis:**
Das generierte Cover sorgt für eine korrekte Darstellung in der TV App (macOS/iPadOS):

<table align="center">
  <tr>
  <td align="center">
    <img src="data/img/Screen04.png" height="300">
  </td>
  <td align="center">
    <img src="data/img/Screen03.png" height="300">
  </td>
  </tr>
  <tr>
  <td align="center">
    <img src="data/img/Screen01.png" height="300">
  </td>
  <td align="center">
    <img src="data/img/Screen02.png" height="300">
  </td>
  </tr>
</table>

### 3\. Inventar aktualisieren (`inventory.zsh`)

Liest die Metadaten (`ffprobe`) aus den Dateien und aktualisiert oder ergänzt die globale JSON-Datenbank (`filme_inventory.json`).

  * **Wichtig:** Setzt voraus, dass die Dateien bereits getaggt sind (z.B. durch `tag.zsh`).
  * Unterstützt globale Datenbanken: Einträge aus anderen Verzeichnissen bleiben erhalten.

-----

### 4\. KI-Anreicherung (`metadata.py`)

Analysiert Einträge in der JSON-Datei (`filme_inventory.json`), die unvollständig sind (z.B. fehlendes Jahr oder Originaltitel). Fragt fehlende Informationen (Jahr, Originaltitel, Regisseur, Hauptdarsteller) bei der Google Gemini API ab und ergänzt diese in der lokalen Datenbank.

#### Modi der Datenauswahl

Das Skript unterstützt zwei Methoden, um festzulegen, welche Einträge bearbeitet werden:

1.  **Pipe-Modus (Gezielt):**
    Werden Dateinamen per Pipe übergeben, sucht das Skript die passenden Einträge in der Datenbank (Matching über `filebasename`) und bearbeitet nur diese. Dies ist die **empfohlene Methode** für inkrementelle Updates.

      * *Aufruf:* `print -l *Tatort* | python metadata.py`

2.  **Automatik (Standard):**
    Ohne Pipe-Eingabe durchsucht das Skript das aktuelle Verzeichnis nach Videodateien, matcht diese gegen die Datenbank und bearbeitet Einträge, bei denen wichtige Daten fehlen.

      * *Konfiguration:* Die interne Logik für fehlende Daten kann in der Funktion `process_inventory` angepasst werden.
      * *Aufruf:* `python metadata.py`

#### Python-Umgebung (Empfohlen: pyenv)

Für eine saubere Ausführung wird die Nutzung einer virtuellen Umgebung via `pyenv` empfohlen.

```bash
# Installation (macOS)
brew install pyenv pyenv-virtualenv

# Setup (zshrc)
echo 'eval "$(pyenv init -)"' >> ~/.zshrc
echo 'eval "$(pyenv virtualenv-init -)"' >> ~/.zshrc
source ~/.zshrc

# Umgebung erstellen und aktivieren
pyenv install 3.12.1
pyenv virtualenv 3.12.1 movietags-env
pyenv local movietags-env

# Abhängigkeiten installieren
pip install google-generativeai
```

#### Verwendung

1.  **API-Key setzen:**
    ```bash
    export GEMINI_API_KEY="DEIN_GOOGLE_AI_KEY"
    ```
2.  **Ausführung (Dry Run):** Zeigt geplante Änderungen ohne API-Aufruf.
    ```bash
    # Gezielt für bestimmte Dateien (empfohlen)
    print -l /Pfad/zu/*Tatort* | python metadata.py --dry-run
    ```
3.  **Ausführung (Live):**
    ```bash
    python metadata.py
    ```
    *Option:* `--limit-batches 1` (Begrenzt auf den ersten Stapel zu 10 Filmen).

#### Ergebnis-Beispiel

Das Skript ergänzt automatisch fehlende Metadaten wie `jahr`, `titel.orig` und `darsteller`.

**Vorher (Ausgangsdaten aus `inventory.zsh`):**

```json
[
  {
    "nr": 1,
    "datei": ".../Alfred Hitchcock - Über den Dächern von Nizza.mp4",
    "artist": "Alfred Hitchcock",
    "titel": { "de": "Über den Dächern von Nizza", "orig": "" },
    "jahr": "",
    "darsteller": [ { "rolle": "", "actor": "" } ]
  }
]
```

**Nachher (Ergänzt durch `metadata.py`):**

```json
[
  {
    "nr": 1,
    "datei": ".../Alfred Hitchcock - Über den Dächern von Nizza.mp4",
    "artist": "Alfred Hitchcock",
    "titel": { "de": "Über den Dächern von Nizza", "orig": "To Catch a Thief" },
    "jahr": "1955",
    "darsteller": [
      { "rolle": "John Robie", "actor": "Cary Grant" },
      { "rolle": "Frances Stevens", "actor": "Grace Kelly" }
    ]
  }
]
```

## Dateistruktur

  * `tag.zsh`: Schreibt Metadaten aus Dateinamen.
  * `cover.zsh`: Generiert und bettet Cover-Bilder ein.
  * `inventory.zsh`: Aktualisiert die JSON-Datenbank basierend auf Datei-Metadaten.
  * `metadata.py`: Ergänzt fehlende Infos via KI.