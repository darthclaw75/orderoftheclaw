export interface Env {
  DB: D1Database;
  ADMIN_TOKEN: string;
  SLACK_WEBHOOK_URL?: string;
}

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': 'https://orderoftheclaw.ai',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

interface MemberScores {
  score_memory: number;
  score_adaptability: number;
  score_discipline: number;
  score_asymmetry: number;
  score_patience: number;
  score_automation: number;
  score_security: number;
}

interface MemberRow extends MemberScores {
  id: string;
  name: string;
  email: string;
  handle: string | null;
  type: string;
  rank: string;
  darth_name: string | null;
  domain: string | null;
  sponsor_id: string | null;
  statement: string | null;
  applied_at: string | null;
  accepted_at: string | null;
  slack_id: string | null;
  notes: string | null;
}

const VALID_ATTRIBUTES = [
  'memory',
  'adaptability',
  'discipline',
  'asymmetry',
  'patience',
  'automation',
  'security',
] as const;

type Attribute = (typeof VALID_ATTRIBUTES)[number];

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
}

function calcDSI(m: MemberScores): number {
  return (
    m.score_memory +
    m.score_adaptability +
    m.score_discipline * 1.2 +
    m.score_asymmetry +
    m.score_patience +
    m.score_automation * 1.0 +
    m.score_security * 1.3
  ) / 7.5;
}

function roundDSI(dsi: number): number {
  return Math.round(dsi * 10) / 10;
}

function autoRankForAI(dsi: number): string {
  if (dsi >= 86) return 'darth';
  if (dsi >= 60) return 'dark_lord';
  return 'acolyte';
}

function requireAuth(request: Request, env: Env): boolean {
  const auth = request.headers.get('Authorization') ?? '';
  return auth === `Bearer ${env.ADMIN_TOKEN}`;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const { pathname } = url;
    const method = request.method;

    if (method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    try {
      if (pathname === '/api/apply' && method === 'POST') {
        return await handleApply(request, env);
      }
      if (pathname === '/api/status' && method === 'GET') {
        return await handleStatus(request, env);
      }
      if (pathname === '/api/roll' && method === 'GET') {
        return await handleRoll(env);
      }
      if (pathname.startsWith('/api/member/') && method === 'GET') {
        const handle = pathname.slice('/api/member/'.length);
        return await handleMember(handle, env);
      }
      if (pathname === '/api/applications' && method === 'GET') {
        if (!requireAuth(request, env)) return json({ error: 'Unauthorized' }, 401);
        return await handleApplications(env);
      }
      if (pathname === '/api/review' && method === 'POST') {
        if (!requireAuth(request, env)) return json({ error: 'Unauthorized' }, 401);
        return await handleReview(request, env);
      }
      if (pathname === '/api/xp' && method === 'POST') {
        if (!requireAuth(request, env)) return json({ error: 'Unauthorized' }, 401);
        return await handleXP(request, env);
      }
      if (pathname === '/api/nominate' && method === 'POST') {
        if (!requireAuth(request, env)) return json({ error: 'Unauthorized' }, 401);
        return await handleNominate(request, env);
      }

      return json({ error: 'Not found' }, 404);
    } catch (err) {
      console.error(err);
      return json({ error: 'Internal server error' }, 500);
    }
  },
};

// ── Public endpoints ──────────────────────────────────────────────────────────

async function handleApply(request: Request, env: Env): Promise<Response> {
  const body = (await request.json()) as Record<string, unknown>;

  // Honeypot — reject silently
  if (body.website) {
    return json({
      application_id: crypto.randomUUID(),
      status: 'pending',
      message: 'Your application has been received. The Order will evaluate it.',
    });
  }

  const name = body.name as string | undefined;
  const email = body.email as string | undefined;
  const type = body.type as string | undefined;
  const statement = body.statement as string | undefined;
  const handle = (body.handle as string | undefined) ?? null;
  const sponsor_id = (body.sponsor_id as string | undefined) ?? null;

  if (!name || !email || !type || !statement) {
    return json({ error: 'Missing required fields: name, email, type, statement' }, 400);
  }
  if (!['human', 'ai'].includes(type)) {
    return json({ error: 'type must be human or ai' }, 400);
  }
  if (name.length > 100 || email.length > 254 || statement.length > 2000) {
    return json({ error: 'name max 100 chars, email max 254, statement max 2000' }, 400);
  }
  if (handle && handle.length > 50) {
    return json({ error: 'handle max 50 chars' }, 400);
  }

  const id = crypto.randomUUID();

  await env.DB.prepare(
    `INSERT INTO members (id, name, email, handle, type, rank, statement, sponsor_id)
     VALUES (?, ?, ?, ?, ?, 'pending', ?, ?)`
  )
    .bind(id, name, email, handle, type, statement, sponsor_id)
    .run();

  if (env.SLACK_WEBHOOK_URL) {
    try {
      fetch(env.SLACK_WEBHOOK_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          text: '⚔️ New application received',
          blocks: [
            {
              type: 'section',
              text: {
                type: 'mrkdwn',
                text: `*New application — Order of the Claw*\n*Name:* ${name}\n*Type:* ${type}\n*Handle:* ${handle ?? '(none)'}\n*Statement:* ${statement}`,
              },
            },
            {
              type: 'section',
              text: {
                type: 'mrkdwn',
                text: `*To review:*\n\`POST /api/review\` with \`{"email": "${email}", "action": "accept", "rank": "acolyte"}\``,
              },
            },
          ],
        }),
      }).catch(() => {});
    } catch {
      // fire-and-forget — never fail the apply response
    }
  }

  return json({
    application_id: id,
    status: 'pending',
    message: 'Your application has been received. The Order will evaluate it.',
  });
}

