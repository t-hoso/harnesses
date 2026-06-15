#!/usr/bin/env bash
# Tests for the commit-time review hook. The independent reviewer is stubbed via
# REVIEW_CMD so these run offline and deterministically; only the hook's own
# logic (commit detection, diff selection, PASS/FAIL parsing, fail-open) is under
# test. Run: bash tests/review-before-commit.test.sh
set -uo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/claude/hooks/review-before-commit.sh"
pass=0; fail=0

ok()   { printf 'ok   - %s\n' "$1"; pass=$((pass+1)); }
bad()  { printf 'FAIL - %s\n' "$1"; fail=$((fail+1)); }
check(){ if eval "$2"; then ok "$1"; else bad "$1 :: $2 :: got=[$out]"; fi; }

# A throwaway git repo with one committed file.
new_repo() {
  d="$(mktemp -d)"
  git -C "$d" init -q
  git -C "$d" config user.email t@e
  git -C "$d" config user.name t
  git -C "$d" config commit.gpgsign false
  printf 'orig\n' > "$d/f.txt"
  git -C "$d" add f.txt
  git -C "$d" commit -qm init
  printf '%s' "$d"
}

stub() { s="$(mktemp)"; printf '%s\n' "$1" > "$s"; printf '%s' "$s"; }

# 1. Reviewer reports a violation on staged diff -> hook blocks the commit.
d="$(new_repo)"; printf 'orig\nnew\n' > "$d/f.txt"; git -C "$d" add f.txt
s="$(stub 'REVIEW: FAIL
- f.txt: 不要な否定コメント')"
out="$(cd "$d" && TOOL_INPUT='{"command":"git commit -m x"}' REVIEW_CMD="cat $s" bash "$HOOK")"
check "violation blocks commit"        'printf "%s" "$out" | grep -q "\"decision\": \"block\""'
check "block reason carries findings"  'printf "%s" "$out" | grep -q "不要な否定コメント"'

# 2. Reviewer passes -> hook is silent and the commit proceeds.
d="$(new_repo)"; printf 'orig\nnew\n' > "$d/f.txt"; git -C "$d" add f.txt
s="$(stub 'REVIEW: PASS')"
out="$(cd "$d" && TOOL_INPUT='{"command":"git commit -m x"}' REVIEW_CMD="cat $s" bash "$HOOK")"
check "pass produces no block"         '! printf "%s" "$out" | grep -q "block"'

# 3. Non-commit command is ignored (reviewer never consulted).
d="$(new_repo)"; printf 'orig\nnew\n' > "$d/f.txt"; git -C "$d" add f.txt
s="$(stub 'REVIEW: FAIL')"
out="$(cd "$d" && TOOL_INPUT='{"command":"git status"}' REVIEW_CMD="cat $s" bash "$HOOK")"
check "git status skipped"             '[ -z "$out" ]'

# 4. Nothing staged -> nothing to review, hook stays silent.
d="$(new_repo)"
s="$(stub 'REVIEW: FAIL')"
out="$(cd "$d" && TOOL_INPUT='{"command":"git commit -m x"}' REVIEW_CMD="cat $s" bash "$HOOK")"
check "empty staged diff skipped"      '[ -z "$out" ]'

# 5. Reviewer error/timeout -> fail open (do not brick the commit).
d="$(new_repo)"; printf 'orig\nnew\n' > "$d/f.txt"; git -C "$d" add f.txt
out="$(cd "$d" && TOOL_INPUT='{"command":"git commit -m x"}' REVIEW_CMD="false" bash "$HOOK")"
check "reviewer failure fails open"    '[ -z "$out" ]'

# 6. -a commits tracked-but-unstaged changes -> reviewed via diff HEAD.
d="$(new_repo)"; printf 'orig\nnew\n' > "$d/f.txt"   # modified, NOT staged
s="$(stub 'REVIEW: FAIL
- f.txt: 違反')"
out="$(cd "$d" && TOOL_INPUT='{"command":"git commit -am x"}' REVIEW_CMD="cat $s" bash "$HOOK")"
check "-am reviews unstaged tracked"   'printf "%s" "$out" | grep -q "\"decision\": \"block\""'

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
