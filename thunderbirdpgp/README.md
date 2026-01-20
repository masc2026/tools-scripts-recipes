# Thunderbird - OpenPGP Digitally Sign 
Note: Created with ChatGPT, 2025

---

1. **A:** `Security → Digitally Sign This Message` *(pro Nachricht)*
2. **B:** `Attach my public key when adding an OpenPGP digital signature` *(Einstellungen → OpenPGP)*
3. **C:** `Send OpenPGP public key(s) in the email headers for compatibility with Autocrypt` *(Einstellungen → OpenPGP)*
4. **D:** `Attach "My Open Public key"` *(Häkchen direkt im Verfassen-Fenster, unabhängig von Signatur)*

---

## 📋 Tabelle: Kombinationen & Auswirkungen

| Nr. | Signieren (A) | Attach bei Signatur (B) | Autocrypt-Header (C) | Manuell Public Key anhängen (D) | **Was passiert beim Senden**                                                                      | **Was sieht der Empfänger**                                                     |
| --: | :-----------: | :---------------------: | :------------------: | :-----------------------------: | ------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
|   1 |       ❌       |            ❌            |           ❌          |                ❌                | Normale unverschlüsselte Mail, keine Signatur, kein Key                                           | Normale Mail                                                                    |
|   2 |       ✅       |            ❌            |           ❌          |                ❌                | Mail wird PGP-signiert, **kein** Public Key angehängt, kein Autocrypt                             | Kann Signatur prüfen **nur wenn** Key schon bekannt                             |
|   3 |       ✅       |            ✅            |           ❌          |                ❌                | Mail wird PGP-signiert **und** `.asc`-Anhang mit Public Key beigefügt                             | Sieht Anhang `openpgpkey.asc`, kann Key manuell importieren                     |
|   4 |       ✅       |            ❌            |           ✅          |                ❌                | Mail wird PGP-signiert, Public Key steckt **nur** im `Autocrypt:`-Header                          | Autocrypt-fähige Clients importieren Key automatisch, andere sehen nichts extra |
|   5 |       ✅       |            ✅            |           ✅          |                ❌                | Mail wird PGP-signiert, `.asc`-Anhang **und** Autocrypt-Header                                    | Maximale Kompatibilität – Key für alle verfügbar                                |
|   6 |       ❌       |            ❌            |           ❌          |                ✅                | Normale Mail **mit** `.asc`-Key-Anhang                                                            | Kein Signatur-Check, Key kann importiert werden                                 |
|   7 |       ❌       |            ❌            |           ✅          |                ✅                | Normale Mail, `.asc`-Key-Anhang **und** Autocrypt-Header                                          | Key sowohl manuell als auch automatisch importierbar                            |
|   8 |       ❌       |            ❌            |           ✅          |                ❌                | Normale Mail, nur Autocrypt-Header                                                                | Key nur für Autocrypt-Clients automatisch verfügbar                             |
|   9 |       ✅       |            ❌            |           ✅          |                ✅                | Mail signiert, Autocrypt-Header **und** extra `.asc`-Anhang (manuell angehängt, unabhängig von B) | Key doppelt vorhanden                                                           |
|  10 |       ✅       |            ✅            |           ❌          |                ✅                | Mail signiert, `.asc`-Anhang aus Signatur-Option **und** manuell (doppelt identisch)              | Empfänger sieht Key zweimal                                                     |
|  11 |       ❌       |            ✅            |           ❌          |                ❌                | **B hat keine Wirkung ohne A** → nur normale Mail                                                 | Normale Mail                                                                    |

---

### 🔹 Zusammengefasst

* **B** funktioniert nur, wenn **A** aktiv ist (digitale Signatur).
* **C** hängt den Key *unsichtbar* in den Header (`Autocrypt:`), unabhängig vom Anhang.
* **D** fügt den `.asc`-Anhang immer hinzu, egal ob die Mail signiert ist oder nicht.
* Wenn du maximale Erreichbarkeit willst: **A + B + C** einschalten → signiert + Anhang + Autocrypt.
