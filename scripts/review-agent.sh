#!/usr/bin/env bash
# review-agent.sh — Adversarial code review via Claude
# Works on any codebase. Analyzes the diff + repo context.
# Usage: review-agent.sh <repo_root> <diff_file> <output_file>
# Exit 0 = pass (only nitpicks or clean), exit 1 = blocking issues found

REPO_ROOT="$1"
DIFF_FILE="$2"
OUTPUT_FILE="$3"

[[ -z "$REPO_ROOT" || -z "$DIFF_FILE" || -z "$OUTPUT_FILE" ]] && {
  echo "Usage: review-agent.sh <repo_root> <diff_file> <output_file>" >&2; exit 2
}

if [[ $(wc -c < "$DIFF_FILE") -lt 10 ]]; then
  echo "## VERDICT: PASS" > "$OUTPUT_FILE"
  exit 0
fi

# Build repo context snapshot for the reviewer
CONTEXT=$(cd "$REPO_ROOT" && {
  echo "=== Repo: $(basename "$PWD") ==="
  echo "--- Files changed ---"
  git diff --name-only HEAD~1 2>/dev/null | head -30
  echo ""
  echo "--- package.json / pyproject.toml / go.mod / Cargo.toml / pom.xml ---"
  for f in package.json pyproject.toml go.mod Cargo.toml pom.xml composer.json Gemfile; do
    [[ -f "$f" ]] && { echo "[$f]"; head -20 "$f"; echo ""; }
  done
  echo "--- README (first 30 lines) ---"
  [[ -f README.md ]] && head -30 README.md || [[ -f README.rst ]] && head -30 README.rst || echo "(none)"
})

claude --permission-mode bypassPermissions --print "
You are an adversarial code reviewer. Opinionated, exacting, no bad code passes.

Repo context:
$CONTEXT

Review the following git diff. Identify:

BLOCKING ISSUES — must be fixed before pushing:
- Security vulnerabilities (injection, auth bypass, data exposure, secret leaks)
- Correctness bugs (wrong logic, off-by-one, null dereference, race conditions, data loss)
- Breaking API changes without versioning
- Runtime type errors or null pointer exceptions
- Unhandled error paths in critical code paths
- Dependency changes that introduce known vulnerabilities

NITPICKS — print but never block:
- Style preferences
- Minor naming issues
- Small non-critical optimizations
- Code organization suggestions
- Redundant code

Rules:
- Be adversarial. Assume this code will be attacked.
- Only flag real issues in the diff. Do not invent problems.
- Be specific: file name and approximate line number for each issue.
- VERDICT: PASS if zero blocking issues. VERDICT: BLOCK if any blocking issues.

Diff:
\`\`\`diff
$(cat "$DIFF_FILE" | head -3000)
\`\`\`

Respond EXACTLY in this format:

## BLOCKING ISSUES
(list each blocking issue with file:line, or write 'None')

## NITPICKS
(list each nitpick, or write 'None')

## VERDICT: [PASS|BLOCK]
" > "$OUTPUT_FILE" 2>&1

# Validate output has expected structure — fail safe if malformed
if ! grep -q "## VERDICT" "$OUTPUT_FILE"; then
  echo "## BLOCKING ISSUES" >> "$OUTPUT_FILE"
  echo "Review agent produced malformed output — failing safe" >> "$OUTPUT_FILE"
  echo "## VERDICT: BLOCK" >> "$OUTPUT_FILE"
  exit 1
fi

grep -q "VERDICT: BLOCK" "$OUTPUT_FILE" && exit 1 || exit 0
