## 🛠 Ausgangssituation (vor dem Merge)

```
(master)   o---o---o
                 \
(feature-x)       f1---f2
```

* `o` = Commits auf `master`
* `f1`, `f2` = Commits im Feature‑Branch
* Beide Branches existieren lokal und auf GitHub (`origin/master`, `origin/feature-x`)

---

## 1️⃣ Merge Commit (GitHub‑Standard)

**Merge‑Befehl:**

```bash
# Lokal vor PR:
git checkout master
git pull origin master
git merge feature-x
git push origin master
```

**GitHub PR:** „Merge pull request“ (Create a merge commit)

**Ergebnis:**

```
(master)   o---o---o-------M
                 \       /
(feature-x)       f1---f2
```

* `M` = Merge Commit mit zwei Eltern (`o` und `f2`)
* Lokal nach Merge:

```bash
git checkout master
git pull origin master
git branch -d feature-x
git push origin --delete feature-x
```

---

## 2️⃣ Rebase + Fast‑Forward Merge

**Lokal vor PR:**

```bash
git fetch origin
git checkout feature-x
git rebase origin/master
git push origin feature-x --force-with-lease
```

**GitHub PR:** „Rebase and merge“ (oder lokal `merge --ff-only`)

**Ergebnis:**

```
(master)   o---o---o---f1'---f2'
```

* `f1'`, `f2'` = neue Commits (Hashes geändert durch Rebase)
* Lokal nach Merge:

```bash
git checkout master
git pull origin master
git branch -d feature-x
git push origin --delete feature-x
```

---

## 3️⃣ Squash Merge

**Lokal vor PR:**

```bash
git push origin feature-x
```

**GitHub PR:** „Squash and merge“ → GitHub erstellt einen einzelnen Commit `F`

**Ergebnis:**

```
(master)   o---o---o---F
(feature-x)       f1---f2
```

* `F` = ein einziger Commit mit allen Änderungen aus `f1` und `f2`
* Lokal nach Merge:

```bash
git checkout master
git pull origin master
git branch -d feature-x
git push origin --delete feature-x
```

---

## 📊 Vergleich

| Strategie    | History linear? | Alle Feature-Commits behalten? | Geeignet für                              |
| ------------ | --------------- | ------------------------------ | ----------------------------------------- |
| Merge Commit | ❌ Nein          | ✅ Ja                           | große Teams, volle Historie               |
| Rebase + FF  | ✅ Ja            | ✅ Ja (aber Hashes neu)         | saubere Historie, eigene Branches         |
| Squash Merge | ✅ Ja            | ❌ Nein (nur 1 Commit)          | kleine Features, aufgeräumte Haupt-Branch |

