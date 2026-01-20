# idkey – Einfaches Bestimmungsschlüssel Tool

CLI-Tool auf `zsh` Basis für das Einlesen und Anfragen eines **dichotomische Bestimmungsschlüssels**. Es werden Schritt für Schritt eine Reihe von Entscheidungsfragen durchlaufen, die in einer JSON-Datei hinterlegt sind.

## Repo

```bash
├── identify.zsh            → Das Tool / Skript (benötigt `zsh` und `jq`).
├── keys                    → Ordner für die Bestimmungsdaten im JSON-Format.
│   └── Chrysotoxum.json    → Beispiel Schlüssel für Chrysotoxum Arten (DE).
└── README.md
```

## Verwendung

```zsh
chmod +x identify.zsh
./identify.zsh
```

## JSON-Format

Die Schlüssel sind als Baumstruktur aufgebaut. Jeder Schritt (`step`) bietet zwei Optionen, die entweder auf einen weiteren Schritt oder auf ein finales Ergebnis (die Art) verweisen:

```json
{
  "metadata": {
    "title": "Name des Schlüssels",
    "parent_key": "Optionaler_Ueberschluessel.json"
  },
  "steps": {
    "1": {
      "frage": "Merkmalbeschreibung...",
      "option_1": "Eigenschaft A",
      "ziel_1": "2",
      "option_2": "Eigenschaft B",
      "ziel_2": "Artname"
    }
  }
}
```

## Voraussetzungen
* **zsh** (getestet unter v5.9)
* **jq** (für das Parsen der JSON-Daten)