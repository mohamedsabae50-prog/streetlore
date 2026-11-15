#!/usr/bin/env python3
"""Resolve unique Aswan catalog images with four polite Wikimedia API batches."""

import json
import re
import sys
import time
import unicodedata
from pathlib import Path
from urllib.parse import urlencode, urlsplit
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parents[1]
SEED_PATH = ROOT / "lib" / "data" / "aswan_seed.dart"
OUTPUT_PATH = ROOT / "lib" / "data" / "aswan_image_urls.dart"
USER_AGENT = (
    "StreetLoreCatalogMaintenance/1.0 "
    "(https://github.com/mohamedsabae50-prog/streetlore)"
)
STOP_WORDS = {
    "at",
    "and",
    "bank",
    "banks",
    "bazaar",
    "cafe",
    "cafes",
    "church",
    "churches",
    "egypt",
    "garden",
    "gardens",
    "hotel",
    "hotels",
    "island",
    "islands",
    "market",
    "markets",
    "mosque",
    "mosques",
    "museum",
    "museums",
    "nile",
    "the",
    "of",
    "temple",
    "temples",
}
IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".avif"}
EXCLUDED_IMAGE_TERMS = {"bonfils", "british_museum", "construction", "turin"}
DISTINCTIVE_LANDMARK_TOKENS = {
    "abu",
    "dam",
    "edfu",
    "edfou",
    "elephantine",
    "ghazal",
    "high",
    "kalabsha",
    "kom",
    "ombo",
    "obelisk",
    "obelisco",
    "obelisque",
    "philae",
    "qertassi",
    "saluga",
    "sehel",
    "simeon",
    "simbel",
    "satet",
    "sesostris",
}
_request_count = 0


def _request_json(endpoint, params):
    global _request_count
    _request_count += 1
    request = Request(
        f"{endpoint}?{urlencode(params)}",
        headers={"User-Agent": USER_AGENT, "Accept": "application/json"},
    )
    with urlopen(request, timeout=30) as response:
        if response.status != 200:
            raise RuntimeError(f"Wikimedia API returned HTTP {response.status}")
        data = json.load(response)
    if "error" in data:
        raise RuntimeError(f"Wikimedia API error: {data['error']}")
    return data


def _tokens(value):
    normalized = (
        unicodedata.normalize("NFKD", value)
        .encode("ascii", "ignore")
        .decode("ascii")
    )
    return {
        token
        for token in re.findall(r"[a-z0-9]+", normalized.casefold())
        if token not in STOP_WORDS and len(token) > 1
    }


def _load_places():
    source = SEED_PATH.read_text(encoding="utf-8")
    place_section = source.split("final List<PlaceModel> aswanSeedPlaces", 1)[1]
    place_section = place_section.split("final Map<String, PlaceModel>", 1)[0]
    record_pattern = re.compile(r"_buildAswanPlace\(\((.*?)\)\),", re.DOTALL)
    id_pattern = re.compile(r"id:\s*'([^']+)'")
    name_pattern = re.compile(
        r"""nameEn:\s*(?:'((?:\\.|[^'])*)'|"((?:\\.|[^"])*)")"""
    )
    places = []
    for record in record_pattern.findall(place_section):
        place_id = id_pattern.search(record)
        name = name_pattern.search(record)
        if place_id and name:
            decoded_name = (name.group(1) or name.group(2)).replace(
                r"\'", "'"
            ).replace(r"\\", "\\")
            places.append((place_id.group(1), decoded_name))
    if len(places) != 60:
        raise RuntimeError(f"Expected 60 Aswan place records, found {len(places)}")
    return places


def _title_key(value):
    return " ".join(value.replace("_", " ").casefold().split())


def _supported_image(url):
    path = urlsplit(url).path.casefold()
    return (
        path.endswith(tuple(IMAGE_EXTENSIONS))
        and not any(term in path for term in EXCLUDED_IMAGE_TERMS)
    )


def _page_images(names):
    results = {}
    title_aliases = {}
    for start in range(0, len(names), 30):
        batch = names[start : start + 30]
        data = _request_json(
            "https://en.wikipedia.org/w/api.php",
            {
                "action": "query",
                "prop": "pageimages",
                "piprop": "original|thumbnail",
                "pithumbsize": "1000",
                "redirects": "1",
                "titles": "|".join(batch),
                "format": "json",
            },
        )
        query = data.get("query", {})
        for alias in [*query.get("normalized", []), *query.get("redirects", [])]:
            title_aliases[_title_key(alias["from"])] = alias["to"]
        for page in query.get("pages", {}).values():
            images = [page.get("original", {}), page.get("thumbnail", {})]
            source = next(
                (
                    image.get("source")
                    for image in images
                    if image.get("source")
                    and image["source"].startswith(
                        "https://upload.wikimedia.org/wikipedia/commons/"
                    )
                    and _supported_image(image["source"])
                ),
                None,
            )
            if source:
                results[_title_key(page["title"])] = source.split("?", 1)[0]
        if start + 30 < len(names):
            time.sleep(1.5)
    return results, title_aliases


