from __future__ import annotations

import re
import subprocess
import sys
import tempfile
import unittest
from html.parser import HTMLParser
from pathlib import Path


SITE_ROOT = Path(__file__).resolve().parents[1]
VALIDATOR = SITE_ROOT / "scripts" / "validate_seo.py"
APP_STORE_BADGE_HOST = "toolbox.marketingtools.apple.com"


class PageParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.title_parts: list[str] = []
        self.in_title = False
        self.main_count = 0
        self.images: list[dict[str, str]] = []
        self.links: list[dict[str, str]] = []

    @property
    def title(self) -> str:
        return " ".join("".join(self.title_parts).split())

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attributes = {key: value or "" for key, value in attrs}
        if tag == "title":
            self.in_title = True
        elif tag == "main":
            self.main_count += 1
        elif tag == "img":
            self.images.append(attributes)
        elif tag == "link":
            self.links.append(attributes)

    def handle_endtag(self, tag: str) -> None:
        if tag == "title":
            self.in_title = False

    def handle_data(self, data: str) -> None:
        if self.in_title:
            self.title_parts.append(data)


def parse_page(path: Path) -> PageParser:
    parser = PageParser()
    parser.feed(path.read_text(encoding="utf-8"))
    return parser


def write_valid_page(root: Path, filename: str, title: str) -> None:
    route = "" if filename == "index.html" else filename
    canonical = f"https://pillr.management/{route}"
    (root / filename).write_text(
        f"""<!DOCTYPE html>
<html lang="en">
<head>
  <title>{title}</title>
  <meta name="description" content="A unique and useful description for {title}." />
  <meta name="robots" content="index, follow" />
  <link rel="canonical" href="{canonical}" />
  <link rel="icon" type="image/png" sizes="64x64" href="assets/favicon.png" />
  <meta property="og:title" content="{title}" />
  <meta property="og:description" content="A unique and useful description for {title}." />
  <meta property="og:url" content="{canonical}" />
  <meta property="og:image" content="https://pillr.management/pillr-og.png" />
  <script type="application/ld+json">{{"@context":"https://schema.org","@type":"Article"}}</script>
</head>
<body><main><h1>{title}</h1></main></body>
</html>
""",
        encoding="utf-8",
    )


def write_site_files(root: Path, filenames: list[str]) -> None:
    (root / "assets").mkdir()
    (root / "assets" / "favicon.png").write_bytes(b"favicon")
    urls = []
    for filename in filenames:
        route = "" if filename == "index.html" else filename
        urls.append(f"  <url><loc>https://pillr.management/{route}</loc></url>")
    (root / "sitemap.xml").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
        + "\n".join(urls)
        + "\n</urlset>\n",
        encoding="utf-8",
    )
    (root / "robots.txt").write_text(
        "User-agent: *\nAllow: /\nSitemap: https://pillr.management/sitemap.xml\n",
        encoding="utf-8",
    )


class SEOQuickWinTests(unittest.TestCase):
    def test_validator_accepts_current_site(self) -> None:
        result = subprocess.run(
            [sys.executable, str(VALIDATOR)],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_validator_rejects_duplicate_titles(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            write_site_files(root, ["index.html", "guide.html"])
            write_valid_page(root, "index.html", "Repeated title")
            write_valid_page(root, "guide.html", "Repeated title")

            result = subprocess.run(
                [sys.executable, str(VALIDATOR), str(root)],
                capture_output=True,
                text=True,
                check=False,
            )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("duplicate title", (result.stdout + result.stderr).lower())

    def test_every_page_has_one_main_landmark(self) -> None:
        problems = {
            path.name: parse_page(path).main_count
            for path in SITE_ROOT.glob("*.html")
            if parse_page(path).main_count != 1
        }
        self.assertEqual(problems, {})

    def test_page_titles_are_unique_and_reminder_guide_is_a_checklist(self) -> None:
        pages = {path.name: parse_page(path).title for path in SITE_ROOT.glob("*.html")}
        title_to_pages: dict[str, list[str]] = {}
        for filename, title in pages.items():
            title_to_pages.setdefault(title, []).append(filename)
        duplicates = {title: names for title, names in title_to_pages.items() if len(names) > 1}

        self.assertEqual(duplicates, {})
        self.assertEqual(
            pages["adhd-medication-reminder-app-for-iphone.html"],
            "ADHD Medication Reminder App Checklist for iPhone | Pillr",
        )

    def test_reminder_guide_shows_its_current_update_date(self) -> None:
        page = (SITE_ROOT / "adhd-medication-reminder-app-for-iphone.html").read_text(
            encoding="utf-8"
        )
        self.assertIn('<p class="article-meta">Updated July 10, 2026</p>', page)

    def test_every_page_declares_the_local_favicon(self) -> None:
        problems: list[str] = []
        for path in SITE_ROOT.glob("*.html"):
            parser = parse_page(path)
            icons = [
                link
                for link in parser.links
                if "icon" in link.get("rel", "").lower().split()
            ]
            if len(icons) != 1 or icons[0].get("href") != "assets/favicon.png":
                problems.append(path.name)

        self.assertTrue((SITE_ROOT / "assets" / "favicon.png").exists())
        self.assertEqual(problems, [])

    def test_app_store_badges_have_intrinsic_dimensions(self) -> None:
        problems: list[tuple[str, str, str]] = []
        for path in SITE_ROOT.glob("*.html"):
            for image in parse_page(path).images:
                if APP_STORE_BADGE_HOST not in image.get("src", ""):
                    continue
                if image.get("width") != "120" or image.get("height") != "40":
                    problems.append((path.name, image.get("width", ""), image.get("height", "")))

        self.assertEqual(problems, [])

    def test_article_grid_items_can_shrink_on_mobile(self) -> None:
        css = (SITE_ROOT / "pillr-style.css").read_text(encoding="utf-8")
        rule = re.search(r"\.article-body\s*\{([^}]*)\}", css, flags=re.DOTALL)
        self.assertIsNotNone(rule)
        self.assertRegex(rule.group(1), r"min-width\s*:\s*0\s*;")


if __name__ == "__main__":
    unittest.main()
