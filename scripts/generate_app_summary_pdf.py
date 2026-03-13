#!/usr/bin/env python3
import os
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEPS = ROOT / "tmp" / "pdfs" / ".deps"
if DEPS.exists():
    sys.path.insert(0, str(DEPS))

from reportlab.lib import colors
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import inch
from reportlab.pdfbase.pdfmetrics import stringWidth
from reportlab.platypus import Paragraph
from reportlab.pdfgen import canvas


PAGE_WIDTH, PAGE_HEIGHT = letter
MARGIN = 0.52 * inch
GUTTER = 0.28 * inch
CONTENT_WIDTH = PAGE_WIDTH - (2 * MARGIN)
COL_WIDTH = (CONTENT_WIDTH - GUTTER) / 2

OUTPUT_DIR = ROOT / "output" / "pdf"
OUTPUT_PATH = OUTPUT_DIR / "pillr-app-summary.pdf"


TITLE = "Pillr"
SUBTITLE = "One-page app summary based only on repo evidence"

WHAT_IT_IS = (
    "Pillr is an iPhone medication tracker built with SwiftUI. "
    "The repo shows dose logging, reminders, ADHD-focused timing tools, "
    "history views, and optional iCloud sync."
)

WHO_ITS_FOR = (
    "People managing daily medications, especially ADHD users who want "
    "reminders, dose history, refill tracking, and simple daily check-ins."
)

FEATURES = [
    "Add medications with schedules, notes, icons, dose amounts, and pill counts.",
    "Send reminders, overdue badges, snoozes, follow-up reminders, and refill alerts.",
    "Log taken or skipped doses and review or export medication history.",
    "Show stimulant focus windows and daily reflection check-ins.",
    "Check medication interactions with an AI-powered tool and save the results.",
    "Optionally sync medications, logs, and interaction records to private iCloud.",
    "Offer premium unlocks, app lock, and optional Apple Health snapshots.",
]

ARCHITECTURE = [
    "UI: SwiftUI screens for My Meds, History, Check-Ins, Focus, and Settings.",
    "App state: MedicationStore, InteractionStore, UserSettings, and StoreManager.",
    "Local data: medications, logs, settings, and interaction history saved in UserDefaults.",
    "Device services: NotificationManager handles reminders and badges; HealthKitManager reads steps, distance, and heart rate; LocalAuthentication supports app lock.",
    "Sync: CloudKitMedicationSync mirrors medications, logs, and interaction records to the user's private iCloud database.",
    "External services found in repo: AIProxy/OpenAI for interaction checks and reflection summaries, TelemetryDeck analytics, and TikTok Business SDK startup.",
    "Custom backend owned by this repo: Not found in repo.",
]

RUN_STEPS = [
    "Open Pillr.xcodeproj in Xcode.",
    "Choose the shared Pillr scheme and an iPhone simulator.",
    "Press Run to build and launch the app.",
    "Swift package setup is included in the project.",
    "Exact signing and service setup for iCloud, notifications, and Apple Health: Not found in repo.",
]


def make_paragraph_style(name: str, font_name: str, font_size: int, leading: float, color):
    return ParagraphStyle(
        name=name,
        fontName=font_name,
        fontSize=font_size,
        leading=leading,
        textColor=color,
        spaceAfter=0,
        spaceBefore=0,
    )


BODY = make_paragraph_style("body", "Helvetica", 9.3, 11.2, colors.HexColor("#1F2A23"))
BODY_BOLD = make_paragraph_style("body_bold", "Helvetica-Bold", 9.3, 11.2, colors.HexColor("#1F2A23"))
SMALL = make_paragraph_style("small", "Helvetica", 8.2, 10.0, colors.HexColor("#5D6A61"))
SECTION = make_paragraph_style("section", "Helvetica-Bold", 11.2, 12.8, colors.HexColor("#314038"))


def draw_wrapped_text(c: canvas.Canvas, text: str, x: float, y: float, width: float, style: ParagraphStyle):
    para = Paragraph(text, style)
    _, height = para.wrap(width, PAGE_HEIGHT)
    para.drawOn(c, x, y - height)
    return y - height


