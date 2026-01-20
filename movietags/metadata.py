import json
import os
import time
import argparse
import sys
import google.generativeai as genai
from google.generativeai.types import GenerationConfig

# --- KONFIGURATION ---
API_KEY = os.environ.get("GEMINI_API_KEY", "DEIN_KEY_HIER") 
INVENTORY_FILE = os.path.expanduser("~/Projekte/gitrepos/tools-scripts-recipes/movietags/filme_inventory.json")
CHUNK_SIZE = 10 
MODEL_NAME = 'gemini-2.5-flash'

# Dateiendungen, die im lokalen Modus berücksichtigt werden
VALID_EXTENSIONS = ('.mp4', '.m4v', '.mov', '.mpeg', '.mkv', '.avi')

def configure_genai():
    if not API_KEY or "DEIN_KEY" in API_KEY:
        print("Fehler: Kein gültiger API Key gefunden.")
        sys.exit(1)
    genai.configure(api_key=API_KEY)
    return genai.GenerativeModel(MODEL_NAME)

def load_inventory():
    if not os.path.exists(INVENTORY_FILE):
        print(f"Fehler: Datei {INVENTORY_FILE} nicht gefunden.")
        sys.exit(1)
    with open(INVENTORY_FILE, 'r', encoding='utf-8') as f:
        return json.load(f)

