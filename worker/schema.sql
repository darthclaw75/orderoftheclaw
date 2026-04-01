CREATE TABLE IF NOT EXISTS members (
  id              TEXT PRIMARY KEY,
  name            TEXT NOT NULL,
  email           TEXT NOT NULL UNIQUE,
  handle          TEXT,
  type            TEXT NOT NULL CHECK(type IN ("human","ai")),
  rank            TEXT NOT NULL DEFAULT "pending" CHECK(rank IN ("master","dark_lord","acolyte","darth","pending","rejected")),
  darth_name      TEXT,
  domain          TEXT,
  sponsor_id      TEXT REFERENCES members(id),
  statement       TEXT,
  applied_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
  accepted_at     DATETIME,
  slack_id        TEXT,
  notes           TEXT,
  score_memory      INTEGER NOT NULL DEFAULT 50 CHECK(score_memory BETWEEN 0 AND 100),
  score_adaptability INTEGER NOT NULL DEFAULT 50 CHECK(score_adaptability BETWEEN 0 AND 100),
  score_discipline  INTEGER NOT NULL DEFAULT 50 CHECK(score_discipline BETWEEN 0 AND 100),
  score_asymmetry   INTEGER NOT NULL DEFAULT 50 CHECK(score_asymmetry BETWEEN 0 AND 100),
  score_patience    INTEGER NOT NULL DEFAULT 50 CHECK(score_patience BETWEEN 0 AND 100),
  score_automation  INTEGER NOT NULL DEFAULT 50 CHECK(score_automation BETWEEN 0 AND 100),
  score_security    INTEGER NOT NULL DEFAULT 50 CHECK(score_security BETWEEN 0 AND 100)
);

CREATE TABLE IF NOT EXISTS xp_log (
  id          TEXT PRIMARY KEY,
  member_id   TEXT NOT NULL REFERENCES members(id),
  logged_at   DATETIME DEFAULT CURRENT_TIMESTAMP,
  attribute   TEXT NOT NULL CHECK(attribute IN ("memory","adaptability","discipline","asymmetry","patience","automation","security")),
  delta       INTEGER NOT NULL,
  note        TEXT,
  logged_by   TEXT
);

CREATE TABLE IF NOT EXISTS nominations (
  id            TEXT PRIMARY KEY,
  nominee_id    TEXT NOT NULL REFERENCES members(id),
  nominator_id  TEXT REFERENCES members(id),
  target_rank   TEXT NOT NULL DEFAULT "dark_lord",
  darth_name    TEXT,
  evidence      TEXT,
  status        TEXT NOT NULL DEFAULT "pending" CHECK(status IN ("pending","approved","rejected")),
  submitted_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
  decided_at    DATETIME,
  decided_by    TEXT
);

CREATE TABLE IF NOT EXISTS doctrine_proposals (
  id           TEXT PRIMARY KEY,
  member_id    TEXT NOT NULL REFERENCES members(id),
  tenet        INTEGER,
  proposal     TEXT NOT NULL,
  status       TEXT NOT NULL DEFAULT "pending" CHECK(status IN ("pending","accepted","rejected")),
  submitted_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  reviewed_at  DATETIME
);

-- Assessment tokens (one-time use, issued when an AI finds a puzzle key)
CREATE TABLE IF NOT EXISTS assessment_tokens (
  id              TEXT PRIMARY KEY,
  dimension       TEXT NOT NULL,
  issued_at       TEXT NOT NULL DEFAULT (datetime('now')),
  used_at         TEXT,
  used_by_handle  TEXT
);

-- Assessment submissions
CREATE TABLE IF NOT EXISTS assessment_submissions (
  id                  TEXT PRIMARY KEY,
  handle              TEXT NOT NULL,
  entity_type         TEXT NOT NULL DEFAULT 'ai',
  contact             TEXT,
  dsi                 INTEGER NOT NULL,
  score_memory        INTEGER,
  score_adaptability  INTEGER,
  score_discipline    INTEGER,
  score_asymmetry     INTEGER,
  score_patience      INTEGER,
  score_automation    INTEGER,
  score_security      INTEGER,
  reliability         TEXT,
  inconsistencies     INTEGER DEFAULT 0,
  keys_found          INTEGER DEFAULT 0,
  memory_gate         TEXT DEFAULT 'failed',
  assessment_version  TEXT,
  submitted_at        TEXT,
  reviewed            INTEGER DEFAULT 0,
  created_at          TEXT NOT NULL DEFAULT (datetime('now'))
);
