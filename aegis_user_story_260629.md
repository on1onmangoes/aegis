# Aegis — User Story (260629)

## The one-liner
**Snap a provider's ID badge → know in seconds whether they're real, and get a ranked
shortlist of verified providers that actually match your needs.**

---

## Persona
**Maya, a care coordinator** at a behavioral-health network. A new patient brings a referral
to "Dr. ___, MD, Psychiatry." Maya must (1) confirm the provider is genuinely licensed before
booking, and (2) if the patient needs someone *else* (wrong specialty, too far, not taking new
patients), find the best verified alternative — fast, while the patient is still on the phone.

Today this is 20 minutes across the NPI website, a state board lookup, and Google Maps.
Aegis does it in seconds.

---

## The story (mapped to the agent realms)

> Maya drags the badge photo into Aegis and clicks **Verify**.

1. **Realm 1 — Extractor** (`gemma-4-31b`, multimodal): reads the badge image and pulls
   `{name, credential, license, NPI, state, specialty}`. *(seconds)*
2. **Realm 2 — NPI Registry** (authoritative): confirms the NPI, license, taxonomy, status,
   and practice address against the public CMS source of truth.
3. **Realm 3 — Analyst** (`gemma-4-31b`, reasoning): compares the badge's claims against the
   truth → **VERIFIED** or **NEEDS REVIEW**, with discrepancies and risk flags.
4. **Realm 4 — Search Kit** (native MapKit): finds nearby wellness providers around the
   verified practice address — the **options**.
5. **Realm 5 — Matcher** (`gemma-4-31b`, reasoning): scores each option against Maya's
   **criteria** and returns a ranked shortlist with one-line reasons.

> Aegis shows: a green **VERIFIED** verdict, the credential graph (the World Tree), and a
> ranked list — *"3 verified-area matches for: child psychiatry · ≤3 km · accepting patients."*

Because every Gemma call runs on **Cerebras**, the five realms feel instantaneous — the
fan-out (Analyst ∥ Search ∥ Matcher) returns before Maya finishes her sentence. That speed is
the difference between "I'll call you back" and "booked while you wait."

---

## The matching layer (Realm 5) — how it works

**Options ✕ Criteria → ranked matches.** Deterministic inputs, model-scored output.

```
OPTIONS  (from Realm 4 + the verified provider)
  [{ name, specialty, distance_km, address }, ...]

CRITERIA (what the patient needs — a simple struct the UI exposes)
  { needed_specialty: "Child Psychiatry",
    max_distance_km: 3,
    must_accept_new_patients: true,
    modality: "in-person" }

MATCHER AGENT (gemma-4-31b, strict JSON, reasoning_effort: medium)
  → [{ name, score: 0..1, fits: [..criteria met..], gaps: [..criteria missed..], reason }]
    sorted by score
```

- **Why a model and not just a filter?** A filter is brittle ("Child Psychiatry" ≠
  "Psychiatry, Child & Adolescent"). Gemma reasons over near-synonyms, partial fits, and
  trade-offs (closer but adult-only vs. farther but exact-match), and explains the ranking.
- **No hallucinated options** — the Matcher may only *rank* the real options from Realm 4;
  it never invents providers (CLAUDE.md: no pattern matching, no fallback).
- **FBQ tie-in:** verification = yes/no; matching = *Increase from Yes/No to Multiple
  Options* (Fishbach) — Aegis moves the user from "is this one real?" to "here are your best
  real choices."

---

## Tracks this serves
- **Track 1 (Multiverse Agents):** 5 coordinated agents, multimodal input, visible Cerebras speed.
- **Track 3 (Enterprise):** credential verification + referral matching — a real
  knowledge-management / intake workflow with production value.

---

## Demo beat (for the 60s video)
1. Drag `rex_adamson` → **VERIFIED**, graph blooms, speed HUD lights up.
2. Drag `mismatch_demo` → **NEEDS REVIEW**, Analyst catches the specialty fraud.
3. Set criteria `Child Psychiatry · ≤3 km · accepting` → Matcher re-ranks the nearby verified
   providers with reasons. *"Real, and the right fit — in seconds."*
