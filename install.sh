#!/usr/bin/env bash
# Deploy the hooks/settings/CLAUDE.md payload under claude/ to a target
# .claude directory — either the global ~/.claude or a specific project.
#
# Usage:
#   ./install.sh --global               # deploy to ~/.claude
#   ./install.sh --project <path>       # deploy to <path>/.claude
#   ./install.sh --project <path> --dry-run
#   ./install.sh --global --force       # skip confirmation prompt
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR/claude"

MODE=""
PROJECT_PATH=""
DRY_RUN=0
FORCE=0

die() { echo "error: $*" >&2; exit 1; }

usage() {
  awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "${BASH_SOURCE[0]}"
  exit "${1:-0}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --global) MODE="global"; shift ;;
    --project) MODE="project"; PROJECT_PATH="${2:-}"; [ -n "$PROJECT_PATH" ] || die "--project requires a path"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --force|-f) FORCE=1; shift ;;
    -h|--help) usage 0 ;;
    *) die "unknown argument: $1 (see --help)" ;;
  esac
done

[ -n "$MODE" ] || die "specify --global or --project <path> (see --help)"
command -v jq >/dev/null 2>&1 || die "jq is required"
[ -d "$SRC" ] || die "payload not found: $SRC"

# Resolve target .claude directory.
if [ "$MODE" = "global" ]; then
  TARGET="$HOME/.claude"
  REWRITE=0          # payload already uses ~/.claude paths
else
  case "$PROJECT_PATH" in /*) : ;; *) PROJECT_PATH="$(pwd)/$PROJECT_PATH" ;; esac
  [ -d "$PROJECT_PATH" ] || die "project path does not exist: $PROJECT_PATH"
  TARGET="$PROJECT_PATH/.claude"
  REWRITE=1          # rewrite ~/.claude -> $CLAUDE_PROJECT_DIR/.claude
fi

echo "Source : $SRC"
echo "Target : $TARGET"
echo "Mode   : $MODE (dry-run=$DRY_RUN)"

# Build the (possibly path-rewritten) payload settings into a temp file.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
PAYLOAD_SETTINGS="$TMP/payload.json"
if [ "$REWRITE" = "1" ]; then
  sed 's#~/.claude/hooks/#$CLAUDE_PROJECT_DIR/.claude/hooks/#g' "$SRC/settings.json" > "$PAYLOAD_SETTINGS"
else
  cp "$SRC/settings.json" "$PAYLOAD_SETTINGS"
fi

# Deep-merge payload into existing target settings:
#   - permissions.allow      -> sorted unique union
#   - hooks.<event> arrays   -> concatenated, order-preserving dedupe
#   - everything else        -> existing preserved, payload keys added
EXISTING="$TMP/existing.json"
if [ -f "$TARGET/settings.json" ]; then
  cp "$TARGET/settings.json" "$EXISTING"
else
  echo '{}' > "$EXISTING"
fi

MERGED="$TMP/merged.json"
jq -n --slurpfile e "$EXISTING" --slurpfile p "$PAYLOAD_SETTINGS" '
  def uniq: reduce .[] as $x ([]; if any(.[]; . == $x) then . else . + [$x] end);
  ($e[0]) as $e | ($p[0]) as $p |
  ($e * $p)
  | .permissions.allow = (((($e.permissions.allow // []) + ($p.permissions.allow // []))) | unique)
  | reduce (($p.hooks // {}) | keys[]) as $ev (.;
      .hooks[$ev] = ((($e.hooks[$ev] // []) + ($p.hooks[$ev] // [])) | uniq))
' > "$MERGED"

# Content directories copied verbatim (no path rewrite needed): markdown that
# Claude Code auto-discovers. Add new ones here and they deploy automatically.
CONTENT_DIRS="commands skills"

# Show plan.
echo
echo "Files to copy into $TARGET/hooks/:"
for f in "$SRC"/hooks/*; do echo "  $(basename "$f")"; done
echo "File to copy: $TARGET/CLAUDE.md"
for d in $CONTENT_DIRS; do
  [ -d "$SRC/$d" ] || continue
  echo "Directory to sync: $TARGET/$d/ ($(find "$SRC/$d" -type f | wc -l | tr -d ' ') files)"
done
echo
echo "settings.json diff (current -> merged):"
diff <(jq -S . "$EXISTING") <(jq -S . "$MERGED") || true

if [ "$DRY_RUN" = "1" ]; then
  echo
  echo "dry-run: no changes written."
  exit 0
fi

if [ "$FORCE" != "1" ]; then
  printf '\nProceed? [y/N] '
  read -r ans
  case "$ans" in y|Y|yes|YES) : ;; *) echo "aborted."; exit 1 ;; esac
fi

# Apply.
mkdir -p "$TARGET/hooks"
cp "$SRC"/hooks/* "$TARGET/hooks/"
chmod +x "$TARGET"/hooks/*.sh "$TARGET"/hooks/*.py 2>/dev/null || true
cp "$SRC/CLAUDE.md" "$TARGET/CLAUDE.md"

for d in $CONTENT_DIRS; do
  [ -d "$SRC/$d" ] || continue
  mkdir -p "$TARGET/$d"
  cp -R "$SRC/$d/." "$TARGET/$d/"
done

if [ -f "$TARGET/settings.json" ]; then
  cp "$TARGET/settings.json" "$TARGET/settings.json.bak.$(date +%Y%m%d%H%M%S)"
fi
cp "$MERGED" "$TARGET/settings.json"

echo
echo "done: deployed to $TARGET"
