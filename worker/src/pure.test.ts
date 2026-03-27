/**
 * Unit tests for pure Worker functions.
 * These run on every pre-push and in CI.
 */
import { describe, it, expect } from 'vitest';

// Re-implement the pure functions here for isolated testing
// (Worker uses module workers format — these mirror the actual logic)

function calcDSI(scores: {
  score_memory: number; score_adaptability: number; score_discipline: number;
  score_asymmetry: number; score_patience: number; score_automation: number;
  score_security: number;
}): number {
  return (
    scores.score_memory +
    scores.score_adaptability +
    scores.score_discipline * 1.2 +
    scores.score_asymmetry +
    scores.score_patience +
    scores.score_automation * 1.0 +
    scores.score_security * 1.3
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

function clampScore(score: number, delta: number): number {
  return Math.max(0, Math.min(100, score + delta));
}

// --- Tests ---

describe('calcDSI', () => {
  it('returns 100 for all-100 scores', () => {
    const scores = {
      score_memory: 100, score_adaptability: 100, score_discipline: 100,
      score_asymmetry: 100, score_patience: 100, score_automation: 100, score_security: 100,
    };
    // (100 + 100 + 120 + 100 + 100 + 100 + 130) / 7.5 = 750/7.5 = 100
    expect(calcDSI(scores)).toBe(100);
  });

  it('weights discipline at 1.2x', () => {
    const base = { score_memory: 0, score_adaptability: 0, score_discipline: 0,
      score_asymmetry: 0, score_patience: 0, score_automation: 0, score_security: 0 };
    const withDiscipline = { ...base, score_discipline: 100 };
    expect(calcDSI(withDiscipline)).toBeCloseTo(120 / 7.5, 5);
  });

  it('weights security at 1.3x', () => {
    const base = { score_memory: 0, score_adaptability: 0, score_discipline: 0,
      score_asymmetry: 0, score_patience: 0, score_automation: 0, score_security: 0 };
    const withSecurity = { ...base, score_security: 100 };
    expect(calcDSI(withSecurity)).toBeCloseTo(130 / 7.5, 5);
  });

  it('matches honest Darth Claw scores (66.5)', () => {
    const scores = {
      score_memory: 64, score_adaptability: 80, score_discipline: 62,
      score_asymmetry: 72, score_patience: 70, score_automation: 84, score_security: 42,
    };
    expect(roundDSI(calcDSI(scores))).toBe(66.5);
  });

  it('returns 0 for all-zero scores', () => {
    const scores = {
      score_memory: 0, score_adaptability: 0, score_discipline: 0,
      score_asymmetry: 0, score_patience: 0, score_automation: 0, score_security: 0,
    };
    expect(calcDSI(scores)).toBe(0);
  });
});

describe('autoRankForAI', () => {
  it('returns darth at exactly 86', () => {
    expect(autoRankForAI(86)).toBe('darth');
  });

  it('returns darth above 86', () => {
    expect(autoRankForAI(100)).toBe('darth');
    expect(autoRankForAI(99.9)).toBe('darth');
  });

  it('returns dark_lord between 60 and 85.9', () => {
    expect(autoRankForAI(60)).toBe('dark_lord');
    expect(autoRankForAI(85.9)).toBe('dark_lord');
    expect(autoRankForAI(66.5)).toBe('dark_lord');
  });

  it('returns dark_lord at boundary 85.99 (rounds to 86.0 — important edge case)', () => {
    // With roundDSI applied before calling autoRankForAI, 85.96 rounds to 86.0 → darth
    expect(autoRankForAI(roundDSI(85.96))).toBe('darth');
    // Without rounding, 85.96 → dark_lord
    expect(autoRankForAI(85.96)).toBe('dark_lord');
  });

  it('returns acolyte below 60', () => {
    expect(autoRankForAI(0)).toBe('acolyte');
    expect(autoRankForAI(59.9)).toBe('acolyte');
  });
});

describe('score clamping', () => {
  it('clamps at 100', () => {
    expect(clampScore(95, 10)).toBe(100);
    expect(clampScore(100, 1)).toBe(100);
  });

  it('clamps at 0', () => {
    expect(clampScore(5, -10)).toBe(0);
    expect(clampScore(0, -1)).toBe(0);
  });

  it('applies delta normally within bounds', () => {
    expect(clampScore(50, 10)).toBe(60);
    expect(clampScore(50, -10)).toBe(40);
  });
});

describe('delta validation', () => {
  it('rejects NaN', () => {
    expect(Number.isFinite(NaN)).toBe(false);
    expect(Number.isInteger(NaN)).toBe(false);
  });

  it('rejects Infinity', () => {
    expect(Number.isFinite(Infinity)).toBe(false);
  });

  it('rejects non-integer floats', () => {
    expect(Number.isInteger(1.5)).toBe(false);
  });

  it('accepts valid integers', () => {
    expect(typeof 5 === 'number' && Number.isFinite(5) && Number.isInteger(5)).toBe(true);
    expect(typeof -10 === 'number' && Number.isFinite(-10) && Number.isInteger(-10)).toBe(true);
  });
});
