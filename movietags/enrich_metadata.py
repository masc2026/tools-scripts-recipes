import json
import os
import time
import argparse
import sys
import google.generativeai as genai
from google.generativeai.types import GenerationConfig

# --- KONFIGURATION ---
API_KEY = os.environ.get("GEMINI_API_KEY", "DEIN_KEY_HIER") 
INVENTORY_FILE = "filme_inventory.json"
CHUNK_SIZE = 10 

# HIER haben wir dein verfügbares Modell eingetragen:
MODEL_NAME = 'gemini-2.5-flash'

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

def build_prompt(movies_chunk):
    prompt = """
    Du bist ein Experte für Filmdatenbanken. Deine Aufgabe ist es, Metadaten für Videodateien zu ergänzen.
    
    Ich gebe dir eine JSON-Liste mit 'nr', 'filebasename' und teilweise gefüllten Daten.
    Deine Aufgabe:
    1. Analysiere den 'filebasename' (Manchmal ist dort auch der Namen des Regisseurs oder Information zur Serie enthalten, du kannst es als Zusatzinfo verwenden. Ignoriere Dinge wie '1080p', 'HD', Nummern am Anfang).
    2. Identifiziere den Film.
    3. Ergänze fehlende Daten für:
       - titel.de (Deutscher Titel)
       - titel.orig (Originaltitel)
       - regisseur (vorname, nachname, geburtsjahr als String)
    
    WICHTIG:
    - Verändere NICHT die 'nr'. Das ist der Schlüssel.
    - Wenn du den Film absolut nicht identifizieren kannst, lasse die Felder leer ("").
    - Erfinde KEINE Daten.
    - Antworte NUR mit dem validen JSON Array, kein Markdown, kein Text davor/danach.
    
    Hier sind die Filme:
    """
    prompt += json.dumps(movies_chunk, ensure_ascii=False)
    return prompt

def process_inventory(dry_run=False, limit_batches=0):
    model = None
    if not dry_run:
        model = configure_genai()
    
    data = load_inventory()
    
    # Filter: Nur Filme ohne deutschen Titel bearbeiten
    todos = [m for m in data if m['titel']['de'] == ""]
    
    # --- NEU: SORTIERUNG EINFÜGEN ---
    todos.sort(key=lambda x: x['nr'])
    # --------------------------------
    
    print(f"Bestand: {len(data)} Filme. Zu bearbeiten: {len(todos)}")
    print(f"Verwendetes Modell: {MODEL_NAME}")
    
    if dry_run:
        print("\n--- DRY RUN MODUS AKTIV ---")

    if not todos:
        print("Alles erledigt.")
        return

    processed_batches = 0

    for i in range(0, len(todos), CHUNK_SIZE):
        # LIMIT CHECK
        if limit_batches > 0 and processed_batches >= limit_batches:
            print(f"\nLimit von {limit_batches} Batches erreicht. Beende.")
            break

        chunk = todos[i:i + CHUNK_SIZE]
        current_batch_num = int(i/CHUNK_SIZE) + 1
        
        # Kleine kosmetische Verbesserung: Zeige Start/Ende NR im Log an
        start_nr = chunk[0]['nr']
        end_nr = chunk[-1]['nr']
        print(f"Bearbeite Batch {current_batch_num} (Nr. {start_nr} bis {end_nr})...")

        mini_chunk = []
        for movie in chunk:
            mini_chunk.append({
                "nr": movie['nr'],
                "filebasename": movie['filebasename'],
                "regisseur": movie['regisseur'], 
                "titel": movie['titel']
            })

        prompt = build_prompt(mini_chunk)

        if dry_run:
            print(f"[DRY-RUN] Batch {current_batch_num} Payload OK.")
            processed_batches += 1
            continue 

        try:
            response = model.generate_content(
                prompt,
                generation_config=GenerationConfig(response_mime_type="application/json")
            )
            
            enriched_chunk = json.loads(response.text)
            
            updates_count = 0
            for enriched_item in enriched_chunk:
                original = next((x for x in data if x['nr'] == enriched_item['nr']), None)
                if original:
                    original['titel'] = enriched_item.get('titel', original['titel'])
                    original['regisseur'] = enriched_item.get('regisseur', original['regisseur'])
                    updates_count += 1
            
            print(f"  -> {updates_count} Filme aktualisiert.")
            save_inventory(data)
            time.sleep(1) 

        except Exception as e:
            error_msg = str(e)
            print(f"  ERROR: {error_msg}")
            
            if "404" in error_msg or "not found" in error_msg.lower():
                print("\nFATALER FEHLER: Modell nicht gefunden oder Zugriff verweigert.")
                sys.exit(1)
            
        finally:
            processed_batches += 1

    print("Vorgang abgeschlossen.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--limit-batches", type=int, default=0)
    args = parser.parse_args()
    
    process_inventory(dry_run=args.dry_run, limit_batches=args.limit_batches)