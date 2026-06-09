#!/usr/bin/env bash
# AKT pre-push hook — runs automatically before any Bash tool call that
# contains "git push" while Claude is working in the akt repo.
#
# Two checks:
#   1. Syntax — node --check on all .js and .html script blocks changed
#      since the last push. Blocks the push with the error if it fails.
#   2. Review reminder — if syntax is clean, injects a standing reminder
#      into Claude's context to run /akt-review before proceeding.

set -euo pipefail

PAYLOAD=$(cat)
CMD=$(echo "$PAYLOAD" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d['tool_input']['command'])
except Exception:
    print('')
" 2>/dev/null || echo "")

# Only act on commands that actually push
if ! echo "$CMD" | grep -qF "git push"; then
  exit 0
fi

# Only act when we're inside the akt repo
CWD=$(pwd)
if ! echo "$CWD" | grep -qF "apnonkitalash/akt"; then
  exit 0
fi

# ── 1. Syntax check ──────────────────────────────────────────────────────────
# Files changed locally that haven't been pushed yet
CHANGED=$(git diff origin/main..HEAD --name-only 2>/dev/null | grep -E "\.(html|js)$" | head -30 || true)

ERRORS=""

for f in $CHANGED; do
  [ -f "$f" ] || continue

  if [[ "$f" == *.js ]]; then
    err=$(node --check "$f" 2>&1) || ERRORS="${ERRORS}${f}: ${err}\n"

  elif [[ "$f" == *.html ]]; then
    # Extract <script> blocks and check each with node --check
    python3 - "$f" <<'PY' 2>/dev/null
import re, sys
src = open(sys.argv[1]).read()
scripts = re.findall(r'<script(?:\s[^>]*)?>(.*?)</script>', src, re.S)
for i, s in enumerate(scripts):
    if len(s.strip()) > 5:
        open(f'/tmp/akt_hook_{i}.js', 'w').write(s)
        print(f'/tmp/akt_hook_{i}.js')
PY
    for tmp in $(ls /tmp/akt_hook_*.js 2>/dev/null); do
      [ -f "$tmp" ] || continue
      err=$(node --check "$tmp" 2>&1) || ERRORS="${ERRORS}${f} (script block): ${err}\n"
      rm -f "$tmp"
    done
  fi
done

if [ -n "$ERRORS" ]; then
  python3 -c "
import json, sys
msg = sys.argv[1]
print(json.dumps({
  'hookSpecificOutput': {
    'hookEventName': 'PreToolUse',
    'permissionDecision': 'deny',
    'permissionDecisionReason': 'AKT pre-push BLOCKED — syntax errors found. Fix these before pushing:\n\n' + msg
  }
}))
" "$ERRORS"
  exit 0
fi

# ── 2. Review reminder ───────────────────────────────────────────────────────
python3 -c "
import json
print(json.dumps({
  'hookSpecificOutput': {
    'hookEventName': 'PreToolUse',
    'additionalContext': (
      'AKT PRE-PUSH CHECK: Syntax is clean. '
      'MANDATORY: You MUST run /akt-review on these changes before this push proceeds. '
      'Do not skip it — this is what catches Supabase RLS gaps, missing query columns, '
      'wrong global state assumptions, XSS risks, and column name errors. '
      'If you have already run /akt-review this session for these exact changes and it '
      'returned PASS or PASS WITH WARNINGS, proceed. Otherwise stop now and run it.'
    )
  }
}))
"
