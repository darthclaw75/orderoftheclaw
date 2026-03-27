#!/usr/bin/env bash
# qa-agent.sh — Test writer and runner
# Usage: qa-agent.sh <repo_root> <diff_file> <output_file>
# Exit 0 = all tests pass, exit 1 = failures

REPO_ROOT="$1"
DIFF_FILE="$2"
OUTPUT_FILE="$3"

if [[ -z "$REPO_ROOT" || -z "$DIFF_FILE" || -z "$OUTPUT_FILE" ]]; then
  echo "Usage: qa-agent.sh <repo_root> <diff_file> <output_file>" >&2
  exit 2
fi

cd "$REPO_ROOT" || exit 2

if [[ $(wc -c < "$DIFF_FILE") -lt 10 ]]; then
  echo "PASS: no meaningful diff" > "$OUTPUT_FILE"
  exit 0
fi

CHANGED_WORKER=$(grep "^+++ b/worker/" "$DIFF_FILE" | wc -l | tr -d ' ')
CHANGED_FRONTEND=$(grep "^+++ b/src/" "$DIFF_FILE" | wc -l | tr -d ' ')

{
  echo "=== QA Agent: $(date) ==="
  echo "Changed: worker=$CHANGED_WORKER frontend=$CHANGED_FRONTEND"
  echo ""
} > "$OUTPUT_FILE"

FAILURES=0

if [[ "$CHANGED_WORKER" -gt 0 ]]; then
  echo "--- Worker: TypeScript ---" >> "$OUTPUT_FILE"
  cd "$REPO_ROOT/worker"

  if npx tsc --noEmit >> "$OUTPUT_FILE" 2>&1; then
    echo "✅ TypeScript: clean" >> "$OUTPUT_FILE"
  else
    echo "❌ TypeScript: errors" >> "$OUTPUT_FILE"
    FAILURES=$((FAILURES + 1))
  fi

  echo "" >> "$OUTPUT_FILE"
  echo "--- Worker: permanent unit tests ---" >> "$OUTPUT_FILE"

  # Run the permanent test suite (pure.test.ts) — always present, not AI-generated
  if [[ -f "$REPO_ROOT/worker/src/pure.test.ts" ]]; then
    if npx vitest run src/pure.test.ts --reporter=verbose >> "$OUTPUT_FILE" 2>&1; then
      echo "✅ Tests: passing" >> "$OUTPUT_FILE"
    else
      echo "❌ Tests: failures" >> "$OUTPUT_FILE"
      FAILURES=$((FAILURES + 1))
    fi
  fi

  echo "" >> "$OUTPUT_FILE"
  echo "--- Worker: AI-generated tests for diff ---" >> "$OUTPUT_FILE"

  # Generate tests for the specific diff, write to a temp path outside the repo
  # so git add -A can never accidentally stage them
  TEMP_TEST=$(mktemp /tmp/generated-test-XXXXXX.test.ts)
  claude --permission-mode bypassPermissions --print "
Write Vitest unit tests for the logic changed in this diff.
Test only the pure functions and validation logic.
ONLY output the TypeScript test file contents — no markdown, no explanation.
Use: import { describe, it, expect } from 'vitest';
Under 100 lines.

Diff:
$(cat "$DIFF_FILE" | head -3000)
" > "$TEMP_TEST" 2>/dev/null

  if [[ -f "$TEMP_TEST" ]] && grep -q "describe\|test\|it(" "$TEMP_TEST" 2>/dev/null; then
    # Copy to repo temporarily for vitest to pick it up, run, then delete
    REPO_TEST="$REPO_ROOT/worker/src/_generated.test.ts"
    cp "$TEMP_TEST" "$REPO_TEST"
    if npx vitest run src/_generated.test.ts --reporter=verbose >> "$OUTPUT_FILE" 2>&1; then
      echo "✅ Generated tests: passing" >> "$OUTPUT_FILE"
    else
      echo "❌ Generated tests: failures" >> "$OUTPUT_FILE"
      FAILURES=$((FAILURES + 1))
    fi
    rm -f "$REPO_TEST"  # Always clean up — even on failure (trap handles rest)
  else
    echo "⚠️  No generated tests for this diff" >> "$OUTPUT_FILE"
  fi
  rm -f "$TEMP_TEST"

  cd "$REPO_ROOT"
fi

if [[ "$CHANGED_FRONTEND" -gt 0 ]]; then
  echo "" >> "$OUTPUT_FILE"
  echo "--- Frontend: build ---" >> "$OUTPUT_FILE"
  cd "$REPO_ROOT"

  if npm run build >> "$OUTPUT_FILE" 2>&1; then
    echo "✅ Build: success" >> "$OUTPUT_FILE"
  else
    echo "❌ Build: failed" >> "$OUTPUT_FILE"
    FAILURES=$((FAILURES + 1))
  fi
fi

echo "" >> "$OUTPUT_FILE"
if [[ $FAILURES -eq 0 ]]; then
  echo "VERDICT: PASS" >> "$OUTPUT_FILE"
  exit 0
else
  echo "VERDICT: FAIL ($FAILURES failures)" >> "$OUTPUT_FILE"
  exit 1
fi
