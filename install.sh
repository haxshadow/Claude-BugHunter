#!/usr/bin/env bash
# =====================================================================
# install.sh — BugHunter Combo unified installer
#
# Two layers, one command:
#   A) KNOWLEDGE  — skills + commands + agents into every detected harness
#                   (Claude Code · OpenCode · Codex CLI · Hermes Agent)
#   B) ENGINE     — standalone `bughunter` CLI powered by free-first
#                   multi-provider AI (Ollama · Groq · DeepSeek · Claude · OpenAI)
#
# DEFAULT (no flags):  install BOTH layers — auto-detect harnesses + install the
#                      standalone CLI. Then run `bughunter setup` to pick a provider.
#
# FLAGS:
#   --harness <t>     install knowledge layer to a specific harness only:
#                       claude | opencode | codex | hermes | all   (default: all/detect)
#   --skills-only     install knowledge layer ONLY (no standalone CLI)
#   --standalone-only install the `bughunter` CLI ONLY (no harness skills)
#   --with-tools      also run install_tools.sh (subfinder/httpx/nuclei/katana/ffuf…)
#   --burp-mcp        wire an existing Burp MCP server into non-Claude harnesses
#   --normalize-frontmatter  strip non-standard keys (sources/report_count) from
#                            the NON-Claude skill copies (some harnesses reject them)
#   -h | --help       show this help
#
# Idempotent. Existing skills/commands are backed up OUTSIDE the loading path
# (~/.claude/install-backups/<ts>/) so backups never load as duplicate skills.
# Requires: bash. (--burp-mcp / Codex truncation also use python3.)
# =====================================================================
set -euo pipefail

REPO_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BACKUP_DEST="$HOME/.claude/install-backups/$(date +%Y%m%d-%H%M%S)"

usage() { sed -n '2,33p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'; }

HARNESS="all"
DO_SKILLS=1
DO_STANDALONE=1
DO_TOOLS=0
DO_MCP=0
NORMALIZE=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --harness) shift; HARNESS="${1:?--harness requires a value}" ;;
    --harness=*) HARNESS="${1#*=}" ;;
    --skills-only) DO_STANDALONE=0 ;;
    --standalone-only) DO_SKILLS=0 ;;
    --with-tools) DO_TOOLS=1 ;;
    --burp-mcp) DO_MCP=1 ;;
    --normalize-frontmatter) NORMALIZE=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1 (try --help)" >&2; exit 2 ;;
  esac
  shift
done

SKILL_COUNT="$(find "$REPO_DIR/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
CMD_COUNT="$(find "$REPO_DIR/commands" -maxdepth 1 -name '*.md' ! -name README.md | wc -l | tr -d ' ')"