def save_inventory(data):
    temp_file = INVENTORY_FILE + ".tmp"
    with open(temp_file, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    os.replace(temp_file, INVENTORY_FILE)

def get_target_files():
    """Ermittelt die zu bearbeitenden Dateinamen (Pipe oder Lokal)."""
    target_files = []
    
    # FALL A: Pipe Input
    if not sys.stdin.isatty():
        print("Modus: Pipe Input")
        for line in sys.stdin:
            line = line.strip()
            if line:
                target_files.append(os.path.basename(line))
                
    # FALL B: Lokales Verzeichnis (wenn keine Pipe)
    else:
        print("Modus: Aktuelles Verzeichnis (Scan)")
        try:
            for f in os.listdir('.'):
                if os.path.isfile(f) and f.lower().endswith(VALID_EXTENSIONS):
                    target_files.append(f)
        except OSError as e:
            print(f"Fehler beim Scannen des Verzeichnisses: {e}")
            
    return target_files

def build_prompt(movies_chunk):
    schema_example = """
    [
      {
        "nr": 123,
        "titel": { "de": "Deutscher Titel", "orig": "Originaltitel" },
        "regisseur": { "name": "Vorname Nachname" },
        "jahr": "1999",
        "darsteller": [
          { "rolle": "Rollenname", "actor": "Schauspieler Name" },
          { "rolle": "Rollenname", "actor": "Schauspieler Name" }
        ]
      }
    ]
    """

    prompt = f"""
    AUFGABE:
    Analysiere die folgende Liste von Videodateien. Ergänze fehlende Metadaten basierend auf 'titel.de', 'jahr', 'artist' und deinem Wissen.
    Du kannst Tools (Google Suche) nutzen, wenn du Informationen wie das Jahr oder den Originaltitel nicht weißt.

    REGELN:
    1. Ergänze fehlende Felder: titel.orig, regisseur.name, jahr (String), darsteller (2-3 Hauptrollen).
    2. Verändere NIEMALS die 'nr'.
    3. Gib NIEMALS Markdown-Formatierung (```json) aus, sondern nur den reinen JSON-String.

    AUSGABEFORMAT:
    Antworte ausschließlich mit einer JSON-Liste in diesem Format:
    {schema_example}

    EINGABEDATEN:
    """
    prompt += json.dumps(movies_chunk, ensure_ascii=False)
    return prompt

def process_inventory(dry_run=False, force=False, limit_batches=0):
    # 1. ZIELE BESTIMMEN
    target_basenames = get_target_files()
    
    if not target_basenames:
        print("Keine Dateien gefunden (weder über Pipe noch im Ordner).")
        return

    print(f"Gefundene Dateien (Input): {len(target_basenames)}")

    # 2. DATENBANK LADEN
    model = None
    if not dry_run:
        model = configure_genai()
    
    data = load_inventory()
    
    # 3. ABGLEICH & FILTERUNG
    target_set = set(target_basenames)
    todos = []
    
    for m in data:
        if m.get('filebasename') in target_set:
            missing_year = not m.get('jahr')
            missing_orig = not m.get('titel', {}).get('orig')
            missing_cast = not m.get('darsteller')
            
            if force or missing_year or missing_orig or missing_cast:
                todos.append(m)
    
    todos.sort(key=lambda x: x['nr'])
    
    print(f"Bestand DB gesamt: {len(data)}")
    print(f"Davon zu bearbeiten: {len(todos)}")
    
    if not todos:
        print("Nichts zu tun.")
        return

    if dry_run:
        print("\n--- DRY RUN MODUS AKTIV ---")
    else:
        print(f"Verwendetes Modell: {MODEL_NAME}")

    processed_batches = 0

    # Config für JSON Output
    generation_config = GenerationConfig(
        response_mime_type="application/json"
    )

    for i in range(0, len(todos), CHUNK_SIZE):
        if limit_batches > 0 and processed_batches >= limit_batches:
            print(f"\nLimit von {limit_batches} Batches erreicht. Beende.")
            break

        chunk = todos[i:i + CHUNK_SIZE]
        current_batch_num = int(i/CHUNK_SIZE) + 1
        
        start_nr = chunk[0]['nr']
        end_nr = chunk[-1]['nr']
        print(f"Bearbeite Batch {current_batch_num} (Nr. {start_nr} bis {end_nr})...")

        mini_chunk = []
        for movie in chunk:
            mini_chunk.append({
                "nr": movie['nr'],
                "filebasename": movie['filebasename'],
                "jahr": movie.get('jahr', ""),
                "artist": movie.get('artist', ""),
                "show": movie.get('show', ""),
                "titel": movie.get('titel', {"de": "", "orig": ""})
            })

        # Prompt bauen (Text-basiert)
        prompt = build_prompt(mini_chunk)

        if dry_run:
            print(f"[DRY-RUN] Batch {current_batch_num} Payload OK.")
            processed_batches += 1
            continue 

        try:
            response = model.generate_content(prompt, generation_config=generation_config)
            
            # Parsing-Versuch mit Fallback
            try:
                enriched_data = json.loads(response.text)
            except Exception as parse_err:
                print(f"  Warnung: Parsing fehlgeschlagen ({parse_err}). Versuche Cleaning...")
                # Manchmal liefert das Modell Markdown trotz Verbot
                clean_text = response.text.replace("```json", "").replace("```", "").strip()
                enriched_data = json.loads(clean_text)

            updates_count = 0
            for enriched_item in enriched_data:
                original = next((x for x in data if x['nr'] == enriched_item['nr']), None)
                if original:
                    original['titel'] = enriched_item.get('titel', original['titel'])
                    original['jahr'] = enriched_item.get('jahr', original.get('jahr', ''))
                    original['darsteller'] = enriched_item.get('darsteller', original.get('darsteller', []))
                    
                    # Robuste Regisseur Übernahme
                    raw_dir = enriched_item.get('regisseur', {}).get('name', '')
                    new_director = ""
                    if isinstance(raw_dir, dict):
                        new_director = raw_dir.get('name', '')
                    elif isinstance(raw_dir, str) and raw_dir.strip().startswith('{'):
                         try: new_director = json.loads(raw_dir).get('name', '')
                         except: new_director = raw_dir
                    else:
                        new_director = raw_dir

                    if new_director:
                        if 'regisseur' not in original: original['regisseur'] = {}
                        original['regisseur']['name'] = new_director
                        # Artist nur setzen wenn leer
                        if not original.get('artist'):
                            original['artist'] = new_director

                    updates_count += 1
            
            print(f"  -> {updates_count} Filme aktualisiert.")
            save_inventory(data)
            time.sleep(1) 

        except Exception as e:
            error_msg = str(e)
            print(f"  ERROR: {error_msg}")
            # Nur bei echten 404/Auth Fehlern abbrechen
            if "404" in error_msg or "not found" in error_msg.lower() or "API_KEY" in error_msg:
                print("\nFATALER FEHLER: Modell oder Key ungültig.")
                sys.exit(1)
            
        finally:
            processed_batches += 1

    print("Vorgang abgeschlossen.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--limit-batches", type=int, default=0)
    args = parser.parse_args()
    
    process_inventory(dry_run=args.dry_run, force=args.force, limit_batches=args.limit_batches)