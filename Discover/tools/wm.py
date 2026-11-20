"""Small Wikimedia helper: polite, cached API access (no credentials, descriptive User-Agent)."""
import html
import json
import os
import re
import time
import urllib.parse
import urllib.request

UA = "StudyCraftDeckBuilder/1.0 (educational flashcard decks)"
CACHE = os.environ.get("WM_CACHE", "/tmp/studycraft-wm")
os.makedirs(CACHE, exist_ok=True)


def fetch(url, path):
    if os.path.exists(path):
        return
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    err = None
    for attempt in range(8):
        try:
            with urllib.request.urlopen(req, timeout=60) as r, open(path, "wb") as f:
                f.write(r.read())
            return
        except Exception as e:  # rate limits: back off
            err = e
            if getattr(e, "code", None) == 404:
                break
            time.sleep(8 + attempt * 10)
    raise err


def get_json(url, name):
    path = os.path.join(CACHE, name)
    fetch(url, path)
    return json.load(open(path))


def commons_info(title, width=400):
    q = urllib.parse.urlencode(
        dict(
            action="query", titles="File:" + title, redirects=1, prop="imageinfo",
            iiprop="url|extmetadata", iiurlwidth=width, format="json",
            iiextmetadatafilter="LicenseShortName|AttributionRequired|Artist",
        )
    )
    data = get_json(
        "https://commons.wikimedia.org/w/api.php?" + q,
        f"info-{width}-" + urllib.parse.quote(title, safe="") + ".json",
    )
    page = next(iter(data["query"]["pages"].values()))
    return page["imageinfo"][0]


def clean(text, limit=70):
    text = html.unescape(re.sub(r"<[^>]+>", "", text or "")).strip()
    text = re.sub(r"\s+", " ", text)
    return text[:limit].rstrip(" ,;") if text else ""
