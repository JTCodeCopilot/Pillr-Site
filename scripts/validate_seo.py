#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
import xml.etree.ElementTree as ET
from collections import defaultdict
from dataclasses import dataclass
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlparse


BASE_URL = "https://pillr.management/"
APP_STORE_BADGE_HOST = "toolbox.marketingtools.apple.com"
REQUIRED_OPEN_GRAPH_PROPERTIES = ("og:title", "og:description", "og:url", "og:image")


@dataclass(frozen=True)
class ValidationStats:
    pages: int
    sitemap_urls: int
    jsonld_blocks: int


class PageParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.title_parts: list[str] = []
        self.in_title = False
        self.meta: list[dict[str, str]] = []
        self.links: list[dict[str, str]] = []
        self.images: list[dict[str, str]] = []
        self.local_references: list[str] = []
        self.h1_count = 0
        self.main_count = 0
        self.in_jsonld = False
        self.jsonld_parts: list[str] = []
        self.jsonld_blocks: list[str] = []

    @property
    def title(self) -> str:
        return " ".join("".join(self.title_parts).split())

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attributes = {key: value or "" for key, value in attrs}
        if tag == "title":
            self.in_title = True
        elif tag == "meta":
            self.meta.append(attributes)
        elif tag == "link":
            self.links.append(attributes)
            href = attributes.get("href", "")
            if href:
                self.local_references.append(href)
        elif tag == "img":
            self.images.append(attributes)
            src = attributes.get("src", "")
            if src:
                self.local_references.append(src)
        elif tag == "script":
            src = attributes.get("src", "")
            if src:
                self.local_references.append(src)
            if attributes.get("type", "").lower() == "application/ld+json":
                self.in_jsonld = True
                self.jsonld_parts = []
        elif tag == "a":
            href = attributes.get("href", "")
            if href:
                self.local_references.append(href)

        if tag == "h1":
            self.h1_count += 1
        elif tag == "main":
            self.main_count += 1

    def handle_endtag(self, tag: str) -> None:
        if tag == "title":
            self.in_title = False
        elif tag == "script" and self.in_jsonld:
            self.jsonld_blocks.append("".join(self.jsonld_parts).strip())
            self.in_jsonld = False
            self.jsonld_parts = []

    def handle_data(self, data: str) -> None:
        if self.in_title:
            self.title_parts.append(data)
        if self.in_jsonld:
            self.jsonld_parts.append(data)


def meta_values(parser: PageParser, attribute: str, name: str) -> list[str]:
    return [
        meta.get("content", "").strip()
        for meta in parser.meta
        if meta.get(attribute, "").casefold() == name.casefold()
    ]


def expected_canonical(filename: str) -> str:
    return BASE_URL if filename == "index.html" else f"{BASE_URL}{filename}"


def local_target(site_root: Path, page: Path, reference: str) -> Path | None:
    if not reference or reference.startswith(("#", "mailto:", "tel:", "javascript:")):
        return None

    parsed = urlparse(reference)
    if parsed.scheme or parsed.netloc:
        return None

    path = parsed.path
    if not path:
        return None
    if path == "/":
        return site_root / "index.html"
    if path.startswith("/"):
        return site_root / path.lstrip("/")
    return page.parent / path


def parse_page(path: Path) -> PageParser:
    parser = PageParser()
    parser.feed(path.read_text(encoding="utf-8"))
    return parser


