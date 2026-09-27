"""One-off: add a `gu` (Gujarati script) name to every district/taluka/village
in assets/data/gujarat_places.json by transliterating the English Census name
through Google Input Tools (same endpoint as lib/services/transliteration_service.dart).

Words are deduped and cached in .gu_cache.json next to this script, so reruns
resume. Punctuation, digits and ALL-CAPS census tags (CT, OG) are kept as-is.
DISTRICTS hand-corrects the 26 Census 2011 district names; WORDS translates the
few English qualifiers (East, Part, ...) instead of transliterating them.

Idempotent: always rebuilds `gu` from `name`.
Usage (from repo root):  python scripts/places/add_gujarati_names.py
"""
import json
import re
import sys
import time
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ASSET = ROOT / 'assets/data/gujarat_places.json'
CACHE = Path(__file__).with_name('.gu_cache.json')

WORDS = {
    'part': 'ભાગ', 'east': 'પૂર્વ', 'west': 'પશ્ચિમ', 'north': 'ઉત્તર',
    'south': 'દક્ષિણ', 'no': 'નં', 'city': 'શહેર', 'ward': 'વોર્ડ',
}

DISTRICTS = {
    'Ahmadabad': 'અમદાવાદ', 'Amreli': 'અમરેલી', 'Anand': 'આણંદ',
    'Banas Kantha': 'બનાસકાંઠા', 'Bharuch': 'ભરૂચ', 'Bhavnagar': 'ભાવનગર',
    'Dohad': 'દાહોદ', 'Gandhinagar': 'ગાંધીનગર', 'Jamnagar': 'જામનગર',
    'Junagadh': 'જૂનાગઢ', 'Kachchh': 'કચ્છ', 'Kheda': 'ખેડા',
    'Mahesana': 'મહેસાણા', 'Narmada': 'નર્મદા', 'Navsari': 'નવસારી',
    'Panch Mahals': 'પંચમહાલ', 'Patan': 'પાટણ', 'Porbandar': 'પોરબંદર',
    'Rajkot': 'રાજકોટ', 'Sabar Kantha': 'સાબરકાંઠા', 'Surat': 'સુરત',
    'Surendranagar': 'સુરેન્દ્રનગર', 'Tapi': 'તાપી', 'The Dangs': 'ડાંગ',
    'Vadodara': 'વડોદરા', 'Valsad': 'વલસાડ',
}

TOKEN = re.compile(r'[A-Za-z]+')


def is_tag(tok):
    return tok in ('CT', 'OG')  # census town / outgrowth tags, keep Latin


def fetch(word):
    url = ('https://inputtools.google.com/request?text=' +
           urllib.parse.quote(word) +
           '&itc=gu-t-i0-und&num=1&cp=0&cs=1&ie=utf-8&oe=utf-8')
    for attempt in range(5):
        try:
            with urllib.request.urlopen(url, timeout=15) as r:
                body = json.loads(r.read().decode('utf-8'))
            if body[0] == 'SUCCESS':
                return word, body[1][0][1][0]
        except Exception as e:  # network blip / throttle: back off and retry
            print(f'  retry {word}: {e}', file=sys.stderr)
        time.sleep(2 ** attempt)
    return word, None


def gu_word(tok, cache):
    if tok.lower() in WORDS:
        return WORDS[tok.lower()]
    if tok in DISTRICTS:  # "Ahmadabad City" -> "અમદાવાદ શહેર", not a re-guess
        return DISTRICTS[tok]
    if is_tag(tok):
        return tok
    return cache.get(tok.lower()) or tok


def gu_name(name, cache):
    if name in DISTRICTS:
        return DISTRICTS[name]
    return TOKEN.sub(lambda m: gu_word(m.group(0), cache), name)


def polite(word):
    time.sleep(0.1)
    return fetch(word)


def main():
    data = json.loads(ASSET.read_text(encoding='utf-8'))
    entries = []
    for d in data['districts']:
        entries.append(d)
        for t in d['talukas']:
            entries.append(t)
            entries.extend(t['villages'])

    cache = json.loads(CACHE.read_text(encoding='utf-8')) if CACHE.exists() else {}
    todo = sorted({w.lower() for e in entries for w in TOKEN.findall(e['name'])
                   if w.lower() not in WORDS and not is_tag(w)} - cache.keys())
    print(f'{len(entries)} entries, {len(todo)} words to fetch')

    # ponytail: 4 workers + 100ms sleep each is "polite enough" for a one-off.
    with ThreadPoolExecutor(4) as pool:
        for i, (w, g) in enumerate(pool.map(polite, todo), 1):
            if g:
                cache[w] = g
            if i % 200 == 0 or i == len(todo):
                # Write-then-rename: a failed write (e.g. disk full) must not
                # truncate the progress already saved.
                tmp = CACHE.with_suffix('.tmp')
                tmp.write_text(json.dumps(cache, ensure_ascii=False), encoding='utf-8')
                tmp.replace(CACHE)
                print(f'  {i}/{len(todo)}', flush=True)

    missing = 0
    for e in entries:
        e['gu'] = gu_name(e['name'], cache)
        missing += not re.search('[઀-૿]', e['gu'])
    print(f'entries without any Gujarati: {missing}')
    ASSET.write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':')),
                     encoding='utf-8', newline='\n')


if __name__ == '__main__':
    main()
