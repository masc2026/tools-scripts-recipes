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
  * **API-Zugriff:** Google AI Studio Key (Gemini) – *nur für `enrich_metadata.py` nötig*

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

### 4\. KI-Anreicherung (`enrich_metadata.py`)

*Optional.* Analysiert Einträge in der JSON-Datei, die noch keine Titel-Informationen haben, und fragt diese bei der Google Gemini API ab.

  * **Vorbereitung:** `export GEMINI_API_KEY="KEY"`
  * **Aufruf:** `python enrich_metadata.py`

## Dateistruktur

  * `data/`: Speicherort der Inventar-Dateien.
  * `tag.zsh`: Schreibt Metadaten aus Dateinamen.
  * `cover.zsh`: Generiert und bettet Cover-Bilder ein.
  * `inventory.zsh`: Aktualisiert die JSON-Datenbank basierend auf Datei-Metadaten.
  * `enrich_metadata.py`: Ergänzt fehlende Infos via KI.