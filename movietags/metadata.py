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
    # Das Schema wurde an dein neues Datenmodell angepasst
    schema_example = """
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
    """

    prompt = f"""
    AUFGABE:
    Analysiere die folgende Liste von Videodateien (JSON). Ergänze fehlende Metadaten basierend auf 'titel.de', 'jahr' und 'artist' und 'show' und dem 'filebasename' und deinem Wissen über Filme/Serien.

    REGELN:
    1. Analysiere 'titel.de', 'jahr' und 'artist' und 'show' (falls vorhanden) und 'filebasename' um den Film zu identifizieren.
    2. Ergänze folgende Felder falls sie leer sind:
       - titel.orig (Originaltitel)
       - regisseur.name (Vollständiger Name)
       - jahr (Erscheinungsjahr als String, z.B. "1966")
       - darsteller (Liste mit 2 bis 3 Hauptdarstellern und ihren Rollennamen)
    3. WICHTIG: Die 'nr' darf NICHT verändert werden (Identifikator).
    4. Falls Identifikation unmöglich: Lasse Felder leer (""). Halluziniere keine Daten.

    AUSGABEFORMAT:
    Antworte ausschließlich mit einer JSON-Liste von Objekten in diesem Format:
    {schema_example}

    EINGABEDATEN:
    """
    prompt += json.dumps(movies_chunk, ensure_ascii=False)
    return prompt

def process_inventory(dry_run=False, limit_batches=0):
    model = None
    if not dry_run:
        model = configure_genai()
    
    data = load_inventory()
    
    # --- FILTER KONFIGURATION ---
    # Definiere hier, welche Einträge in die Todo-Liste kommen.
    # 'm' ist der einzelne Filmeintrag als Dictionary.
    
    def filter_condition(m):
        # OPTION A: Nur bestimmte Serie (z.B. Tatort)
        # return m.get('show') == "Tatort"
        
        # OPTION B: Nur Einträge, die "Hitchcock" im Artist haben
        # return "Hitchcock" in m.get('artist', "")

        # OPTION C: Alte Logik (Nur wo deutscher Titel fehlt)
        # return m['titel']['de'] == ""

        # OPTION D: ALLES (Default - Vorsicht, bearbeitet die ganze DB!)
        return True

    # Filter anwenden
    todos = [m for m in data if filter_condition(m)]
    
    # Sortieren nach Nummer
    todos.sort(key=lambda x: x['nr'])
    
    print(f"Bestand: {len(data)} Einträge. Zu bearbeiten: {len(todos)}")
    print(f"Verwendetes Modell: {MODEL_NAME}")
    
    if dry_run:
        print("\n--- DRY RUN MODUS AKTIV ---")

    if not todos:
        print("Alles erledigt.")
        return

    processed_batches = 0

    for i in range(0, len(todos), CHUNK_SIZE):
        if limit_batches > 0 and processed_batches >= limit_batches:
            print(f"\nLimit von {limit_batches} Batches erreicht. Beende.")
            break

        chunk = todos[i:i + CHUNK_SIZE]
        current_batch_num = int(i/CHUNK_SIZE) + 1
        
        start_nr = chunk[0]['nr']
        end_nr = chunk[-1]['nr']
        print(f"Bearbeite Batch {current_batch_num} (Nr. {start_nr} bis {end_nr})...")

        # Wir bauen einen minimierten Chunk für den Prompt, um Tokens zu sparen,
        # schicken aber artist/show mit, falls das Inventar-Skript sie schon gefunden hat.
        mini_chunk = []
        for movie in chunk:
            mini_chunk.append({
                "nr": movie['nr'],
                "filebasename": movie['filebasename'],
                "jahr": movie['jahr'],
                "artist": movie.get('artist', ""),
                "show": movie.get('show', ""),
                "titel": movie.get('titel', {"de": "", "orig": ""})
            })

        prompt = build_prompt(mini_chunk)

        if dry_run:
            print(f"[DRY-RUN] Batch {current_batch_num} Payload OK.")
            # Optional: print(prompt) um zu sehen was rausgeht
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
                    # Hier übernehmen wir die neuen Felder in die Datenbank
                    original['titel'] = enriched_item.get('titel', original['titel'])
                    original['regisseur'] = enriched_item.get('regisseur', original.get('regisseur', {'name': ''}))
                    original['jahr'] = enriched_item.get('jahr', original.get('jahr', ''))
                    original['darsteller'] = enriched_item.get('darsteller', original.get('darsteller', []))
                    
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