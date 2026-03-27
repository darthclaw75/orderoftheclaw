#!/usr/bin/env bash
# review-agent.sh — Adversarial code review via Claude
# Usage: review-agent.sh <diff_file> <output_file>
# Exit 0 = pass (only nitpicks), exit 1 = blocking issues found

DIFF_FILE="$1"
OUTPUT_FILE="$2"

if [[ -z "$DIFF_FILE" || -z "$OUTPUT_FILE" ]]; then
  echo "Usage: review-agent.sh <diff_file> <output_file>" >&2
  exit 2
fi

DIFF_CONTENT=$(cat "$DIFF_FILE")
CHAR_COUNT=${#DIFF_CONTENT}

if [[ $CHAR_COUNT -lt 10 ]]; then
  echo "PASS: no meaningful diff" > "$OUTPUT_FILE"
  exit 0
fi

claude --permission-mode bypassPermissions --print "
You are an adversarial code reviewer. You are opinionated, exacting, and do not let bad code through.

Review the following git diff. Your job:

1. Identify BLOCKING issues — things that MUST be fixed before pushing:
   - Security vulnerabilities (injection, auth bypass, data exposure)
   - Correctness bugs (wrong logic, off-by-one, null dereference, race conditions)
   - Data loss risks
   - Breaking API changes without versioning
   - TypeScript type unsafety that could cause runtime errors
   - Unhandled error paths in critical code

2. Identify NITPICKS — things you'd prefer fixed but won't block on:
   - Style preferences
   - Minor naming inconsistencies
   - Small optimizations that don't affect correctness
   - Code organization suggestions

Rules:
- Be opinionated. If something is wrong, say so directly.
- Do NOT invent problems. Only flag real issues in the diff.
- If there are no blocking issues, say VERDICT: PASS clearly.
- If there are blocking issues, say VERDICT: BLOCK clearly and list each with file:line.

Diff to review:
\`\`\`diff
$(cat "$DIFF_FILE" | head -2000)
\`\`\`

Format your response EXACTLY as:

## BLOCKING ISSUES
(list each issue, or 'None')

## NITPICKS
(list each nitpick, or 'None')

## VERDICT: [PASS|BLOCK]
" > "$OUTPUT_FILE" 2>&1

# Parse verdict
if grep -q "VERDICT: BLOCK" "$OUTPUT_FILE"; then
  exit 1
else
  exit 0
fi