def _commons_images(search_terms):
    query = " OR ".join(search_terms)
    data = _request_json(
        "https://commons.wikimedia.org/w/api.php",
        {
            "action": "query",
            "generator": "search",
            "gsrsearch": query,
            "gsrnamespace": "6",
            "gsrlimit": "50",
            "prop": "imageinfo",
            "iiprop": "url",
            "format": "json",
        },
    )
    candidates = []
    for page in data.get("query", {}).get("pages", {}).values():
        image_info = page.get("imageinfo", [])
        if not image_info:
            continue
        url = image_info[0].get("url")
        if (
            url
            and url.startswith("https://upload.wikimedia.org/wikipedia/commons/")
            and _supported_image(url)
        ):
            candidates.append((page["title"], url.split("?", 1)[0]))
    return list(dict.fromkeys(candidates))


def _existing_image_urls():
    urls = set()
    for filename in (
        "alexandria_image_urls.dart",
        "cairo_image_urls.dart",
        "luxor_image_urls.dart",
    ):
        source = (ROOT / "lib" / "data" / filename).read_text(encoding="utf-8")
        urls.update(
            re.findall(
                r"https://upload\.wikimedia\.org/wikipedia/commons/[^\s\"']+",
                source,
            )
        )
    return urls


def refresh():
    global _request_count
    _request_count = 0
    places = _load_places()
    names = [name for _, name in places]
    page_images, aliases = _page_images(names)
    time.sleep(1.5)
    first_candidates = _commons_images(
        ["Aswan", "Philae", "Nubia", "Elephantine", "granite", "Kalabsha"]
    )
    time.sleep(1.5)
    second_candidates = _commons_images(
        ["Aswan", "Abu Simbel", "Kom Ombo", "Edfu", "Nile", "Nubia"]
    )
    if _request_count != 4:
        raise RuntimeError(f"Expected four Wikimedia requests, made {_request_count}")

    assigned = {}
    used_urls = _existing_image_urls()
    candidate_batches = [first_candidates, second_candidates]
    for index, (place_id, name) in enumerate(places):
        lookup_name = aliases.get(_title_key(name), name)
        page_image = page_images.get(_title_key(lookup_name))
        if page_image and page_image not in used_urls:
            assigned[place_id] = page_image
            used_urls.add(page_image)
            continue

        preferred_batch = 0 if index < 30 else 1
        candidates = list(
            dict.fromkeys(
                candidate_batches[preferred_batch]
                + candidate_batches[1 - preferred_batch]
            )
        )
        name_tokens = _tokens(name)
        name_landmarks = name_tokens & DISTINCTIVE_LANDMARK_TOKENS
        ranked = sorted(
            enumerate(candidates),
            key=lambda entry: (
                bool(
                    (_tokens(entry[1][0]) & DISTINCTIVE_LANDMARK_TOKENS)
                    - name_landmarks
                ),
                -len(name_tokens & _tokens(entry[1][0])),
                entry[0],
            ),
        )
        selected = next(
            (
                candidate
                for _, candidate in ranked
                if candidate[1] not in used_urls
            ),
            None,
        )
        if selected is None:
            raise RuntimeError(
                f"No unique Wikimedia Commons image found for {place_id}"
            )
        assigned[place_id] = selected[1]
        used_urls.add(selected[1])

    if len(assigned) != 60 or len(set(assigned.values())) != 60:
        raise RuntimeError("The resolved image map is not 60-for-60 and unique")
    if any(
        not url.startswith("https://upload.wikimedia.org/wikipedia/commons/")
        for url in assigned.values()
    ):
        raise RuntimeError("A resolved image URL is outside Wikimedia Commons")

    lines = ["const Map<String, String> aswanImageUrls = {"]
    for place_id, _ in places:
        lines.append(f"  {json.dumps(place_id)}: {json.dumps(assigned[place_id])},")
    lines.append("};")
    OUTPUT_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Updated {len(assigned)} unique Aswan image URLs in {OUTPUT_PATH}")


def validate_offline():
    source = OUTPUT_PATH.read_text(encoding="utf-8")
    entry_pattern = re.compile(
        r"""(?P<quote>["'])(?P<key>[^"']+)(?P=quote):\s*"""
        r"""(?P=quote)(?P<url>[^"']+)(?P=quote)"""
    )
    entries = [
        (match.group("key"), match.group("url"))
        for match in entry_pattern.finditer(source)
    ]
    if len(entries) != 60:
        raise RuntimeError(f"Expected 60 Aswan image URLs, found {len(entries)}")
    urls = [url for _, url in entries]
    if len(set(urls)) != 60:
        raise RuntimeError("Aswan image URLs are not unique")
    if any(
        not url.startswith("https://upload.wikimedia.org/wikipedia/commons/")
        for url in urls
    ):
        raise RuntimeError("An Aswan image URL is not a Wikimedia Commons URL")
    if any(not _supported_image(url) for url in urls):
        raise RuntimeError("An Aswan URL does not point to a supported image format")
    print("Offline validation passed: 60 unique Wikimedia Commons URLs.")


if __name__ == "__main__":
    try:
        if sys.argv[1:] == ["--check"]:
            validate_offline()
        elif not sys.argv[1:] or sys.argv[1:] == ["--refresh"]:
            refresh()
        else:
            raise RuntimeError("Usage: resolve_aswan_image_urls.py [--refresh|--check]")
    except Exception as error:
        print(f"Could not refresh Aswan images: {error}", file=sys.stderr)
        raise
