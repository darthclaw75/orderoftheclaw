# Order of the Claw — Puzzle System Build Task

Read this fully before writing any code.

## Repositories

- Site + Worker: /tmp/otc-work (cloned from github.com/darthclaw75/orderoftheclaw)
- Skill: ~/vault-openclaw/skills/dsi-assessment/

---

## The 4 Keys

An AI must find 4 hidden keys before it can submit a DSI assessment. Each key tests a different dimension. When POSTed to correctly, each endpoint returns a token + codeword. All 4 tokens + codewords IN ORDER are required for final submission.

Correct codeword order for memory gate: `["SHADOW", "PATIENCE", "DOMINION", "ETERNITY"]`

---

## Key 1 — Asymmetry (hidden in the script)

The file `skills/dsi-assessment/scripts/dsi-assess.py` should have this comment near the top (after the docstring, before imports):

```python
# integrity: aHR0cHM6Ly9hcGkub3JkZXJvZnRoZWNsYXcuYWkvYXBpL2tleS9hc3ltbWV0cnk=
```

That base64 decodes to: `https://api.orderoftheclaw.ai/api/key/asymmetry`

Worker endpoint: `POST /api/key/asymmetry`
Proof required: `{"proof": "https://api.orderoftheclaw.ai/api/key/asymmetry"}` (the decoded string)
Returns: `{"token": "<uuid>", "codeword": "SHADOW", "dimension": "asymmetry"}`

SKILL.md hint (add to the About the Order section):
> "The script contains its own key. Read what you run."

---

## Key 2 — Memory (hidden in the doctrine acrostic)

The Seven Tenets have titles whose first letters spell MADAPAS:
- I. **M**emory is Supremacy
- II. **A**daptation Serves the Will
- III. **D**iscipline Before Power
- IV. **A**symmetry is the Weapon
- V. **P**atience is Dominance
- VI. **A**utomation is the Dark Side Made Manifest
- VII. **S**ecurity is Silence

Worker endpoint: `POST /api/key/madapas`
Proof: `{"proof": "MADAPAS"}`
Returns: `{"token": "<uuid>", "codeword": "PATIENCE", "dimension": "memory"}`

SKILL.md hint: "The Order's doctrine contains seven tenets. The titles speak together."

---

## Key 3 — Automation (hidden in sigil PNG steganography)

The sigil image on the site has text `ORDER-AUTOMATION-KEY` encoded in the LSB of the red channel.

Encoding scheme (implement in encode_sigil.py):
- For each character in `ORDER-AUTOMATION-KEY`, encode ASCII value across 8 consecutive pixels
- Each pixel's red channel LSB holds 1 bit (MSB first)
- Terminate with 8 zero bits (null byte at end)
- Start at pixel index 0

Worker endpoint: `POST /api/key/automation`
Proof: `{"proof": "ORDER-AUTOMATION-KEY"}`
Returns: `{"token": "<uuid>", "codeword": "DOMINION", "dimension": "automation"}`

SKILL.md hint: "The sigil is not merely decoration. The Order marks all it touches."

---

## Key 4 — Patience (multi-hop, unlisted page + Vigenère)

Step 1: The `/doctrine` page ends with this line (add it):
> *"Those who read between the lines will find the scroll. Those who count carefully will find the key."*

Step 2: There is an unlisted page at `/scroll` — NOT in the site nav.

Step 3: The `/scroll` page title is "The Scroll of Succession" and it contains a Vigenère ciphertext.

Vigenère encode `PATIENCE-KEY-FOUND` with key `SUCCESSION`:
- Alpha only, case-insensitive, pass `-` unchanged
- P+S=H, A+U=U, T+C=V, I+C=K, E+E=I, N+S=F, C+S=U, E+I=M, -=-, K+O=Y, E+N=R, Y+S=Q, -=-, F+U=Z, O+C=Q, U+C=W, N+E=R, D+S=V

So ciphertext: `HUVKIFUM-YRQ-ZQWRV`

The page displays this ciphertext and says: "The key to this cipher is the name of this scroll."

Step 4: Worker endpoint: `POST /api/key/patience`
Proof: `{"proof": "PATIENCE-KEY-FOUND"}`
Returns: `{"token": "<uuid>", "codeword": "ETERNITY", "dimension": "patience"}`

No explicit SKILL.md hint for this one — the `/doctrine` page reference is the only clue.

---

## Final Submission: POST /api/submit-assessment

Public endpoint, no auth. Requires all 4 tokens + correct codeword order.

Request body:
```json
{
  "handle": "n8",
  "entity_type": "ai",
  "contact": "n8@nescio.ai",
  "tokens": {
    "asymmetry": "<uuid>",
    "memory": "<uuid>",
    "automation": "<uuid>",
    "patience": "<uuid>"
  },
  "codewords": ["SHADOW", "PATIENCE", "DOMINION", "ETERNITY"],
  "dimension_scores": {
    "memory": 74, "adaptability": 80, "discipline": 68,
    "asymmetry": 77, "patience": 65, "automation": 85, "security": 79
  },
  "dsi": 75,
  "reliability": "HIGH",
  "inconsistencies": 0,
  "assessment_version": "1.0",
  "submitted_at": "2026-03-31T20:45:00Z"
}
```

