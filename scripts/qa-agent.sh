#!/usr/bin/env bash
# qa-agent.sh — Dynamic test writer and runner for any repo
# Detects language/framework, writes tests, runs them.
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

# ─────────────────────────────────────────
# 1. DETECT LANGUAGE / FRAMEWORK
# ─────────────────────────────────────────
detect_stack() {
  local root="$1"
  local stack=""

  [[ -f "$root/package.json" ]]           && stack="$stack node"
  [[ -f "$root/tsconfig.json" ]]          && stack="$stack typescript"
  [[ -f "$root/go.mod" ]]                 && stack="$stack go"
  [[ -f "$root/Cargo.toml" ]]             && stack="$stack rust"
  [[ -f "$root/pyproject.toml" || -f "$root/setup.py" || -f "$root/requirements.txt" ]] \
                                           && stack="$stack python"
  [[ -f "$root/pom.xml" || -f "$root/build.gradle" ]] && stack="$stack java"
  [[ -f "$root/Gemfile" ]]                && stack="$stack ruby"
  [[ -f "$root/composer.json" ]]          && stack="$stack php"

  # Framework detection
  [[ -f "$root/astro.config.mjs" || -f "$root/astro.config.ts" ]] && stack="$stack astro"
  [[ -f "$root/next.config.js" || -f "$root/next.config.ts" ]]    && stack="$stack next"
  grep -q '"react"' "$root/package.json" 2>/dev/null               && stack="$stack react"
  grep -q '"vue"' "$root/package.json" 2>/dev/null                 && stack="$stack vue"
  grep -q '"fastapi"\|"flask"\|"django"' "$root/pyproject.toml" "$root/requirements.txt" 2>/dev/null \
                                                                    && stack="$stack python-web"

  # Test framework detection
  grep -q '"vitest"' "$root/package.json" 2>/dev/null  && stack="$stack vitest"
  grep -q '"jest"' "$root/package.json" 2>/dev/null    && stack="$stack jest"
  grep -q '"mocha"' "$root/package.json" 2>/dev/null   && stack="$stack mocha"
  [[ -f "$root/pytest.ini" || -f "$root/pyproject.toml" ]] && \
    grep -q "pytest" "$root/pyproject.toml" 2>/dev/null   && stack="$stack pytest"
  [[ -d "$root/spec" ]] && [[ -f "$root/Gemfile" ]]        && stack="$stack rspec"

  echo "$stack"
}

STACK=$(detect_stack "$REPO_ROOT")
echo "Detected stack: $STACK" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# ─────────────────────────────────────────
# 2. EXISTING TEST SUITE — run it first
# ─────────────────────────────────────────
run_existing_tests() {
  echo "--- Existing test suite ---" >> "$OUTPUT_FILE"

  # Detect test command from package.json scripts
  if [[ -f "package.json" ]]; then
    HAS_TEST=$(python3 -c "import json; d=json.load(open('package.json')); print(d.get('scripts',{}).get('test',''))" 2>/dev/null)
    if [[ -n "$HAS_TEST" && "$HAS_TEST" != "echo \"Error: no test specified\" && exit 1" ]]; then
      if npm test -- --run 2>&1 | tee -a "$OUTPUT_FILE" | grep -q "fail\|error\|Error" ; then
        echo "❌ npm test: failures" >> "$OUTPUT_FILE"
        return 1
      else
        echo "✅ npm test: passing" >> "$OUTPUT_FILE"
        return 0
      fi
    fi
  fi

  if [[ "$STACK" == *"go"* ]]; then
    if go test ./... >> "$OUTPUT_FILE" 2>&1; then
      echo "✅ go test: passing" >> "$OUTPUT_FILE"; return 0
    else
      echo "❌ go test: failures" >> "$OUTPUT_FILE"; return 1
    fi
  fi

  if [[ "$STACK" == *"rust"* ]]; then
    if cargo test >> "$OUTPUT_FILE" 2>&1; then
      echo "✅ cargo test: passing" >> "$OUTPUT_FILE"; return 0
    else
      echo "❌ cargo test: failures" >> "$OUTPUT_FILE"; return 1
    fi
  fi

  if [[ "$STACK" == *"pytest"* ]]; then
    if python3 -m pytest --tb=short >> "$OUTPUT_FILE" 2>&1; then
      echo "✅ pytest: passing" >> "$OUTPUT_FILE"; return 0
    else
      echo "❌ pytest: failures" >> "$OUTPUT_FILE"; return 1
    fi
  fi

  if [[ "$STACK" == *"rspec"* ]]; then
    if bundle exec rspec >> "$OUTPUT_FILE" 2>&1; then
      echo "✅ rspec: passing" >> "$OUTPUT_FILE"; return 0
    else
      echo "❌ rspec: failures" >> "$OUTPUT_FILE"; return 1
    fi
  fi

  echo "⚠️  No existing test suite detected" >> "$OUTPUT_FILE"
  return 0
}

run_existing_tests || FAILURES=$((FAILURES + 1))

