#!/usr/bin/env python3
# aegis_badge_generator_260629.py
# Added 260629: Generates synthetic provider ID badges seeded with REAL, PUBLIC NPI
# Registry data, so Aegis verification returns genuine results (no PII, no mock data).
#
# CLAUDE.md compliance:
#   - Deterministic output (fixed seed data, no randomness)
#   - Fails loudly if Pillow is missing (no fallback)
#   - Datestamped output PNGs (_260629)
#
# Usage:  python3 aegis_badge_generator_260629.py
# Output: ./badges_260629/<name>_badge_260629.png  +  one intentionally-mismatched card
import logging
import sys
from pathlib import Path

logging.basicConfig(level=logging.INFO,
                    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s")
logger = logging.getLogger("aegis_badge_generator")

try:
    from PIL import Image, ImageDraw, ImageFont, ImageOps
except ImportError:
    logger.error("[FAILURE] Pillow not installed. Run: pip install Pillow  (NO fallback by design)")
    sys.exit(1)

# Real, public CMS NPI Registry records (verified live 260629). The 'mismatch' card
# intentionally pairs a real NPI with a wrong specialty to demo the Analyst catching fraud.
BADGES = [
    {  # HERO: real NPI + real license number
        "key": "rex_adamson",
        "name": "REX SCOTT ADAMSON, M.D.",
        "credential": "MD",
        "specialty": "Psychiatry",
        "license_no": "G85915",
        "npi": "1134381320",
        "state": "CA",
        "org": "Modesto Psychiatric Associates",
    },
    {
        "key": "mark_levine",
        "name": "MARK DAVID LEVINE, MD",
        "credential": "MD",
        "specialty": "Psychiatry",
        "license_no": "",
        "npi": "1407119571",
        "state": "CA",
        "org": "Manteca Behavioral Health",
    },
    {  # FRAUD DEMO: real NPI 1942866462 (Psychiatry) labelled as a wrong specialty
        "key": "mismatch_demo",
        "name": "DEEPAK KUMAR, MD",
        "credential": "MD",
        "specialty": "Orthopedic Surgery",   # <-- deliberate mismatch vs NPI record
        "license_no": "FAKE00000",            # <-- not on record
        "npi": "1942866462",
        "state": "CA",
        "org": "Fremont Wellness Clinic",
    },
    {  # UChicago Medicine — ties to the Dr. Mario RAG corpus (drmarioRAGChicago250906)
        "key": "nancy_beckman",
        "name": "NANCY J. BECKMAN, Ph.D.",
        "credential": "PhD",
        "specialty": "Clinical Psychology",
        "license_no": "071008565",
        "npi": "1750725495",
        "state": "IL",
        "org": "UChicago Medicine",
    },
    {  # NYC — Gracie Square area (real, verified 260629)
        "key": "devon_addonizio",
        "name": "DEVON K. ADDONIZIO, MD",
        "credential": "MD",
        "specialty": "Psychiatry",
        "license_no": "227039",
        "npi": "1366599805",
        "state": "NY",
        "org": "Gracie Square Hospital",
    },
    {
        "key": "seth_aidinoff",
        "name": "SETH G. AIDINOFF, MD",
        "credential": "MD",
        "specialty": "Psychiatry",
        "license_no": "187128",
        "npi": "1811065782",
        "state": "NY",
        "org": "Gracie Square Hospital",
    },
    {
        "key": "stewart_anderson",
        "name": "STEWART A. ANDERSON, MD",
        "credential": "MD",
        "specialty": "Psychiatry",
        "license_no": "226580",
        "npi": "1326195884",
        "state": "NY",
        "org": "Gracie Square Hospital",
    },
]

W, H = 1000, 700
NAVY = (14, 30, 64)
ACCENT = (40, 110, 220)
WHITE = (255, 255, 255)
GREY = (120, 130, 145)
DARK = (25, 30, 40)


def _font(size, bold=False):
    candidates = [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ]
    for path in candidates:
        if Path(path).exists():
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    return ImageFont.load_default()


PHOTO_BOX = (40, 180, 280, 470)  # x0, y0, x1, y1


def _place_photo(img, d, spec, photo_dir: Path):
    x0, y0, x1, y1 = PHOTO_BOX
    bw, bh = x1 - x0, y1 - y0
    portrait = photo_dir / f"{spec['key']}_portrait_260629.png"
    if portrait.exists():
        # Synthetic FAL portrait: cover-fit into a rounded rectangle.
        photo = ImageOps.fit(Image.open(portrait).convert("RGB"), (bw, bh), method=Image.LANCZOS)
        mask = Image.new("L", (bw, bh), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, bw, bh], radius=16, fill=255)
        img.paste(photo, (x0, y0), mask)
    else:
        d.rounded_rectangle(list(PHOTO_BOX), radius=16, fill=(232, 236, 242))
        d.text((x0 + 80, (y0 + y1) // 2 - 15), "PHOTO", font=_font(22, bold=True), fill=GREY)


def draw_badge(spec: dict, out_path: Path, photo_dir: Path):
    img = Image.new("RGB", (W, H), WHITE)
    d = ImageDraw.Draw(img)

    # Header band
    d.rectangle([0, 0, W, 130], fill=NAVY)
    d.rectangle([0, 130, W, 138], fill=ACCENT)
    d.text((40, 34), spec["org"].upper(), font=_font(34, bold=True), fill=WHITE)
    d.text((40, 84), "PROVIDER IDENTIFICATION", font=_font(20), fill=(170, 190, 220))

    # Photo (synthetic FAL portrait if generated, else placeholder)
    _place_photo(img, d, spec, photo_dir)

    # Fields
    x = 330
    rows = [
        ("NAME", spec["name"]),
        ("CREDENTIAL", spec["credential"]),
        ("SPECIALTY", spec["specialty"]),
        ("LICENSE NO.", spec["license_no"] or "—"),
        ("NPI", spec["npi"]),
        ("STATE", spec["state"]),
    ]
    y = 185
    for label, value in rows:
        d.text((x, y), label, font=_font(16, bold=True), fill=ACCENT)
        d.text((x, y + 22), value, font=_font(28, bold=True), fill=DARK)
        y += 78

    # Footer
    d.rectangle([0, H - 50, W, H], fill=NAVY)
    d.text((40, H - 38), "Issued for credential verification demonstration · Aegis 260629",
           font=_font(15), fill=(170, 190, 220))

    img.save(out_path, "PNG")
    logger.info(f"[OUTPUT] wrote {out_path.name}")


def main():
    out_dir = Path(__file__).resolve().parent.parent / "badges_260629"
    out_dir.mkdir(parents=True, exist_ok=True)
    photo_dir = out_dir / "photos"
    logger.info(f"[ENTRY] generating {len(BADGES)} synthetic badges into {out_dir}")
    for spec in BADGES:
        draw_badge(spec, out_dir / f"{spec['key']}_badge_260629.png", photo_dir)
    logger.info("[DONE] badges ready. Drag one into the Aegis window to verify.")


if __name__ == "__main__":
    main()
