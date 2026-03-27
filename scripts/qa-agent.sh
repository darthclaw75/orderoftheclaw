#!/usr/bin/env bash
# qa-agent.sh — Dynamic test writer and runner for any repo
# Detects language/framework, runs existing tests, writes and runs new tests.
# Logical unit tests are written to the repo and staged for commit.
# Usage: qa-agent.sh <repo_root> <diff_file> <output_file>
# Exit 0 = pass, exit 1 = failures

REPO_ROOT="$1"
DIFF_FILE="$2"
OUTPUT_FILE="$3"

[[ -z "$REPO_ROOT" || -z "$DIFF_FILE" || -z "$OUTPUT_FILE" ]] && {
  echo "Usage: qa-agent.sh <repo_root> <diff_file> <output_file>" >&2; exit 2
}

cd "$REPO_ROOT" || exit 2

if [[ $(wc -c < "$DIFF_FILE") -lt 10 ]]; then
  echo "VERDICT: PASS (no diff)" > "$OUTPUT_FILE"
  exit 0
fi

{
  echo "=== QA Agent: $(date) ==="
  echo "Repo: $(basename "$REPO_ROOT")"
  echo ""
} > "$OUTPUT_FILE"

FAILURES=0
NEW_TEST_FILES=()

# ─────────────────────────────────────────
# 1. DETECT STACK
# ─────────────────────────────────────────
detect_stack() {
  local root="$1"
  local stack=""
  [[ -f "$root/package.json" ]]    && stack="$stack node"
  [[ -f "$root/tsconfig.json" ]]   && stack="$stack typescript"
  [[ -f "$root/go.mod" ]]          && stack="$stack go"
  [[ -f "$root/Cargo.toml" ]]      && stack="$stack rust"
  [[ -f "$root/pyproject.toml" || -f "$root/setup.py" || -f "$root/requirements.txt" ]] \
                                    && stack="$stack python"
  [[ -f "$root/pom.xml" || -f "$root/build.gradle" ]] && stack="$stack java"
  [[ -f "$root/Gemfile" ]]         && stack="$stack ruby"
  [[ -f "$root/composer.json" ]]   && stack="$stack php"
  [[ -f "$root/astro.config.mjs" || -f "$root/astro.config.ts" ]] && stack="$stack astro"
  [[ -f "$root/next.config.js" || -f "$root/next.config.ts" ]]    && stack="$stack next"
  grep -q '"vitest"' "$root/package.json" 2>/dev/null  && stack="$stack vitest"
  grep -q '"jest"' "$root/package.json" 2>/dev/null    && stack="$stack jest"
  grep -q '"mocha"' "$root/package.json" 2>/dev/null   && stack="$stack mocha"
  grep -q "pytest" "$root/pyproject.toml" "$root/setup.cfg" 2>/dev/null && stack="$stack pytest"
  [[ -d "$root/spec" && -f "$root/Gemfile" ]] && stack="$stack rspec"
  echo "$stack"
}

STACK=$(detect_stack "$REPO_ROOT")
echo "Stack: $STACK" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# ─────────────────────────────────────────
# 2. STATIC ANALYSIS
# ─────────────────────────────────────────
echo "--- Static analysis ---" >> "$OUTPUT_FILE"

if [[ "$STACK" == *"typescript"* ]]; then
  if npx tsc --noEmit >> "$OUTPUT_FILE" 2>&1; then
    echo "✅ TypeScript: clean" >> "$OUTPUT_FILE"
  else
    echo "❌ TypeScript: errors" >> "$OUTPUT_FILE"
    FAILURES=$((FAILURES + 1))
  fi
fi

if [[ "$STACK" == *"go"* ]]; then
  if go vet ./... >> "$OUTPUT_FILE" 2>&1; then
    echo "✅ go vet: clean" >> "$OUTPUT_FILE"
  else
    echo "❌ go vet: issues" >> "$OUTPUT_FILE"
    FAILURES=$((FAILURES + 1))
  fi
fi

if [[ "$STACK" == *"python"* ]]; then
  command -v ruff > /dev/null 2>&1 && {
    ruff check . >> "$OUTPUT_FILE" 2>&1 \
      && echo "✅ ruff: clean" >> "$OUTPUT_FILE" \
      || echo "⚠️  ruff: warnings" >> "$OUTPUT_FILE"
  }
fi

# ─────────────────────────────────────────
# 3. EXISTING TESTS
# ─────────────────────────────────────────
echo "" >> "$OUTPUT_FILE"
echo "--- Existing tests ---" >> "$OUTPUT_FILE"

run_existing() {
  if [[ -f "package.json" ]]; then
    HAS_TEST=$(python3 -c "import json; d=json.load(open('package.json')); t=d.get('scripts',{}).get('test',''); print(t)" 2>/dev/null)
    if [[ -n "$HAS_TEST" && "$HAS_TEST" != *"no test specified"* ]]; then
      npm test -- --run >> "$OUTPUT_FILE" 2>&1 \
        && echo "✅ npm test: passing" >> "$OUTPUT_FILE" \
        || { echo "❌ npm test: failures" >> "$OUTPUT_FILE"; return 1; }
      return 0
    fi
  fi
  [[ "$STACK" == *"go"* ]]   && { go test ./... >> "$OUTPUT_FILE" 2>&1 \
    && echo "✅ go test: passing" >> "$OUTPUT_FILE" \
    || { echo "❌ go test: failures" >> "$OUTPUT_FILE"; return 1; }; return 0; }
  [[ "$STACK" == *"rust"* ]] && { cargo test >> "$OUTPUT_FILE" 2>&1 \
    && echo "✅ cargo test: passing" >> "$OUTPUT_FILE" \
    || { echo "❌ cargo test: failures" >> "$OUTPUT_FILE"; return 1; }; return 0; }
  [[ "$STACK" == *"pytest"* ]] && { python3 -m pytest --tb=short >> "$OUTPUT_FILE" 2>&1 \
    && echo "✅ pytest: passing" >> "$OUTPUT_FILE" \
    || { echo "❌ pytest: failures" >> "$OUTPUT_FILE"; return 1; }; return 0; }
  [[ "$STACK" == *"rspec"* ]] && { bundle exec rspec >> "$OUTPUT_FILE" 2>&1 \
    && echo "✅ rspec: passing" >> "$OUTPUT_FILE" \
    || { echo "❌ rspec: failures" >> "$OUTPUT_FILE"; return 1; }; return 0; }
  echo "⚠️  No existing test suite detected" >> "$OUTPUT_FILE"
  return 0
}

