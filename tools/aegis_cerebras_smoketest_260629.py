#!/usr/bin/env python3
# aegis_cerebras_smoketest_260629.py
# Added 260629: Validates the LIVE Cerebras gemma-4-31b contract that the Swift client
# depends on, BEFORE recording the demo. Checks, in order:
#   1) plain chat + reports usage + EXACT time_info field names (the Swift HUD relies on these)
#   2) structured output (response_format json_schema strict)  — Extractor/Analyst/Matcher path
#   3) reasoning_effort=medium                                  — Analyst/Matcher path
#   4) multimodal image input (base64 data URI)                — Extractor path (uses a demo badge)
# Fails loudly; prints what works and what doesn't so we can fix the Swift side if needed.
import base64
import json
import logging
import os
import sys
import urllib.request
from pathlib import Path

logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(levelname)s | %(name)s | %(message)s")
log = logging.getLogger("aegis_smoketest")

ENDPOINT = "https://api.cerebras.ai/v1/chat/completions"
MODEL = "gemma-4-31b"


def call(body: dict, key: str) -> dict:
    req = urllib.request.Request(
        ENDPOINT, data=json.dumps(body).encode(), method="POST",
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json",
                 # Cloudflare (error 1010) bans the default python-urllib UA; send a normal one.
                 "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", "ignore")
        raise RuntimeError(f"HTTP {e.code}: {detail[:500]}")


def main():
    key = os.environ.get("CEREBRAS_API_KEY", "").strip()
    if not key:
        log.error("[FAILURE] CEREBRAS_API_KEY not set. `set -a; source .env_260629; set +a` first.")
        sys.exit(1)

    # 1) Plain chat + time_info inspection ------------------------------------
    log.info("[TEST 1] plain chat + time_info field names")
    r1 = call({"model": MODEL, "messages": [{"role": "user", "content": "Reply with the single word: OK"}],
               "max_completion_tokens": 16}, key)
    content = r1["choices"][0]["message"]["content"]
    log.info(f"  content={content!r}")
    log.info(f"  usage keys      = {list(r1.get('usage', {}).keys())}")
    log.info(f"  time_info keys  = {list(r1.get('time_info', {}).keys())}")
    log.info(f"  time_info       = {r1.get('time_info')}")

    # 2) Structured output ----------------------------------------------------
    log.info("[TEST 2] structured output (json_schema strict)")
    schema = {"type": "object", "additionalProperties": False,
              "required": ["city", "population"],
              "properties": {"city": {"type": "string"}, "population": {"type": "integer"}}}
    r2 = call({"model": MODEL,
               "messages": [{"role": "user", "content": "Return the capital of France and its population."}],
               "response_format": {"type": "json_schema",
                                   "json_schema": {"name": "city_pop", "strict": True, "schema": schema}},
               "max_completion_tokens": 128}, key)
    log.info(f"  structured content = {r2['choices'][0]['message']['content']!r}")

    # 3) reasoning_effort -----------------------------------------------------
    log.info("[TEST 3] reasoning_effort=medium")
    r3 = call({"model": MODEL, "messages": [{"role": "user", "content": "If 3x=12, what is x? Reply with the number."}],
               "reasoning_effort": "medium", "max_completion_tokens": 256}, key)
    log.info(f"  reasoning content = {r3['choices'][0]['message']['content']!r}")

    # 4) Multimodal image input ----------------------------------------------
    log.info("[TEST 4] multimodal image input (base64 data URI)")
    badge = Path(__file__).resolve().parent.parent / "badges_260629" / "rex_adamson_badge_260629.png"
    if not badge.exists():
        log.warning(f"  skipped: demo badge not found at {badge} (run badge generator first)")
    else:
        b64 = base64.b64encode(badge.read_bytes()).decode()
        data_uri = f"data:image/png;base64,{b64}"
        r4 = call({"model": MODEL, "messages": [{"role": "user", "content": [
                    {"type": "text", "text": "What NAME and NPI number are printed on this badge? Reply briefly."},
                    {"type": "image_url", "image_url": {"url": data_uri}}]},
                   ], "max_completion_tokens": 128}, key)
        log.info(f"  vision content = {r4['choices'][0]['message']['content']!r}")

    log.info("[DONE] all live Cerebras checks passed.")


if __name__ == "__main__":
    main()
