"""Copie le GIF / la vidéo de l'écran d'accueil sur le dépôt.

Lit splash.json. Si "source" est un lien (Discord, Tenor, Giphy, lien direct...), le média est
téléchargé TOUT DE SUITE (avant que le lien expire) et rangé dans splash_media/.
splash.lock.json indique au launcher quelle copie utiliser pour quel lien.
"""
import hashlib
import html
import json
import os
import re
import sys
import urllib.request

UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"
MEDIA_DIR = "splash_media"
LOCK = "splash.lock.json"
MAX_BYTES = 90 * 1024 * 1024


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as r:
        data = r.read(MAX_BYTES + 1)
        if len(data) > MAX_BYTES:
            sys.exit("Fichier trop lourd (90 Mo max).")
        return data, (r.headers.get("Content-Type") or "").lower()


def kind(data):
    if data[:4] == b"GIF8":
        return ".gif"
    if data[4:8] == b"ftyp":
        return ".mp4"
    if data[:4] == b"RIFF" and data[8:12] == b"AVI ":
        return ".avi"
    if data[:4] == b"\x30\x26\xb2\x75":
        return ".wmv"
    return None


def find_media_in_page(page):
    found = []
    for tag in re.findall(r'(?i)<meta[^>]+>', page):
        if re.search(r'(?i)(?:property|name)\s*=\s*"(?:og:video:secure_url|og:video:url|og:video|og:image|twitter:image|twitter:player:stream)"', tag):
            m = re.search(r'(?i)content\s*=\s*"([^"]+)"', tag)
            if m:
                found.append(html.unescape(m.group(1)))
    found += re.findall(r'(?i)https?://[^"\'\s<>]+?\.(?:gif|mp4)(?:\?[^"\'\s<>]*)?', page)
    gifs = [u for u in found if re.search(r'(?i)\.gif(\?|$)', u)]
    vids = [u for u in found if re.search(r'(?i)\.mp4(\?|$)', u)]
    return (gifs + vids)[:5]


def write_lock(source, file):
    with open(LOCK, "w", encoding="utf-8") as f:
        json.dump({"source": source, "file": file}, f, ensure_ascii=False, indent=2)
        f.write("\n")


def main():
    with open("splash.json", encoding="utf-8-sig") as f:
        cfg = json.load(f)
    source = str(cfg.get("source") or "").strip()

    if not source or not re.match(r"(?i)^https?://", source):
        # pas de lien (désactivé, ou fichier déjà sur le dépôt) : rien à copier
        if os.path.isdir(MEDIA_DIR):
            for n in os.listdir(MEDIA_DIR):
                os.remove(os.path.join(MEDIA_DIR, n))
        if os.path.exists(LOCK):
            os.remove(LOCK)
        print("Pas de lien à copier.")
        return

    if re.search(r"(?i)(youtube\.com|youtu\.be)", source):
        sys.exit("Les liens YouTube ne marchent pas.")

    url = source
    m = re.search(r"giphy\.com/(?:gifs|stickers)/(?:[^/?#]*-)?([A-Za-z0-9]+)(?:[/?#]|$)", source)
    if m:
        url = f"https://media.giphy.com/media/{m.group(1)}/giphy.gif"

    data, ctype = fetch(url)
    ext = kind(data)
    if not ext and "html" in ctype:
        for candidate in find_media_in_page(data.decode("utf-8", "replace")):
            try:
                data, ctype = fetch(candidate)
            except Exception:
                continue
            ext = kind(data)
            if ext:
                break
    if not ext:
        sys.exit("Ce lien ne donne pas un GIF ou une vidéo (.gif / .mp4). Le lien a peut-être expiré : recopie-le.")

    name = hashlib.sha1(source.encode("utf-8")).hexdigest()[:12] + ext
    os.makedirs(MEDIA_DIR, exist_ok=True)
    for n in os.listdir(MEDIA_DIR):
        if n != name:
            os.remove(os.path.join(MEDIA_DIR, n))
    with open(os.path.join(MEDIA_DIR, name), "wb") as f:
        f.write(data)
    write_lock(source, f"{MEDIA_DIR}/{name}")
    print(f"Copié : {MEDIA_DIR}/{name} ({len(data)} octets)")


if __name__ == "__main__":
    main()
