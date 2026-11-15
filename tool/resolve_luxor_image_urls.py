#!/usr/bin/env python3
"""Refresh Luxor catalog images from Wikimedia APIs in four polite batches."""

import json
import re
import sys
import time
from pathlib import Path
from urllib.parse import urlencode, urlsplit
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parents[1]
SEED_PATH = ROOT / "lib" / "data" / "luxor_seed.dart"
OUTPUT_PATH = ROOT / "lib" / "data" / "luxor_image_urls.dart"
USER_AGENT = (
    "StreetLoreCatalogMaintenance/1.0 "
    "(https://github.com/mohamedsabae50-prog/streetlore)"
)
STOP_WORDS = {
    "of",
    "the",
    "and",
}
IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".avif"}


def _request_json(endpoint, params):
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
    return {
        token
        for token in re.findall(r"[a-z0-9]+", value.casefold())
        if token not in STOP_WORDS and len(token) > 1
    }


def _load_places():
    source = SEED_PATH.read_text(encoding="utf-8")
    place_section = source.split("final List<PlaceModel> luxorSeedPlaces", 1)[1]
    place_section = place_section.split(
        "luxorSeedItineraries = List<ItineraryModel>", 1
    )[0]
    record_pattern = re.compile(r"_buildLuxorPlace\(\((.*?)\)\),", re.DOTALL)
    field_patterns = {
        "id": re.compile(r"id:\s*'([^']+)'"),
        "category": re.compile(r"category:\s*'([^']+)'"),
        "name": re.compile(r"nameEn:\s*'((?:\\.|[^'])*)'"),
    }
    places = []
    for record in record_pattern.findall(place_section):
        fields = {
            field: pattern.search(record)
            for field, pattern in field_patterns.items()
        }
        if all(fields.values()):
            places.append(
                tuple(fields[field].group(1) for field in ("id", "category", "name"))
            )
    if len(places) != 60:
        raise RuntimeError(f"Expected 60 Luxor place records, found {len(places)}")
    return places


def _title_key(value):
    return " ".join(value.replace("_", " ").casefold().split())


def _supported_image(url):
    return urlsplit(url).path.casefold().endswith(tuple(IMAGE_EXTENSIONS))


def _page_images(names):
    results = {}
    title_aliases = {}
    for batch_start in range(0, len(names), 50):
        batch = names[batch_start : batch_start + 50]
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
                    if image.get("source") and _supported_image(image["source"])
                    and image["source"].startswith(
                        "https://upload.wikimedia.org/wikipedia/commons/"
                    )
                ),
                None,
            )
            if source:
                results[_title_key(page["title"])] = source.split("?", 1)[0]
        if batch_start + 50 < len(names):
            time.sleep(1.5)
    return results, title_aliases


def _commons_images():
    candidates = []

    def collect(data):
        for page in data.get("query", {}).get("pages", {}).values():
            image_info = page.get("imageinfo", [])
            if image_info:
                url = image_info[0].get("url")
                if url and url.startswith(
                    "https://upload.wikimedia.org/wikipedia/commons/"
                ) and _supported_image(url):
                    candidates.append((page["title"], url.split("?", 1)[0]))

    params = {
        "action": "query",
        "generator": "search",
        "gsrsearch": "Luxor",
        "gsrnamespace": "6",
        "gsrlimit": "50",
        "prop": "imageinfo",
        "iiprop": "url",
        "format": "json",
    }
    data = _request_json("https://commons.wikimedia.org/w/api.php", params)
    collect(data)
    continuation = data.get("continue", {})
    if continuation:
        time.sleep(1.5)
        params.update(continuation)
        collect(_request_json("https://commons.wikimedia.org/w/api.php", params))
    candidates = list(dict.fromkeys(candidates))
    if not candidates:
        raise RuntimeError("Wikimedia Commons returned no usable image candidates")
    return candidates


def refresh():
    places = _load_places()
    names = [name for _, _, name in places]
    page_images, aliases = _page_images(names)
    time.sleep(1.5)
    commons_images = _commons_images()

    assigned = {}
    used_urls = set()
    for place_id, _, name in places:
        lookup_name = aliases.get(_title_key(name), name)
        page_image = page_images.get(_title_key(lookup_name))
        if page_image and page_image not in used_urls:
            assigned[place_id] = page_image
            used_urls.add(page_image)
            continue

        name_tokens = _tokens(name)
        ranked = sorted(
            commons_images,
            key=lambda candidate: (
                -len(name_tokens & _tokens(candidate[0])),
                candidate[0].casefold(),
            ),
        )
        selected = next(
            ((title, url) for title, url in ranked if url not in used_urls),
            None,
        )
        if selected is None:
            raise RuntimeError(f"No unique Commons image found for {place_id}")
        assigned[place_id] = selected[1]
        used_urls.add(selected[1])

    if len(assigned) != 60 or len(used_urls) != 60:
        raise RuntimeError("The resolved image map is not 60-for-60 and unique")
    if any(
        not url.startswith("https://upload.wikimedia.org/wikipedia/commons/")
        for url in assigned.values()
    ):
        raise RuntimeError("A resolved image URL is outside Wikimedia Commons")

    lines = ["const Map<String, String> luxorImageUrls = {"]
    for place_id, _, _ in places:
        lines.append(f"  {json.dumps(place_id)}: {json.dumps(assigned[place_id])},")
    lines.append("};")
    OUTPUT_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Updated {len(assigned)} unique Luxor image URLs in {OUTPUT_PATH}")


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
        raise RuntimeError(f"Expected 60 Luxor image URLs, found {len(entries)}")
    urls = [url for _, url in entries]
    if len(set(urls)) != 60:
        raise RuntimeError("Luxor image URLs are not unique")
    if any(
        not url.startswith("https://upload.wikimedia.org/wikipedia/commons/")
        for url in urls
    ):
        raise RuntimeError("A Luxor image URL is not a Wikimedia Commons URL")
    if any(not _supported_image(url) for url in urls):
        raise RuntimeError("A Luxor URL does not point to a supported image format")
    print("Offline validation passed: 60 unique Wikimedia Commons URLs.")


if __name__ == "__main__":
    try:
        if sys.argv[1:] == ["--check"]:
            validate_offline()
        elif not sys.argv[1:] or sys.argv[1:] == ["--refresh"]:
            refresh()
        else:
            raise RuntimeError("Usage: resolve_luxor_image_urls.py [--refresh|--check]")
    except Exception as error:
        print(f"Could not refresh Luxor images: {error}", file=sys.stderr)
        raise