# ── helpers ──────────────────────────────────────────────────────────
# Copy every skill folder into <dest>/skills, backing up same-name dirs OUTSIDE
# the loading path. $2 = label for backup subfolder + logging.
install_skills() {
  local dest="$1/skills" label="$2" name
  mkdir -p "$dest"
  echo "  skills →  $dest   ($label)"
  for skill_dir in "$REPO_DIR/skills"/*/; do
    name="$(basename "$skill_dir")"
    if [ -d "$dest/$name" ] && [ ! -L "$dest/$name" ]; then
      mkdir -p "$BACKUP_DEST/$label-skills"
      mv "$dest/$name" "$BACKUP_DEST/$label-skills/$name"
    fi
    cp -r "$skill_dir" "$dest/$name"
  done
  echo "    ✓ $SKILL_COUNT skills"
}

install_commands() {
  local dest="$1/commands" label="$2" name
  mkdir -p "$dest"
  for f in "$REPO_DIR/commands"/*.md; do
    [ -e "$f" ] || continue
    name="$(basename "$f")"
    [ "$name" = "README.md" ] && continue
    if [ -f "$dest/$name" ] && [ ! -L "$dest/$name" ]; then
      mkdir -p "$BACKUP_DEST/$label-commands"
      mv "$dest/$name" "$BACKUP_DEST/$label-commands/$name"
    fi
    cp "$f" "$dest/$name"
  done
  echo "  commands →  $dest   ($CMD_COUNT, $label)"
}

install_agents() {
  local dest="$1/agents" label="$2" name
  [ -d "$REPO_DIR/agents" ] || return 0
  mkdir -p "$dest"
  for f in "$REPO_DIR/agents"/*.md; do
    [ -e "$f" ] || continue
    name="$(basename "$f")"
    [ "$name" = "README.md" ] && continue
    cp "$f" "$dest/$name"
  done
  echo "  agents →  $dest   ($label)"
}

# Codex (~/.agents/skills) HARD-rejects descriptions > 1024 chars. Truncate in
# THAT copy only; optionally strip non-standard frontmatter keys.
codex_normalize() {
  command -v python3 >/dev/null 2>&1 || return 0
  python3 - "$1/skills" "$NORMALIZE" <<'PY'
import os, re, sys
root, strip_extra = sys.argv[1], sys.argv[2] == "1"
LIMIT = 1024
for name in sorted(os.listdir(root)):
    p = os.path.join(root, name, "SKILL.md")
    if not os.path.isfile(p):
        continue
    lines = open(p, encoding="utf-8").read().split("\n")
    out, changed = [], False
    for i, line in enumerate(lines):
        m = re.match(r'^description:\s*(.*)$', line) if i < 12 else None
        if m:
            val = m.group(1)
            quoted = len(val) >= 2 and val[0] == val[-1] and val[0] in "\"'"
            inner = val[1:-1] if quoted else val
            if len(inner) > LIMIT:
                cut = inner[:LIMIT - 2].rsplit(" ", 1)[0].rstrip(" ,;:—-")
                line = 'description: "' + cut + '…"'
                changed = True
                print(f"    ✂ truncated {name} ({len(inner)}→{len(cut)+1}, Codex 1024 limit)")
        if strip_extra and i < 12 and re.match(r'^(sources|report_count):\s', line):
            changed = True
            continue
        out.append(line)
    if changed:
        open(p, "w", encoding="utf-8").write("\n".join(out))
PY
}

# ── harness detection ────────────────────────────────────────────────
HAS_CLAUDE=0; HAS_OPENCODE=0; HAS_CODEX=0; HAS_HERMES=0
detect_harnesses() {
  if command -v claude   >/dev/null 2>&1 || [ -d "$HOME/.claude" ];          then HAS_CLAUDE=1; fi
  if command -v opencode >/dev/null 2>&1 || [ -d "$HOME/.config/opencode" ]; then HAS_OPENCODE=1; fi
  if command -v codex    >/dev/null 2>&1 || [ -d "$HOME/.codex" ];           then HAS_CODEX=1; fi
  if command -v hermes   >/dev/null 2>&1 || [ -d "$HOME/.hermes" ];          then HAS_HERMES=1; fi
}

# ── LAYER A: knowledge into harnesses ────────────────────────────────
do_knowledge() {
  echo ""
  echo "── Knowledge layer (skills + commands + agents) ──"
  detect_harnesses

  local targets="$HARNESS"
  if [ "$HARNESS" = "all" ]; then
    echo "Detecting installed harnesses:"
    [ "$HAS_CLAUDE"   = 1 ] && echo "  ✓ Claude Code"
    [ "$HAS_OPENCODE" = 1 ] && echo "  ✓ OpenCode"
    [ "$HAS_CODEX"    = 1 ] && echo "  ✓ Codex CLI"
    [ "$HAS_HERMES"   = 1 ] && echo "  ✓ Hermes Agent"
    if [ "$HAS_CLAUDE$HAS_OPENCODE$HAS_CODEX$HAS_HERMES" = "0000" ]; then
      echo "  (none detected — installing to Claude Code path ~/.claude anyway)"
      HAS_CLAUDE=1
    fi
  fi

  # Claude Code  → ~/.claude/{skills,commands,agents}
  if [ "$targets" = "claude" ] || { [ "$targets" = "all" ] && [ "$HAS_CLAUDE" = 1 ]; }; then
    echo "Claude Code:"
    install_skills   "$HOME/.claude" "claude"
    install_commands "$HOME/.claude" "claude"
    install_agents   "$HOME/.claude" "claude"
  fi
  # OpenCode → ~/.config/opencode/{skills,commands,agents}
  if [ "$targets" = "opencode" ] || { [ "$targets" = "all" ] && [ "$HAS_OPENCODE" = 1 ]; }; then
    OC="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"
    echo "OpenCode:"
    install_skills   "$OC" "opencode"
    install_commands "$OC" "opencode"
    install_agents   "$OC" "opencode"
  fi
  # Codex CLI → ~/.agents/{skills,commands}  (+ description truncation)
  if [ "$targets" = "codex" ] || { [ "$targets" = "all" ] && [ "$HAS_CODEX" = 1 ]; }; then
    echo "Codex CLI:"
    install_skills   "$HOME/.agents" "codex"
    install_commands "$HOME/.agents" "codex"
    codex_normalize  "$HOME/.agents"
  fi
  # Hermes Agent → ~/.hermes/skills
  if [ "$targets" = "hermes" ] || { [ "$targets" = "all" ] && [ "$HAS_HERMES" = 1 ]; }; then
    echo "Hermes Agent:"
    install_skills   "$HOME/.hermes" "hermes"
  fi

  # Optional: wire Burp MCP into non-Claude harnesses
  if [ "$DO_MCP" = 1 ]; then
    if [ -f "$REPO_DIR/scripts/setup_harness_mcp.py" ] && command -v python3 >/dev/null 2>&1; then
      local mcp_targets=""
      [ "$HAS_OPENCODE" = 1 ] && mcp_targets="$mcp_targets --opencode"
      [ "$HAS_CODEX"    = 1 ] && mcp_targets="$mcp_targets --codex"
      [ "$HAS_HERMES"   = 1 ] && mcp_targets="$mcp_targets --hermes"
      if [ -n "$mcp_targets" ]; then
        # shellcheck disable=SC2086
        python3 "$REPO_DIR/scripts/setup_harness_mcp.py" $mcp_targets || \
          echo "  ⚠ Burp MCP wiring reported an issue"
      else
        echo "  ⚠ --burp-mcp: no non-Claude harness detected, skipping"
      fi
    else
      echo "  ⚠ --burp-mcp: setup_harness_mcp.py or python3 missing, skipping"
    fi
  fi
}

# ── LAYER B: standalone bughunter CLI ────────────────────────────────
do_standalone() {
  echo ""
  echo "── Standalone engine (free-first multi-provider) ──"
  local engine="$REPO_DIR/engine.py"
  chmod +x "$engine"

  local bin_dir="" sudo=""
  if [ -w /usr/local/bin ]; then
    bin_dir="/usr/local/bin"
  elif sudo -n true 2>/dev/null; then
    bin_dir="/usr/local/bin"; sudo="sudo"
  else
    bin_dir="$HOME/.local/bin"; mkdir -p "$bin_dir"
  fi
  local target="$bin_dir/bughunter"
  $sudo rm -f "$target" 2>/dev/null || true
  $sudo ln -sf "$engine" "$target"
  if [ -e "$target" ]; then
    echo "  ✓ bughunter → $target"
  else
    echo "  ⚠ could not link to $bin_dir — add alias: alias bughunter='python3 $engine'"
  fi
  case ":$PATH:" in
    *":$bin_dir:"*) : ;;
    *) echo "  ⚠ $bin_dir not on PATH — add: export PATH=\"$bin_dir:\$PATH\"" ;;
  esac

  if command -v ollama >/dev/null 2>&1; then
    echo "  ✓ Ollama detected (free local provider ready)"
  else
    echo "  ℹ free local AI: curl -fsSL https://ollama.ai/install.sh | sh && ollama pull qwen2.5:14b"
  fi
  if command -v pip3 >/dev/null 2>&1; then
    pip3 install --quiet requests ollama 2>/dev/null || true
  fi
}

# ── run ──────────────────────────────────────────────────────────────
echo "Installing BugHunter Combo from $REPO_DIR"
echo "  $SKILL_COUNT skills · $CMD_COUNT commands"

[ "$DO_SKILLS"     = 1 ] && do_knowledge
[ "$DO_STANDALONE" = 1 ] && do_standalone

if [ "$DO_TOOLS" = 1 ] && [ -f "$REPO_DIR/install_tools.sh" ]; then
  echo ""
  echo "── External scanning tools ──"
  bash "$REPO_DIR/install_tools.sh" || echo "  ⚠ install_tools.sh reported an issue"
fi

echo ""
echo "============================================"
echo "✓ BugHunter Combo install complete"
echo "============================================"
[ -d "$BACKUP_DEST" ] && echo "Backups: $BACKUP_DEST  (outside loading paths)"
echo ""
if [ "$DO_STANDALONE" = 1 ]; then
  echo "Standalone (no subscription):"
  echo "  bughunter setup            # pick a free provider (Ollama/Groq/DeepSeek/…)"
  echo "  bughunter providers        # see what's available + free-first priority"
  echo "  bughunter recon target.com"
  echo "  bughunter hunt  target.com"
  echo "  bughunter validate \"<finding>\""
fi
if [ "$DO_SKILLS" = 1 ]; then
  echo ""
  echo "In any harness (Claude Code / OpenCode / Codex / Hermes):"
  echo "  describe your target in plain English — the right skill auto-loads"
  echo "  or use /recon /hunt /validate /report (Claude Code & OpenCode)"
fi
echo ""
