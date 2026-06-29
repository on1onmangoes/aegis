# Aegis — Hackathon Submission Pack (260629)

Cerebras × Google DeepMind Gemma 4 24h Hackathon. Submit to **Track 1 (Multiverse Agents)**
and **Track 3 (Enterprise Impact)**; post the X version for **Track 2 (People's Choice)**.

> **FILL IN before posting:** Team Members (Discord @handles) · GitHub URL · Demo video file.

---

## Project Name
**Aegis — Multiverse Credential Verification**

## Tagline
*Is your doctor real? Verify it at the speed of thought.*

---

## Track 1 — Multiverse Agents (Discord: #g4hackathon-multiverse-agents)

**Project Name:** Aegis
**Team Members:** @on1onmangoes_63221 (Amit · mangoes.ai), @kushagrayadv15 (Kushagra Yadav), Nalin Prabhat (Discord @ pending)
**Project Description:**
> Aegis turns a photo of a healthcare provider's ID badge into a live, verified credential
> graph in seconds. Four coordinated **Gemma 4 31B** agents on **Cerebras** — Extractor
> (multimodal), Analyst, Background, and Matcher — read the badge, cross-check it against
> authoritative public sources (NPI Registry, CMS, PubMed, YouTube, Apple Maps), and return a
> three-state trust verdict plus a ranked shortlist of matching providers. Because every agent
> runs on Cerebras, the whole multi-agent fan-out finishes in ~4 seconds at **1,600+ tokens/sec**,
> turning credential verification from a 20-minute manual chore into an instant, explainable graph.

**GitHub Repository:** https://github.com/____/aegis
**Demo Video:** (attached)

---

## Track 3 — Enterprise Impact (Discord: #g4hackathon-enterprise-impact)

**Project Name:** Aegis
**Team Members:** @on1onmangoes_63221 (Amit · mangoes.ai), @kushagrayadv15 (Kushagra Yadav), Nalin Prabhat (Discord @ pending)
**Project Description:**
> Aegis is an enterprise credential-verification and referral tool for healthcare intake and
> compliance teams. From a single badge photo, multimodal **Gemma 4 31B on Cerebras** extracts
> the claimed credentials, an Analyst agent cross-checks them against the authoritative NPI
> Registry and CMS records to flag fraud as **VERIFIED / NEEDS ATTENTION / NOT VERIFIED** with a
> trust score, and a Matcher agent ranks nearby in-network providers against intake criteria.
> Every check is grounded in real public data (no hallucinated results) and the full pipeline
> returns in seconds thanks to Cerebras — making it deployable for real-time patient intake,
> provider onboarding, and anti-fraud screening.

**GitHub Repository:** https://github.com/____/aegis
**Demo Video:** (attached)

---

## Track 2 — People's Choice (X/Twitter, then post link in #g4hackathon-people-choice)

**X post draft:**
> Meet Aegis 🛡️ — snap a doctor's ID badge, get a VERIFIED credential graph in ~4 seconds.
>
> 4 @googlegemma Gemma 4 31B agents on @Cerebras (1,600+ tok/s) cross-check NPI, CMS, PubMed &
> YouTube — catching fake credentials before they slip through.
>
> Multimodal + multi-agent + real data. No GPUs were harmed. 👇
> #Gemma4 #Cerebras
> [video]

*(No paid promotion — organic only, per Track 2 rules.)*

---

## 60-second demo video — shot list

| Time | Shot | On screen |
|---|---|---|
| 0–7s | Hook | "Is your doctor real?" → drag **Beckman (UChicago)** badge into Aegis |
| 7–20s | Click **Verify** | 4-agent HUD lights up — **1,600+ tok/s**, ~4s wall clock → **VERIFIED 100%** |
| 20–38s | Graph blooms | Pan the World Tree: NPI ✓, license, **med school (CMS)**, **4 PubMed papers**, **4 real YouTube videos**, focus areas |
| 38–48s | Fraud catch | Load **Kumar (mismatch)** → Analyst flags specialty mismatch → **NEEDS ATTENTION / NOT VERIFIED** |
| 48–56s | Matcher | Set criteria → ranked shortlist with reasons/gaps (honest scoring) |
| 56–60s | Close | Tagline + "4 Gemma agents on Cerebras · all real data" |

**Tips (per FAQ):**
- Show the **speed HUD** prominently — it *is* the "Show Cerebras speed" criterion.
- Optional but recommended: a 3-second **side-by-side vs a GPU provider** on the same extract.
- Privacy: hide notifications, API keys, other tabs while recording (the env file is gitignored).
- Keep it ≤60s.

---

## What to highlight to judges (talking points)
- **Multimodal Gemma 4 31B**: reads the badge image directly (base64), text-only out.
- **4 real coordinated agents** (Extractor, Analyst, Background, Matcher) — multi-agent, no theater.
- **All-real data**: NPI Registry, CMS Doctors & Clinicians, PubMed, YouTube Data API, Apple Maps. No fabrication; residency/undergrad honestly omitted (no free authoritative source).
- **Cerebras speed**: ~1,600 tok/s, full fan-out in ~4s — parallel agents feel instant.
- **3-state trust verdict** with score — beyond yes/no.
- **Fraud detection**: the mismatch card demonstrates real risk flagging.