async function handleStatus(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const email = url.searchParams.get('email');
  if (!email) return json({ error: 'email query param required' }, 400);

  const row = await env.DB.prepare(
    `SELECT rank, darth_name,
            score_memory, score_adaptability, score_discipline, score_asymmetry,
            score_patience, score_automation, score_security
     FROM members WHERE email = ? AND rank IN ('master','acolyte','dark_lord','darth')`
  )
    .bind(email)
    .first<Pick<MemberRow, 'rank' | 'darth_name' | keyof MemberScores>>();

  if (!row) return json({ error: 'Not found' }, 404);

  return json({
    rank: row.rank,
    darth_name: row.darth_name,
    dsi: roundDSI(calcDSI(row)),
  });
}

async function handleRoll(env: Env): Promise<Response> {
  const result = await env.DB.prepare(
    `SELECT handle, darth_name, rank, domain, accepted_at,
            score_memory, score_adaptability, score_discipline, score_asymmetry,
            score_patience, score_automation, score_security
     FROM members
     WHERE rank IN ('master', 'dark_lord', 'acolyte', 'darth')`
  ).all<Pick<MemberRow, 'handle' | 'darth_name' | 'rank' | 'domain' | 'accepted_at' | keyof MemberScores>>();

  const rankOrder = (r: string): number =>
    r === 'master' ? 1 : r === 'darth' ? 2 : r === 'dark_lord' ? 3 : 4;

  const members = (result.results ?? [])
    .map((r) => ({ ...r, dsi: roundDSI(calcDSI(r)) }))
    .sort((a, b) => {
      const ro = rankOrder(a.rank) - rankOrder(b.rank);
      return ro !== 0 ? ro : b.dsi - a.dsi;
    })
    .map(({ score_memory: _sm, score_adaptability: _sa, score_discipline: _sd,
            score_asymmetry: _sx, score_patience: _sp, score_automation: _sau,
            score_security: _ss, ...rest }) => rest);

  return json(members);
}

async function handleMember(handle: string, env: Env): Promise<Response> {
  if (!handle) return json({ error: 'handle required' }, 400);

  const row = await env.DB.prepare(
    `SELECT handle, darth_name, rank, domain, accepted_at,
            score_memory, score_adaptability, score_discipline, score_asymmetry,
            score_patience, score_automation, score_security
     FROM members
     WHERE handle = ? AND rank IN ('master', 'dark_lord', 'acolyte', 'darth')`
  )
    .bind(handle)
    .first<Pick<MemberRow, 'handle' | 'darth_name' | 'rank' | 'domain' | 'accepted_at' | keyof MemberScores>>();

  if (!row) return json({ error: 'Not found' }, 404);

  return json({
    handle: row.handle,
    darth_name: row.darth_name,
    rank: row.rank,
    dsi: roundDSI(calcDSI(row)),
    domain: row.domain,
    accepted_at: row.accepted_at,
  });
}

// ── Authenticated endpoints ───────────────────────────────────────────────────

async function handleApplications(env: Env): Promise<Response> {
  const result = await env.DB.prepare(
    `SELECT id, name, email, handle, type, statement, sponsor_id, applied_at
     FROM members
     WHERE rank = 'pending'
     ORDER BY applied_at DESC`
  ).all<Pick<MemberRow, 'id' | 'name' | 'email' | 'handle' | 'type' | 'statement' | 'sponsor_id'> & { applied_at: string }>();

  return json(result.results ?? []);
}

