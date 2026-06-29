#!/usr/bin/env python3
# aegis_portrait_generator_260629.py
# Added 260629: Generates SYNTHETIC ID-badge portraits via FAL (fal-ai/flux/schnell),
# matching CLAUDE.md image-gen routing (FAL for image generation). Faces are fully
# synthetic (no real person) -> privacy-safe demo assets.
#
#   - Reads FAL_KEY from env (fail loudly if missing, NO fallback)
#   - One portrait per badge identity, saved to ../badges_260629/photos/
#
# Usage:  set -a; source .env_260629; set +a; python3 tools/aegis_portrait_generator_260629.py
import json
import logging
import os
import sys
import urllib.request
from pathlib import Path

logging.basicConfig(level=logging.INFO,
                    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s")
logger = logging.getLogger("aegis_portrait_generator")

FAL_ENDPOINT = "https://fal.run/fal-ai/flux/schnell"

# Synthetic, generic descriptions aligned to each badge identity.
PORTRAITS = [
    ("rex_adamson",
     "professional ID badge headshot photo of a 55 year old American man, short gray hair, "
     "clean shaven, neutral confident expression, wearing a collared shirt, plain light gray "
     "studio background, evenly lit corporate portrait, sharp focus, passport photo style"),
    ("mark_levine",
     "professional ID badge headshot photo of a 45 year old American man, dark brown hair, "
     "thin-rimmed glasses, neutral expression, wearing a collared shirt, plain light gray "
     "studio background, evenly lit corporate portrait, sharp focus, passport photo style"),
    ("mismatch_demo",
     "professional ID badge headshot photo of a 40 year old South Asian man, black hair, "
     "clean shaven, neutral expression, wearing a collared shirt, plain light gray studio "
     "background, evenly lit corporate portrait, sharp focus, passport photo style"),
    ("nancy_beckman",
     "professional ID badge headshot photo of a 55 year old American woman, shoulder-length "
     "blonde-gray hair, warm neutral expression, wearing a blazer, plain light gray studio "
     "background, evenly lit corporate portrait, sharp focus, passport photo style"),
    ("devon_addonizio",
     "professional ID badge headshot photo of a 40 year old American woman, dark hair pulled "
     "back, neutral expression, wearing a blazer, plain light gray studio background, evenly "
     "lit corporate portrait, sharp focus, passport photo style"),
    ("seth_aidinoff",
     "professional ID badge headshot photo of a 50 year old American man, short brown hair, "
     "neutral expression, wearing a collared shirt and tie, plain light gray studio "
     "background, evenly lit corporate portrait, sharp focus, passport photo style"),
    ("stewart_anderson",
     "professional ID badge headshot photo of a 60 year old American man, gray hair, "
     "thin-rimmed glasses, neutral expression, wearing a collared shirt, plain light gray "
     "studio background, evenly lit corporate portrait, sharp focus, passport photo style"),
]


def generate(prompt: str, fal_key: str) -> bytes:
    body = json.dumps({
        "prompt": prompt,
        "image_size": "portrait_4_3",
        "num_images": 1,
        "num_inference_steps": 4,
        "enable_safety_checker": True,
    }).encode("utf-8")
    req = urllib.request.Request(
        FAL_ENDPOINT, data=body, method="POST",
        headers={"Authorization": f"Key {fal_key}", "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=120) as resp:
        payload = json.loads(resp.read())
    images = payload.get("images") or []
    if not images or "url" not in images[0]:
        raise RuntimeError(f"FAL returned no image url: {json.dumps(payload)[:300]}")
    url = images[0]["url"]
    with urllib.request.urlopen(url, timeout=120) as img_resp:
        return img_resp.read()


def main():
    fal_key = os.environ.get("FAL_KEY", "").strip()
    if not fal_key:
        logger.error("[FAILURE] FAL_KEY not set. `set -a; source .env_260629; set +a` first. NO fallback.")
        sys.exit(1)

    out_dir = Path(__file__).resolve().parent.parent / "badges_260629" / "photos"
    out_dir.mkdir(parents=True, exist_ok=True)
    logger.info(f"[ENTRY] generating {len(PORTRAITS)} synthetic portraits via FAL flux/schnell")

    for key, prompt in PORTRAITS:
        logger.info(f"[MODEL] fal-ai/flux/schnell for {key}")
        try:
            data = generate(prompt, fal_key)
        except Exception as exc:
            logger.error(f"[FAILURE] portrait '{key}' failed: {type(exc).__name__} - {exc}")
            sys.exit(1)
        out_path = out_dir / f"{key}_portrait_260629.png"
        out_path.write_bytes(data)
        logger.info(f"[OUTPUT] wrote {out_path.name} ({len(data)} bytes)")

    logger.info("[DONE] portraits ready. Re-run aegis_badge_generator_260629.py to embed them.")


if __name__ == "__main__":
    main()