def validate_site(site_root: Path) -> tuple[list[str], ValidationStats]:
    errors: list[str] = []
    pages = sorted(site_root.glob("*.html"))
    titles: dict[str, list[str]] = defaultdict(list)
    descriptions: dict[str, list[str]] = defaultdict(list)
    jsonld_count = 0
    expected_sitemap_urls: set[str] = set()

    if not pages:
        errors.append(f"No HTML pages found in {site_root}")

    for page in pages:
        parser = parse_page(page)
        filename = page.name

        if not parser.title:
            errors.append(f"{filename}: missing title")
        else:
            titles[parser.title.casefold()].append(filename)

        description_values = meta_values(parser, "name", "description")
        if len(description_values) != 1 or not description_values[0]:
            errors.append(f"{filename}: expected one non-empty meta description")
        else:
            descriptions[description_values[0].casefold()].append(filename)

        if parser.h1_count != 1:
            errors.append(f"{filename}: expected one H1, found {parser.h1_count}")
        if parser.main_count != 1:
            errors.append(f"{filename}: expected one main landmark, found {parser.main_count}")

        robots_values = meta_values(parser, "name", "robots")
        if len(robots_values) != 1:
            errors.append(f"{filename}: expected one robots meta tag")
        is_noindex = len(robots_values) == 1 and "noindex" in robots_values[0].casefold()

        canonical_links = [
            link.get("href", "").strip()
            for link in parser.links
            if "canonical" in link.get("rel", "").casefold().split()
        ]
        expected_url = expected_canonical(filename)
        if not is_noindex and canonical_links != [expected_url]:
            errors.append(
                f"{filename}: canonical should be {expected_url}, found {canonical_links or 'none'}"
            )
        elif is_noindex and (
            len(canonical_links) != 1 or not canonical_links[0].startswith(BASE_URL)
        ):
            errors.append(f"{filename}: noindex page needs one Pillr canonical URL")

        if not is_noindex:
            expected_sitemap_urls.add(expected_url)

        for property_name in REQUIRED_OPEN_GRAPH_PROPERTIES:
            values = meta_values(parser, "property", property_name)
            if len(values) != 1 or not values[0]:
                errors.append(f"{filename}: expected one non-empty {property_name} tag")

        og_urls = meta_values(parser, "property", "og:url")
        canonical_url = canonical_links[0] if len(canonical_links) == 1 else expected_url
        if og_urls and og_urls[0] != canonical_url:
            errors.append(f"{filename}: og:url should match its canonical")

        icon_links = [
            link
            for link in parser.links
            if "icon" in link.get("rel", "").casefold().split()
        ]
        if len(icon_links) != 1 or icon_links[0].get("href") != "assets/favicon.png":
            errors.append(f"{filename}: expected one local assets/favicon.png icon")

        for index, raw_jsonld in enumerate(parser.jsonld_blocks, start=1):
            jsonld_count += 1
            try:
                json.loads(raw_jsonld)
            except json.JSONDecodeError as error:
                errors.append(f"{filename}: invalid JSON-LD block {index}: {error.msg}")

        for image in parser.images:
            source = image.get("src", "")
            if not image.get("alt", "").strip():
                errors.append(f"{filename}: image is missing meaningful alt text: {source}")
            if APP_STORE_BADGE_HOST in source:
                if image.get("width") != "120" or image.get("height") != "40":
                    errors.append(f"{filename}: App Store badge must use width 120 and height 40")

        for reference in parser.local_references:
            target = local_target(site_root, page, reference)
            if target is not None and not target.exists():
                errors.append(f"{filename}: broken local reference {reference}")

    for filenames in titles.values():
        if len(filenames) > 1:
            errors.append(f"Duplicate title used by: {', '.join(sorted(filenames))}")
    for filenames in descriptions.values():
        if len(filenames) > 1:
            errors.append(f"Duplicate meta description used by: {', '.join(sorted(filenames))}")

    favicon = site_root / "assets" / "favicon.png"
    if not favicon.exists():
        errors.append("Missing assets/favicon.png")

    sitemap_path = site_root / "sitemap.xml"
    sitemap_urls: list[str] = []
    if not sitemap_path.exists():
        errors.append("Missing sitemap.xml")
    else:
        try:
            sitemap_root = ET.parse(sitemap_path).getroot()
            sitemap_urls = [
                element.text.strip()
                for element in sitemap_root.findall("{*}url/{*}loc")
                if element.text and element.text.strip()
            ]
        except ET.ParseError as error:
            errors.append(f"Invalid sitemap.xml: {error}")

    if len(sitemap_urls) != len(set(sitemap_urls)):
        errors.append("sitemap.xml contains duplicate URLs")

    expected_urls = expected_sitemap_urls
    actual_urls = set(sitemap_urls)
    for missing_url in sorted(expected_urls - actual_urls):
        errors.append(f"sitemap.xml is missing {missing_url}")
    for extra_url in sorted(actual_urls - expected_urls):
        errors.append(f"sitemap.xml contains an unknown URL: {extra_url}")

    robots_path = site_root / "robots.txt"
    if not robots_path.exists():
        errors.append("Missing robots.txt")
    elif "Sitemap: https://pillr.management/sitemap.xml" not in robots_path.read_text(
        encoding="utf-8"
    ):
        errors.append("robots.txt is missing the production sitemap URL")

    return errors, ValidationStats(len(pages), len(sitemap_urls), jsonld_count)


def main(argv: list[str]) -> int:
    site_root = (
        Path(argv[1]).expanduser().resolve()
        if len(argv) > 1
        else Path(__file__).resolve().parents[1]
    )
    errors, stats = validate_site(site_root)
    if errors:
        print("SEO validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print(
        "SEO validation passed: "
        f"{stats.pages} pages, {stats.sitemap_urls} sitemap URLs, "
        f"{stats.jsonld_blocks} JSON-LD blocks."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