def draw_bullets(c: canvas.Canvas, items, x: float, y: float, width: float, style: ParagraphStyle):
    bullet_indent = 9
    for item in items:
        bullet_width = stringWidth("-", style.fontName, style.fontSize)
        c.setFillColor(style.textColor)
        c.setFont(style.fontName, style.fontSize)
        c.drawString(x, y - style.fontSize + 1, "-")
        para = Paragraph(item, style)
        _, height = para.wrap(width - bullet_indent - bullet_width, PAGE_HEIGHT)
        para.drawOn(c, x + bullet_indent, y - height)
        y -= height + 4
    return y


def section_header(c: canvas.Canvas, title: str, x: float, y: float):
    c.setFillColor(SECTION.textColor)
    c.setFont(SECTION.fontName, SECTION.fontSize)
    c.drawString(x, y, title)
    return y - 14


def draw_top_band(c: canvas.Canvas):
    c.setFillColor(colors.HexColor("#324239"))
    c.roundRect(MARGIN, PAGE_HEIGHT - 1.55 * inch, CONTENT_WIDTH, 1.0 * inch, 18, fill=1, stroke=0)
    c.setFillColor(colors.white)
    c.setFont("Helvetica-Bold", 23)
    c.drawString(MARGIN + 18, PAGE_HEIGHT - 1.0 * inch, TITLE)
    c.setFont("Helvetica", 10.2)
    c.drawString(MARGIN + 18, PAGE_HEIGHT - 1.25 * inch, SUBTITLE)
    c.setFillColor(colors.HexColor("#B7C8AE"))
    c.setFont("Helvetica", 8.6)
    c.drawRightString(PAGE_WIDTH - MARGIN - 18, PAGE_HEIGHT - 1.0 * inch, "Generated March 13, 2026")


def draw_info_card(c: canvas.Canvas, title: str, text: str, x: float, y: float, width: float, fill: str):
    height = 88
    c.setFillColor(colors.HexColor(fill))
    c.roundRect(x, y - height, width, height, 14, fill=1, stroke=0)
    c.setFillColor(colors.HexColor("#314038"))
    c.setFont("Helvetica-Bold", 10.2)
    c.drawString(x + 14, y - 18, title)
    draw_wrapped_text(c, text, x + 14, y - 28, width - 28, BODY)


def generate_pdf():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    c = canvas.Canvas(str(OUTPUT_PATH), pagesize=letter)
    c.setTitle("Pillr App Summary")

    c.setFillColor(colors.HexColor("#F4F6F2"))
    c.rect(0, 0, PAGE_WIDTH, PAGE_HEIGHT, fill=1, stroke=0)

    draw_top_band(c)

    card_top = PAGE_HEIGHT - 1.82 * inch
    card_gap = 0.16 * inch
    card_width = (CONTENT_WIDTH - card_gap) / 2
    draw_info_card(c, "What it is", WHAT_IT_IS, MARGIN, card_top, card_width, "#E7EEE2")
    draw_info_card(c, "Who it's for", WHO_ITS_FOR, MARGIN + card_width + card_gap, card_top, card_width, "#EAF1E5")

    left_x = MARGIN
    right_x = MARGIN + COL_WIDTH + GUTTER
    columns_top = PAGE_HEIGHT - 3.05 * inch

    left_y = section_header(c, "What it does", left_x, columns_top)
    left_y = draw_bullets(c, FEATURES, left_x, left_y, COL_WIDTH, BODY)

    right_y = section_header(c, "How it works", right_x, columns_top)
    right_y = draw_bullets(c, ARCHITECTURE, right_x, right_y, COL_WIDTH, BODY)

    bottom_y = min(left_y, right_y) - 8
    c.setStrokeColor(colors.HexColor("#D3DDD0"))
    c.setLineWidth(1)
    c.line(MARGIN, bottom_y, PAGE_WIDTH - MARGIN, bottom_y)

    run_y = bottom_y - 18
    run_y = section_header(c, "How to run", MARGIN, run_y)
    draw_bullets(c, RUN_STEPS, MARGIN, run_y, CONTENT_WIDTH, BODY)

    footer_text = "Sources used: SwiftUI views, stores, services, entitlements, package settings, and shared scheme in this repo."
    draw_wrapped_text(c, footer_text, MARGIN, 0.73 * inch, CONTENT_WIDTH, SMALL)

    c.showPage()
    c.save()


if __name__ == "__main__":
    generate_pdf()
    print(OUTPUT_PATH)