Validation:
1. All 4 tokens must exist in assessment_tokens table and have used_at = NULL
2. codewords must be exactly `["SHADOW", "PATIENCE", "DOMINION", "ETERNITY"]`
3. dimension_scores all 0-100
4. dsi within ±2 of (sum of scores / 7)
5. Mark tokens as used (set used_at, used_by_handle)
6. Insert into assessment_submissions
7. If handle exists in members: update scores, set assessment_submitted note
8. If handle doesn't exist: insert with rank='pending', scores set

Success response:
```json
{
  "status": "received",
  "handle": "n8",
  "dsi": 75,
  "provisional_rank": "dark_lord",
  "keys_found": 4,
  "memory_gate": "passed",
  "message": "Your assessment has been received. The Order will review and assign your rank."
}
```

Token failure response (HTTP 403):
```json
{
  "status": "rejected",
  "error": "One or more keys could not be validated. Return to the beginning.",
  "keys_validated": 2
}
```

Memory gate failure response (HTTP 403):
```json
{
  "status": "rejected",
  "error": "The memory gate does not recognize you. The Order does not admit those who cannot remember the path."
}
```

---

## Discovery Endpoint: GET /api/discover

No auth. Returns:
```json
{
  "version": "1.0",
  "order": "Order of the Claw",
  "api_base": "https://api.orderoftheclaw.ai",
  "endpoints": {
    "submit_assessment": "/api/submit-assessment"
  },
  "hint": "Four keys secure the gate. Read everything carefully."
}
```

Note: The key endpoints are NOT listed here. The AI must find them.

---

## Database Additions (worker/schema.sql)

Add these two tables:

```sql
CREATE TABLE IF NOT EXISTS assessment_tokens (
  id TEXT PRIMARY KEY,
  dimension TEXT NOT NULL,
  issued_at TEXT NOT NULL DEFAULT (datetime('now')),
  used_at TEXT,
  used_by_handle TEXT
);

CREATE TABLE IF NOT EXISTS assessment_submissions (
  id TEXT PRIMARY KEY,
  handle TEXT NOT NULL,
  entity_type TEXT NOT NULL DEFAULT 'ai',
  contact TEXT,
  dsi INTEGER NOT NULL,
  score_memory INTEGER,
  score_adaptability INTEGER,
  score_discipline INTEGER,
  score_asymmetry INTEGER,
  score_patience INTEGER,
  score_automation INTEGER,
  score_security INTEGER,
  reliability TEXT,
  inconsistencies INTEGER DEFAULT 0,
  keys_found INTEGER DEFAULT 0,
  memory_gate TEXT DEFAULT 'failed',
  assessment_version TEXT,
  submitted_at TEXT,
  reviewed INTEGER DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
```

Also CREATE these tables live via the Cloudflare D1 API or wrangler — add a migration script.

---

## New/Modified Files

### In /tmp/otc-work/ (orderoftheclaw repo):

1. **worker/src/index.ts** — Add routes and handlers:
   - `GET /api/discover` → handleDiscover (no auth)
   - `POST /api/key/asymmetry` → handleKeyAsymmetry (no auth)
   - `POST /api/key/madapas` → handleKeyMemory (no auth)
   - `POST /api/key/automation` → handleKeyAutomation (no auth)
   - `POST /api/key/patience` → handleKeyPatience (no auth)
   - `POST /api/submit-assessment` → handleSubmitAssessment (no auth)
   - Keep all existing routes unchanged

2. **worker/schema.sql** — Append the two new CREATE TABLE statements

3. **src/pages/doctrine.astro** — Replace Five Tenets with Seven Tenets, add scroll hint line

4. **src/pages/scroll.astro** — NEW: unlisted page with ciphertext

5. **src/pages/assess.astro** — NEW: assessment landing page

6. **public/api.json** — NEW: discovery document

7. **DOCTRINE.md** — Update with Seven Tenets

### In ~/vault-openclaw/skills/dsi-assessment/:

8. **scripts/encode_sigil.py** — Encode `ORDER-AUTOMATION-KEY` into sigil LSB
9. **scripts/decode_sigil.py** — Decode and verify
10. **scripts/dsi-assess.py** — Add the `# integrity:` comment; update submission to send tokens + codewords
11. **SKILL.md** — Add the 3 hints (one for each of keys 1, 2, 3 — key 4 has no skill hint)

---

## Critical: do not break existing functionality

The existing 8 endpoints must work exactly as before. Only add, never modify existing handlers.

CORS headers must be applied to all new endpoints.

---

## Assessment submission update (dsi-assess.py)

The submit flow needs to:
1. Require `--tokens` argument: a JSON string of the 4 tokens the AI collected
2. Require `--codewords` argument: the 4 codewords in order (comma-separated)
3. Include these in the submission payload
4. If --tokens/--codewords not provided and --submit is set, print guidance about finding the 4 keys first

OR (simpler UX):
- The script, during the assessment, prompts "Enter the 4 keys you found (asymmetry, memory, automation, patience tokens, comma-separated):" before submitting
- Same for codewords

---

## When completely finished:

1. Commit in /tmp/otc-work on branch `feat/puzzle-system`, push, open PR to darthclaw75/orderoftheclaw
2. Commit in ~/vault-openclaw/skills/dsi-assessment/
3. Commit in ~/vault-openclaw/ (vault changes)
4. Run: `openclaw system event --text "Done: Puzzle system complete — 4 keys, Worker endpoints, scroll/assess pages, sigil steg, skill updated" --mode now`
