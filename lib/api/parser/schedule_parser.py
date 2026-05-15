import json
import re
import time
from bs4 import BeautifulSoup
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

# --- CONFIGURATION ---
INPUT_FILE = 'lib/api/grades.html'
OUTPUT_FILE = 'assets/schedule.json'

STYLE_MAP = {
    'CS':   {'bg': '0xFFECFDF5', 'border': '0xFFA7F3D0', 'text': '0xFF065F46'},
    'EECS': {'bg': '0xFFF5F3FF', 'border': '0xFFDDD6FE', 'text': '0xFF6D28D9'},
    'PHYS': {'bg': '0xFFFFF1F2', 'border': '0xFFFECACA', 'text': '0xFFB91C1C'},
    'MATH': {'bg': '0xFFFAF5FF', 'border': '0xFFE9D5FF', 'text': '0xFF7C3AED'},
    'CLC':  {'bg': '0xFFFFF7ED', 'border': '0xFFFED7AA', 'text': '0xFFC2410C'},
    'PE':   {'bg': '0xFFF8FAFC', 'border': '0xFFCBD5E1', 'text': '0xFF475569'},
}

def parse_and_save():
    try:
        with open(INPUT_FILE, 'r', encoding='utf-8') as f:
            soup = BeautifulSoup(f, 'html.parser')
        
        rows = soup.find_all('tr', align="center")
        course_list = []

        for row in rows:
            tds = row.find_all('td')
            if len(tds) < 6: continue

            year = tds[0].get_text(strip=True)
            status = tds[5].get_text(strip=True)

            # Filter for Year 114 and ignore Withdrawn courses
            if year == "114" and "Withdrawn" not in status and "停修" not in status:
                code = tds[2].get_text(strip=True)
                # Parse English title from the mixed language cell
                name_bits = tds[3].get_text(separator="|", strip=True).split("|")
                title = name_bits[2] if len(name_bits) > 2 else name_bits[0]
                
                # Get styles
                prefix = re.match(r'^([a-zA-Z]+)', code)
                prefix = prefix.group(1) if prefix else "DEFAULT"
                style = STYLE_MAP.get(prefix, {'bg': '0xFFEFF6FF', 'border': '0xFFBFDBFE', 'text': '0xFF1D4ED8'})
                
                course_list.append({
                    "title": title,
                    "code": code,
                    "day": 1, 
                    "startSlot": 0,
                    "duration": 2,
                    "bg": style['bg'],
                    "border": style['border'],
                    "text": style['text']
                })

        with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
            json.dump(course_list, f, indent=4, ensure_ascii=False)
        
        print(f"[{time.strftime('%H:%M:%S')}] JSON updated successfully in {OUTPUT_FILE}")
    
    except Exception as e:
        print(f"Error parsing file: {e}")

class UpdateHandler(FileSystemEventHandler):
    def on_modified(self, event):
        if event.src_path.endswith(INPUT_FILE):
            parse_and_save()

if __name__ == "__main__":
    # Initial run
    parse_and_save()
    
    # Start watching
    observer = Observer()
    observer.schedule(UpdateHandler(), path='.', recursive=False)
    observer.start()
    print(f"Watching for changes in {INPUT_FILE}...")
    
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
    observer.join()