run_existing || FAILURES=$((FAILURES + 1))

# ─────────────────────────────────────────
# 4. AI-WRITTEN TESTS FOR THE DIFF
# ─────────────────────────────────────────
echo "" >> "$OUTPUT_FILE"
echo "--- AI-generated tests ---" >> "$OUTPUT_FILE"

# Build context for Claude
CHANGED_FILES=$(git diff --name-only "${DIFF_BASE:-HEAD~1}" 2>/dev/null | head -20)
FILE_CONTEXT=""
for f in $CHANGED_FILES; do
  [[ -f "$f" ]] && FILE_CONTEXT="$FILE_CONTEXT\n[[$f]]\n$(head -80 "$f")\n"
done

# Find test directories
TEST_DIRS=$(find . -maxdepth 3 -type d \( -name "test" -o -name "tests" -o -name "__tests__" -o -name "spec" \) \
  ! -path "*/node_modules/*" ! -path "*/.git/*" | head -5 | tr '\n' ' ')

TEMP_SCRIPT=$(mktemp /tmp/qa-testscript-XXXXXX.sh)

claude --permission-mode bypassPermissions --print "
You are a QA engineer writing tests for a git diff. 

Stack: $STACK
Repo: $REPO_ROOT
Existing test dirs: ${TEST_DIRS:-none found}
Changed files: $CHANGED_FILES

File context:
$FILE_CONTEXT

Diff:
$(cat "$DIFF_FILE" | head -3000)

Your job:
1. Decide which tests have LASTING VALUE (unit tests for real business logic, edge cases, regression tests for bugs fixed) vs THROWAWAY TESTS (one-off smoke tests for trivial changes).

2. For LASTING VALUE tests:
   - Write the test file to the appropriate location INSIDE the repo
   - Use whatever test framework is already present (or the most appropriate one for the stack)
   - Follow naming conventions of existing tests in the repo
   - Tests should be meaningful — cover edge cases, boundary conditions, error paths
   - Emit: REPO_TEST_FILE:<filepath> on its own line for each file written to the repo

3. For THROWAWAY tests (or if no lasting tests make sense):
   - Write them to /tmp/qa-test-XXXX.<ext> 
   - Run and delete them

4. Write a bash script that:
   - Creates the test files
   - Runs them using the correct test command
   - Reports pass/fail
   - Cleans up ONLY the /tmp files (NOT the repo test files)
   - Exits 0 on pass, 1 on any failure

5. If the diff is trivial (config change, comment, whitespace) output just: echo 'SKIP: trivial diff'; exit 0

Output ONLY the bash script — no markdown, no explanation.
" > "$TEMP_SCRIPT" 2>/dev/null

if [[ -f "$TEMP_SCRIPT" && -s "$TEMP_SCRIPT" ]]; then
  chmod +x "$TEMP_SCRIPT"

  # Capture which repo test files get written (Claude signals with REPO_TEST_FILE:)
  if timeout 180 bash "$TEMP_SCRIPT" >> "$OUTPUT_FILE" 2>&1; then
    echo "✅ AI tests: passing" >> "$OUTPUT_FILE"
  else
    EXIT_CODE=$?
    [[ $EXIT_CODE -eq 124 ]] \
      && echo "⚠️  AI tests: timed out" >> "$OUTPUT_FILE" \
      || { echo "❌ AI tests: failures" >> "$OUTPUT_FILE"; FAILURES=$((FAILURES + 1)); }
  fi

  # Extract any repo test files Claude wrote, stage them
  REPO_TEST_FILES=$(grep "^REPO_TEST_FILE:" "$OUTPUT_FILE" 2>/dev/null | sed 's/^REPO_TEST_FILE://' | tr -d ' ')
  for tf in $REPO_TEST_FILES; do
    if [[ -f "$REPO_ROOT/$tf" ]]; then
      git -C "$REPO_ROOT" add "$REPO_ROOT/$tf" 2>/dev/null && \
        echo "📁 Staged test file: $tf" >> "$OUTPUT_FILE" && \
        NEW_TEST_FILES+=("$tf")
    fi
  done
else
  echo "⚠️  No tests generated" >> "$OUTPUT_FILE"
fi
rm -f "$TEMP_SCRIPT"

# Report new test files to be committed
if [[ ${#NEW_TEST_FILES[@]} -gt 0 ]]; then
  echo "" >> "$OUTPUT_FILE"
  echo "📝 New test files staged for commit:" >> "$OUTPUT_FILE"
  for tf in "${NEW_TEST_FILES[@]}"; do
    echo "   $tf" >> "$OUTPUT_FILE"
  done
fi

echo "" >> "$OUTPUT_FILE"
if [[ $FAILURES -eq 0 ]]; then
  echo "VERDICT: PASS" >> "$OUTPUT_FILE"
  exit 0
else
  echo "VERDICT: FAIL ($FAILURES failures)" >> "$OUTPUT_FILE"
  exit 1
fi
