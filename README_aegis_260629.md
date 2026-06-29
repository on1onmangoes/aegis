# Aegis — Multiverse Credential Verification (Cerebras × Gemma 4 Hackathon, 260629)

**One line:** Drop a provider ID badge → multimodal Gemma 4 31B reads it → multiple agent
"realms" verify it in parallel against the authoritative NPI Registry → a live credential
**graph** assembles in seconds, with a Cerebras tokens/sec HUD proving the speed.

Targets **Track 1 (Multiverse Agents)** — multimodal + genuine multi-agent fan-out + Cerebras
speed — and doubles as **Track 3 (Enterprise)**: credential verification / fraud detection.

---

## The Multiverse (agent realms)

| Realm | Engine | Job |
|-------|--------|-----|
| 1 · Extractor | `gemma-4-31b` (multimodal, strict JSON) | Read the badge image → `{name, credential, license_no, npi, state, specialty}` |
| 2 · NPI Registry | CMS public API (no key) | Authoritative truth: license, taxonomy, status, address |
| 3 · Analyst | `gemma-4-31b` (reasoning, strict JSON) | Compare claims vs truth → verdict + discrepancies + risk flags |
| 4 · MapKit | native `MKLocalSearch` (no key) | Nearby wellness providers around the verified address |

Realms 3 + 4 run **in parallel** — Cerebras makes the fan-out feel instant (the demo point).
The graph is assembled **deterministically** from authoritative data (the model never invents
the graph structure — CLAUDE.md: no pattern-matching, no fallback).

---

## Setup (one-time)

1. **Secrets** live in `.env_260629` (GITIGNORED — copied from VoiceAgentRAG/.env.local).
   Holds `CEREBRAS_API_KEY` (required), `FAL_KEY` (portraits), `BRAVE_API_KEY` (optional web search).
   Load it into the shell before anything else:
   ```bash
   set -a; source .env_260629; set +a
   ```
   The app reads `CEREBRAS_API_KEY` from the environment and **fails loudly** if missing.

2. **Generate demo badges** (real public NPI data + synthetic FAL portraits, no PII):
   ```bash
   pip install Pillow
   python3 tools/aegis_portrait_generator_260629.py   # FAL flux → synthetic ID photos
   python3 tools/aegis_badge_generator_260629.py       # embeds photos into the badges
   # → badges_260629/rex_adamson_badge_260629.png   (hero: real NPI + real license)
   #   badges_260629/mark_levine_badge_260629.png
   #   badges_260629/mismatch_demo_badge_260629.png  (fraud demo: wrong specialty)
   ```

---

## Run

Launch from a terminal that has the env loaded (so the GUI inherits `CEREBRAS_API_KEY`):

```bash
cd "Aegis_260629"
set -a; source .env_260629; set +a
swift run
```

A macOS window opens. **Drag a badge PNG into the drop zone → Verify Credentials.**
Watch the speed HUD light up per agent and the credential graph assemble.

> Prefer Xcode? `File → New → macOS App`, then drag `Sources/Aegis/*.swift` into the target
> and add the `CEREBRAS_API_KEY` env var to the scheme. (SPM `swift run` is the fastest path.)

---

## Demo script (60s video)

1. Drag **rex_adamson** badge → Verify → green **VERIFIED**, NPI 1134381320 + license G85915,
   graph blooms, HUD shows ~hundreds of tok/s. **Total wall-clock in the status bar.**
2. Drag **mismatch_demo** badge → Analyst (reasoning) flags the **specialty mismatch** →
   red **NEEDS REVIEW**. Shows the agents catch fraud, not just OCR.
3. (Optional, recommended by FAQ) side-by-side vs a GPU provider on the same extract call to
   highlight the latency gap.

Protect privacy when recording: no API keys / notifications on screen.

---

## Files (CLAUDE.md datestamped)

```
Aegis_260629/
├── Package.swift
├── README_aegis_260629.md
├── Sources/Aegis/
│   ├── aegis_app_260629.swift                 # @main, window/activation
│   ├── aegis_content_view_260629.swift        # two-pane UI, drop zone, verdict
│   ├── aegis_graph_view_260629.swift          # radial credential graph (Canvas)
│   ├── aegis_speed_hud_260629.swift           # Cerebras tokens/sec HUD
│   ├── aegis_agents_orchestrator_260629.swift # the Multiverse + graph assembly
│   ├── aegis_cerebras_client_260629.swift     # gemma-4-31b, multimodal, structured, time_info
│   ├── aegis_npi_registry_client_260629.swift # authoritative verification
│   ├── aegis_mapkit_search_260629.swift       # native nearby-provider search
│   ├── aegis_models_260629.swift              # Codable contracts
│   ├── aegis_image_util_260629.swift          # NSImage → base64 JPEG data URI
│   └── aegis_logging_260629.swift             # [ENTRY]/[MODEL]/[LATENCY]/[FAILURE]
└── tools/
    └── aegis_badge_generator_260629.py        # synthetic badges from real NPI data
```
