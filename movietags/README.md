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

Die Skripte bauen logisch aufeinander auf. Es wird folgende Reihenfolge empfohlen:

1.  **`tag.zsh`**: Extrahiert Informationen aus dem Dateinamen und schreibt sie als Metadaten in die Datei.
2.  **`cover.zsh`**: Generiert basierend auf den (in Schritt 1 gesetzten) Metadaten ein Cover und bettet es ein.
3.  **`inventory.zsh`**: Liest die fertigen Metadaten aus den Dateien und aktualisiert die JSON-Datenbank.

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

-----

### 1\. Tags schreiben (`tag.zsh`)

Analysiert Dateinamen anhand definierter Muster (z.B. "Artist - Show . Title") und schreibt iTunes-konforme Tags (Artist, Show, Staffel, Episode, Titel).

**Unterstützte Muster für Dateinamen:**

    Artist - Show . Title_S_E_Total

    Artist - Title_S_E_Total

    Title_S_E_Total

    Artist - Show . Title

    Show . Title

    Artist - Title

    Title

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

#### Filterung der zu bearbeitenden Einträge

Das Skript `metadata.py` enthält die interne Funktion `filter_condition` (innerhalb von `process_inventory`), mit der die Auswahl der zu bearbeitenden Datensätze gezielt eingeschränkt werden kann.

* **Standard:** Es werden alle Einträge bearbeitet, die den Kriterien entsprechen.
* **Anpassung:** Durch Änderung des Quellcodes in dieser Funktion können spezifische Filter definiert werden (z. B. nur Einträge mit `show == "Tatort"` oder `artist` enthält "Hitchcock"). Dies ermöglicht das selektive Aktualisieren bestimmter Teile der Sammlung.

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
    python metadata.py --dry-run
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