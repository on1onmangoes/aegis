# 🛡️ Aegis — Multiverse Credential Verification

**Snap a healthcare provider's ID badge → get a live, verified credential graph in seconds.**

Built for the **Cerebras × Google DeepMind Gemma 4** 24-hour hackathon (Track 1 · Multiverse
Agents, Track 3 · Enterprise Impact).

![status](https://img.shields.io/badge/Gemma_4_31B-on_Cerebras-blue) ![speed](https://img.shields.io/badge/~1600-tokens%2Fsec-green) ![platform](https://img.shields.io/badge/macOS-SwiftUI-orange)

---

## What it does

A photo of a provider badge fans out across **four coordinated Gemma 4 31B agents on Cerebras**
plus real authoritative data sources, and assembles a **3-state trust verdict** (VERIFIED /
NEEDS ATTENTION / NOT VERIFIED) with a credential graph — fast enough that the whole multi-agent
pipeline feels instant.

```
                         ┌─ ③ Analyst   (Gemma)  → verified? + score + risk flags
 badge image            │
   │                    ├─ ④ Background (Gemma)  → profile + focus areas
 ① Extractor (Gemma) ───┤
   │  multimodal        ├─ NPI Registry  → license, taxonomy, status (authoritative)
 ② NPI truth            ├─ CMS           → medical school + grad year
                        ├─ PubMed        → real publications
                        ├─ YouTube API   → real related videos
                        ├─ Apple MapKit  → nearby providers
                        └─ ⑤ Matcher (Gemma) → ranks providers vs criteria
                                  ↓
                    World-Tree credential graph + Cerebras speed HUD
```

## Why it's interesting

- **Multimodal Gemma 4 31B** reads the badge image directly (base64), text-only out.
- **4 real coordinated agents** — Extractor, Analyst, Matcher, Background. Multi-agent, no theater.
- **All-real data, zero fabrication** — NPI Registry, CMS Doctors & Clinicians, PubMed,
  YouTube Data API v3, Apple MapKit. (Residency/undergrad honestly omitted — no free
  authoritative source; we never invent them.)
- **Cerebras speed** — ~1,600 tokens/sec, full fan-out in ~4 s wall-clock; the on-screen HUD
  shows per-agent tok/s.
- **3-state trust verdict** with a score — beyond yes/no — and real fraud detection (a
  mismatched badge is flagged, not waved through).

## Where it earns its keep (enterprise continuity)

Verification is easy when there's time. Aegis is built for when there isn't:

- **Disaster privileging** — after an earthquake or hurricane, displaced clinicians must be cleared
  to practice at surge facilities in *minutes*. Aegis verifies each badge against federal sources instantly.
- **Provider relocation & record migration** — re-verify and re-link credentials from one photo when
  clinicians move or EHRs migrate across systems/states.
- **Mergers & acquisitions** — re-credential and de-duplicate *thousands* of providers across a merged
  network; batch-verify against NPI/CMS and flag every discrepancy with a trust score.

## Run it

```bash
# 1. set your keys (CEREBRAS required; YOUTUBE optional for video nodes)
export CEREBRAS_API_KEY=...      # Gemma 4 31B on Cerebras
export YOUTUBE_API_KEY=...       # optional — real related videos

# 2. launch (macOS 13+)
swift run
```

Then drag a badge into the window (or click an example) → **Verify**. Demo badges are
generated from **real public NPI data** + synthetic FLUX portraits (privacy-safe):

```bash
python3 tools/aegis_badge_generator_260629.py
```

## Tech

macOS SwiftUI · Swift Package · no backend · OpenAI-compatible Cerebras Chat Completions
(`gemma-4-31b`, structured outputs, `reasoning_effort`, multimodal image) · NPI/CMS/PubMed/
YouTube/MapKit data sources.

See [README_aegis_260629.md](README_aegis_260629.md) for full setup and
[aegis_user_story_260629.md](aegis_user_story_260629.md) for the product story.