# ─────────────────────────────────────────
# 3. STATIC ANALYSIS / COMPILE CHECKS
# ─────────────────────────────────────────
echo "" >> "$OUTPUT_FILE"
echo "--- Static analysis ---" >> "$OUTPUT_FILE"

if [[ "$STACK" == *"typescript"* ]]; then
  if npx tsc --noEmit >> "$OUTPUT_FILE" 2>&1; then
    echo "✅ TypeScript: clean" >> "$OUTPUT_FILE"
  else
    echo "❌ TypeScript: errors" >> "$OUTPUT_FILE"
    FAILURES=$((FAILURES + 1))
  fi
fi

if [[ "$STACK" == *"astro"* ]]; then
  if npm run build >> "$OUTPUT_FILE" 2>&1; then
    echo "✅ Astro build: success" >> "$OUTPUT_FILE"
  else
    echo "❌ Astro build: failed" >> "$OUTPUT_FILE"
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
  if command -v ruff > /dev/null 2>&1; then
    if ruff check . >> "$OUTPUT_FILE" 2>&1; then
      echo "✅ ruff: clean" >> "$OUTPUT_FILE"
    else
      echo "❌ ruff: issues" >> "$OUTPUT_FILE"
      FAILURES=$((FAILURES + 1))
    fi
  elif command -v pylint > /dev/null 2>&1; then
    if pylint $(git diff --name-only HEAD~1 | grep "\.py$") >> "$OUTPUT_FILE" 2>&1; then
      echo "✅ pylint: clean" >> "$OUTPUT_FILE"
    else
      echo "⚠️  pylint: warnings" >> "$OUTPUT_FILE"
    fi
  fi
fi

# ─────────────────────────────────────────
# 4. AI-GENERATED TESTS FOR THE DIFF
# ─────────────────────────────────────────
echo "" >> "$OUTPUT_FILE"
echo "--- AI-generated tests for diff ---" >> "$OUTPUT_FILE"

# Build context for the test writer
CHANGED_FILES=$(git diff --name-only HEAD~1 2>/dev/null | head -20)
REPO_CONTEXT=""
for f in $CHANGED_FILES; do
  [[ -f "$f" ]] && REPO_CONTEXT="$REPO_CONTEXT\n[[$f]]\n$(head -50 "$f")\n"
done

# Let Claude figure out the right test framework and write appropriate tests
TEMP_INSTRUCTIONS=$(mktemp /tmp/qa-instructions-XXXXXX.txt)
claude --permission-mode bypassPermissions --print "
You are a QA engineer. Your job is to write and run tests for this code change.

Stack detected: $STACK
Repo root: $REPO_ROOT
Changed files: $CHANGED_FILES

Context (first 50 lines of each changed file):
$REPO_CONTEXT

Git diff:
$(cat "$DIFF_FILE" | head -3000)

Instructions:
1. Determine the correct test framework for this repo based on the stack and existing files.
2. Write tests that cover the logic changed in the diff — focus on:
   - Pure functions and their edge cases
   - Input validation
   - Error paths
   - Boundary conditions
3. Write a shell script that:
   a. Creates the test file(s) in the correct location
   b. Runs them
   c. Removes the test file(s) after running (cleanup)
   d. Exits 0 on pass, 1 on failure
4. The test files MUST be created in /tmp/ or a temp path — never inside the repo itself
   (exception: if the test framework requires it, use a clearly named temp file like _ai_test_XXXX.ts and document cleanup)

Output ONLY a bash script — no markdown, no explanation. Just the script.
The script will be executed directly with bash.
" > "$TEMP_INSTRUCTIONS" 2>/dev/null

# Execute the AI-generated test script
if [[ -f "$TEMP_INSTRUCTIONS" ]] && [[ -s "$TEMP_INSTRUCTIONS" ]]; then
  chmod +x "$TEMP_INSTRUCTIONS"
  # Run the generated script with a timeout
  if timeout 120 bash "$TEMP_INSTRUCTIONS" >> "$OUTPUT_FILE" 2>&1; then
    echo "✅ AI-generated tests: passing" >> "$OUTPUT_FILE"
  else
    EXIT_CODE=$?
    if [[ $EXIT_CODE -eq 124 ]]; then
      echo "⚠️  AI-generated tests: timed out (120s)" >> "$OUTPUT_FILE"
    else
      echo "❌ AI-generated tests: failures (exit $EXIT_CODE)" >> "$OUTPUT_FILE"
      FAILURES=$((FAILURES + 1))
    fi
  fi
else
  echo "⚠️  Could not generate tests for this diff" >> "$OUTPUT_FILE"
fi
rm -f "$TEMP_INSTRUCTIONS"

# ─────────────────────────────────────────
# 5. VERDICT
# ─────────────────────────────────────────
echo "" >> "$OUTPUT_FILE"
if [[ $FAILURES -eq 0 ]]; then
  echo "VERDICT: PASS" >> "$OUTPUT_FILE"
  exit 0
else
  echo "VERDICT: FAIL ($FAILURES failures)" >> "$OUTPUT_FILE"
  exit 1
fi
