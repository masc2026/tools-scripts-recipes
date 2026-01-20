### Lokales Repo erstellen und mit `gh` per HTTPS pushen

Dieser Ablauf beschreibt, wie du ein neues Verzeichnis als Git-Repository initialisierst, es auf GitHub erstellst und es sicher per HTTPS (statt SSH) hochlädst.

### Voraussetzungen

Bevor du startest, stelle sicher, dass:

1.  **`gh` authentifiziert ist:** Du musst in der GitHub CLI eingeloggt sein.
      * *Test-Befehl:* `gh auth status` (sollte "Logged in to github.com" anzeigen)
2.  **Git konfiguriert ist:** Dein lokales Git muss deinen Benutzernamen und deine E-Mail-Adresse kennen, damit deine Commits korrekt zugeordnet werden.
      * *Test-Befehl:* `git config --global user.name` und `git config --global user.email`
3.  **HTTPS-Nutzung:** Dieser Workflow ist für die HTTPS-Authentifizierung ausgelegt (die `gh` automatisch verwaltet), da bei dir der SSH-Schlüssel-Abgleich fehlgeschlagen ist.

-----

### Schritte

Angenommene Ausgangslage: Du bist im Terminal und dein Verzeichnis heißt `mein-neues-repo`.

**1. Lokales Git-Repository initialisieren**

Erstelle das Repo und setze den Standard-Branch direkt auf `main` (statt `master`):

```bash
git init -b main
```

**2. Alle Dateien hinzufügen**

Füge alle deine Skripte, READMEs usw. zum Git-Tracking hinzu:

```bash
git add .
```

**3. Ersten Commit erstellen**

Erstelle den ersten Commit mit deinen hinzugefügten Dateien:

```bash
git commit -m "Initial commit"
```

**4. GitHub-Repo erstellen (OHNE Push)**

Jetzt nutzt du `gh`, um das Repo auf GitHub zu erstellen. Wir lassen das `--push`-Flag bewusst weg, da `gh` standardmäßig ein SSH-Remote einrichten könnte, was fehlschlägt.

```bash
gh repo create mein-neues-repo --public --source=. --remote=origin
```

  * **Was passiert hier?** `gh` erstellt das Repo auf GitHub und fügt deinem lokalen Repo ein "remote" namens `origin` hinzu, das (in deinem Fall) auf die SSH-Adresse (`git@github.com:...`) zeigt.

**5. Remote-URL auf HTTPS korrigieren (Der wichtige Schritt)**

Da `origin` die falsche (SSH) Adresse hat, ändern wir sie manuell auf die HTTPS-Adresse. `git` wird für diese Adresse die Anmeldedaten von `gh` (das Token) verwenden.

```bash
git remote set-url origin https://github.com/masc2026/mein-neues-repo.git
```

**6. Manuell per HTTPS pushen**

Jetzt, da `origin` auf die korrekte HTTPS-URL zeigt, kannst du sicher pushen:

```bash
git push -u origin main
```

Das `-u` (oder `--set-upstream`) sorgt dafür, dass dein lokaler `main`-Branch ab sofort mit `origin/main` verbunden ist.