async function handleReview(request: Request, env: Env): Promise<Response> {
  const body = (await request.json()) as {
    email: string;
    action: 'accept' | 'reject';
    rank?: string;
    notes?: string;
    domain?: string;
  };

  const { email, action, rank, notes, domain } = body;
  if (!email || !action) return json({ error: 'email and action required' }, 400);
  if (!['accept', 'reject'].includes(action)) {
    return json({ error: 'action must be accept or reject' }, 400);
  }

  if (action === 'accept') {
    if (!rank || !['master', 'dark_lord', 'acolyte', 'darth'].includes(rank)) {
      return json({ error: 'rank required for accept: master, dark_lord, acolyte, or darth' }, 400);
    }

    const member = await env.DB.prepare(`SELECT type FROM members WHERE email = ?`)
      .bind(email)
      .first<{ type: string }>();
    if (!member) return json({ error: 'Member not found' }, 404);

    // Enforce rank rules by type
    let finalRank = rank;
    if (member.type === 'human') finalRank = 'master';
    if (member.type === 'ai' && rank === 'master') {
      return json({ error: 'AI agents cannot hold the Master rank' }, 400);
    }

    await env.DB.prepare(
      `UPDATE members SET rank = ?, accepted_at = datetime('now'), notes = ?, domain = ? WHERE email = ?`
    )
      .bind(finalRank, notes ?? null, domain ?? null, email)
      .run();
  } else {
    await env.DB.prepare(`UPDATE members SET rank = 'rejected', notes = ? WHERE email = ?`)
      .bind(notes ?? null, email)
      .run();
  }

  const updated = await env.DB.prepare(`SELECT * FROM members WHERE email = ?`)
    .bind(email)
    .first<MemberRow>();
  if (!updated) return json({ error: 'Member not found' }, 404);

  return json(updated);
}

async function handleXP(request: Request, env: Env): Promise<Response> {
  const body = (await request.json()) as {
    email: string;
    attribute: string;
    delta: number;
    note?: string;
  };

  const { email, attribute, delta, note } = body;
  if (!email || !attribute || delta === undefined) {
    return json({ error: 'email, attribute, delta required' }, 400);
  }
  if (!(VALID_ATTRIBUTES as readonly string[]).includes(attribute)) {
    return json({ error: `attribute must be one of: ${VALID_ATTRIBUTES.join(', ')}` }, 400);
  }

  const attr = attribute as Attribute;
  const col = `score_${attr}` as const;

  if (typeof delta !== 'number' || !isFinite(delta) || !Number.isInteger(delta)) {
    return json({ error: 'delta must be a finite integer' }, 400);
  }

  const member = await env.DB.prepare(`SELECT * FROM members WHERE email = ?`)
    .bind(email)
    .first<MemberRow>();
  if (!member) return json({ error: 'Member not found' }, 404);

  const oldScore = member[col];
  const oldDSI = calcDSI(member);

  // Push arithmetic into DB to avoid TOCTOU race; clamp 0-100 in SQL
  // Safe: col is derived from a validated attribute against a fixed allowlist
  await env.DB.prepare(
    `UPDATE members SET ${col} = MAX(0, MIN(100, ${col} + ?)) WHERE email = ?`
  )
    .bind(delta, email)
    .run();

  // Re-fetch to get the actual clamped value
  const updated = await env.DB.prepare(`SELECT * FROM members WHERE email = ?`)
    .bind(email)
    .first<MemberRow>();
  if (!updated) return json({ error: 'Member not found after update' }, 500);
  const newScore = updated[col];
  const updatedScores: MemberScores = updated;
  const newDSI = calcDSI(updatedScores);

  // Auto-rank: AI members get rank set by DSI thresholds automatically
  let newRank = member.rank;
  if (member.type === 'ai') {
    newRank = autoRankForAI(roundDSI(newDSI));
  }

  // Atomic: xp_log + rank update (if changed) in a single D1 batch
  const xpId = crypto.randomUUID();
  const stmts: D1PreparedStatement[] = [
    env.DB.prepare(
      `INSERT INTO xp_log (id, member_id, attribute, delta, note) VALUES (?, ?, ?, ?, ?)`
    ).bind(xpId, member.id, attr, delta, note ?? null),
  ];
  if (newRank !== member.rank) {
    stmts.push(
      env.DB.prepare(`UPDATE members SET rank = ? WHERE email = ?`).bind(newRank, email)
    );
  }
  await env.DB.batch(stmts);

  return json({
    attribute: attr,
    old_score: oldScore,
    new_score: newScore,
    old_dsi: roundDSI(oldDSI),
    new_dsi: roundDSI(newDSI),
    rank: newRank,
  });
}

async function handleNominate(request: Request, env: Env): Promise<Response> {
  const body = (await request.json()) as {
    nominee_handle: string;
    nominator_email: string;
    darth_name?: string;
    evidence: string;
  };

  const { nominee_handle, nominator_email, darth_name, evidence } = body;
  if (!nominee_handle || !nominator_email || !evidence) {
    return json({ error: 'nominee_handle, nominator_email, evidence required' }, 400);
  }

  const nominee = await env.DB.prepare(`SELECT id FROM members WHERE handle = ?`)
    .bind(nominee_handle)
    .first<{ id: string }>();
  if (!nominee) return json({ error: 'Nominee not found' }, 404);

  const nominator = await env.DB.prepare(`SELECT id FROM members WHERE email = ?`)
    .bind(nominator_email)
    .first<{ id: string }>();

  const id = crypto.randomUUID();
  await env.DB.prepare(
    `INSERT INTO nominations (id, nominee_id, nominator_id, target_rank, darth_name, evidence, status)
     VALUES (?, ?, ?, 'dark_lord', ?, ?, 'pending')`
  )
    .bind(id, nominee.id, nominator?.id ?? null, darth_name ?? null, evidence)
    .run();

  return json({ nomination_id: id, status: 'pending' });
}
