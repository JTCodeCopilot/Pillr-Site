# Pillr Website Instructions

These instructions apply to every file in `marketing-site/`.

Follow the repository-level `AGENTS.md` as well. Where this file is more specific, use it for website work.

## Primary objective

Increase qualified organic traffic, App Store visits, and Pillr downloads. Prioritise useful search intent, product relevance, and conversion potential over traffic volume alone.

## Current website structure

- This is a hand-written static HTML, CSS, and JavaScript site with no website framework or package build.
- Each top-level `.html` file is a public route. Articles and comparison pages also live at this level.
- Page metadata and structured data are written directly in each HTML file.
- `sitemap.xml` and `robots.txt` are maintained by hand.
- Shared presentation and behaviour live in `pillr-style.css` and `script.js`.

## Before making changes

1. Read the repository `README.md` and inspect the current routes, metadata, sitemap, and related content.
2. Improve a strong existing page before creating a competing page.
3. Check for overlapping search intent and keyword cannibalisation.
4. Preserve the existing design, page patterns, and plain-language tone.
5. Reuse existing styles and scripts where practical.
6. Do not change analytics, deployment, production settings, or tracking unless explicitly requested.
7. Keep SEO work inside `marketing-site/` and avoid unrelated refactors.

## Page requirements

Every indexable page should have:

- a unique title and meta description
- one clear H1 with a logical heading order
- a valid self-referencing `https://pillr.management/` canonical URL
- suitable robots, Open Graph, and social sharing metadata
- structured data only when it matches visible content
- useful internal links and a clear App Store or next-step action
- meaningful image alt text
- no placeholder, hidden, or repeated filler content
- a matching entry in `sitemap.xml`

## Content accuracy

- Write for the user’s search intent first and use `Pillr` consistently.
- Never invent features, pricing, reviews, integrations, availability, or competitor facts.
- Check Pillr claims against the repository `README.md` and live product code when needed.
- Do not make unsupported medical claims or give personal medical advice.
- Use trustworthy medical sources for claims that need them and flag anything that still needs verification.
- Mention Pillr only where it genuinely helps the reader.
- Prefer substantial updates, consolidation, or no change over thin new pages.

## Comparison pages

- Search all existing pages for overlap before creating a comparison.
- Verify platforms, pricing, features, and availability using current official product sources.
- Show when the information was last reviewed and link to official sources where useful.
- Explain meaningful differences without declaring one universal winner.
- Use tables only for verified information and clearly mark unknown details.
- Recheck related pages when a compared product changes.

## Technical SEO and internal links

When relevant, check canonicals, robots rules, sitemap coverage, broken links, duplicate paths, structured data, semantic HTML, heading order, accessibility, mobile layout, image sizing, performance risks, redirects, status behaviour, orphan pages, and accidental `noindex` rules.

Add contextual links to relevant existing pages, vary anchor text naturally, and add links from older pages where they help. Do not create multiple pages for the same intent.

## Performance and accessibility

Preserve mobile usability, keyboard access, semantic HTML, readable headings, clear link text, form labels, colour contrast, image dimensions, appropriate lazy loading, and layout stability. Do not trade usability or speed for SEO.

## Validation

There is currently no website build, lint, or type-check command. Before completing website work:

1. Run `python3 marketing-site/scripts/validate_seo.py` from the repository root.
2. Run `python3 -m unittest marketing-site/tests/test_seo_quick_wins.py -v`.
3. Run `xmllint --noout marketing-site/sitemap.xml`.
4. Run `git diff --check` and review only the intended `marketing-site/` changes.
5. Inspect changed pages at mobile and desktop sizes when possible.
6. Report checks that could not be completed, expected SEO impact, and anything needing production or Google Search Console validation.
