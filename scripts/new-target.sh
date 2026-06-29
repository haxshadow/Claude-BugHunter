#!/usr/bin/env bash
# =====================================================================
# new-target.sh — scaffold a ready-to-hunt workspace for one target.
#
# Creates  <base>/<target>/  with:
#   CLAUDE.md   — auto-read by Claude Code when you run `claude` from here;
#                 tells it the target, scope, rules, and workflow
#   AGENTS.md   — same content for OpenCode / Codex / Hermes
#   scope.json  — engine/scope.py format (code-enforced, deny-wins)
#   scope.txt   — paste the program's raw scope here for reference
#   notes/{recon,findings,reports,leads}/
#
# Usage:
#   new-target acme.com
#   new-target acme.com --base ~/hunting          # custom base dir
#   new-target acme.com --in "*.acme.com,acme.com" --out "staging.acme.com"
#
# Then:
#   cd ~/hunting/acme.com && claude        # Claude reads CLAUDE.md, knows everything
# =====================================================================
set -uo pipefail

TARGET=""
BASE="$HOME/hunting"
IN_SCOPE=""
OUT_SCOPE=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --base) shift; BASE="${1:?--base needs a value}" ;;
    --in)   shift; IN_SCOPE="${1:-}" ;;
    --out)  shift; OUT_SCOPE="${1:-}" ;;
    -h|--help) sed -n '2,22p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'; exit 0 ;;
    *) TARGET="$1" ;;
  esac
  shift
done

[ -z "$TARGET" ] && { echo "usage: new-target <target.com> [--base DIR] [--in a,b] [--out c,d]"; exit 2; }

# strip scheme/path if the user pasted a URL
TARGET="${TARGET#http://}"; TARGET="${TARGET#https://}"; TARGET="${TARGET%%/*}"

DIR="$BASE/$TARGET"
if [ -d "$DIR" ]; then
  echo "⚠ $DIR already exists — opening it (nothing overwritten)."
  echo "  cd \"$DIR\" && claude"
  exit 0
fi

mkdir -p "$DIR/notes/recon" "$DIR/notes/findings" "$DIR/notes/reports" "$DIR/notes/leads"

# default scope = the apex + its wildcard, unless the user gave --in
[ -z "$IN_SCOPE" ] && IN_SCOPE="$TARGET,*.$TARGET"

# build JSON arrays from comma lists
_json_arr() {
  local IFS=','; local out="" first=1
  for x in $1; do
    x="$(echo "$x" | xargs)"; [ -z "$x" ] && continue
    [ $first -eq 1 ] && first=0 || out+=", "
    out+="\"$x\""
  done
  echo "[$out]"
}
IN_JSON="$(_json_arr "$IN_SCOPE")"
OUT_JSON="$(_json_arr "$OUT_SCOPE")"

# ── scope.json (code-enforced by engine/scope.py) ──
cat > "$DIR/scope.json" <<EOF
{
  "name": "$TARGET",
  "in_scope": $IN_JSON,
  "out_of_scope": $OUT_JSON,
  "seeds": ["https://$TARGET"]
}
EOF

# ── scope.txt (paste raw program scope here) ──
cat > "$DIR/scope.txt" <<'EOF'
# Paste the program's FULL scope text here (copy from HackerOne/Bugcrowd page).
# Then in Claude:  "scope.txt পড়ে scope.json আপডেট করে দাও আর বুঝিয়ে দাও"
#
# In scope:
#   -
# Out of scope:
#   -
# Path exclusions / special rules:
#   -
# Safe harbor: yes / no
#
# ── TESTING REQUIREMENTS (program-specific rules — NOT host-based, so NOT
#    enforced by scope.json. Claude MUST read these and obey them) ──
# Account / email rule (e.g. register with name+bugcrowd@gmail.com, @bugcrowdninja.com,
#   or a given test account):
#   -
# Username / handle to use when signing up or posting:
#   -
# Required traffic identifier (e.g. header  X-Bug-Bounty: <username>  on every request):
#   -
# Rate limits / throttling (e.g. max N req/sec, no automated scanners):
#   -
# Credentials provided by the program (test accounts, API keys):
#   -
# Anything else the program says you MUST or MUST NOT do:
#   -
EOF

# ── CLAUDE.md (Claude Code auto-reads this) ──
cat > "$DIR/CLAUDE.md" <<EOF
# Target: $TARGET

I am hunting **$TARGET** under an authorized bug bounty program. BugHunter Combo
skills are installed globally — use them.

## Scope (authoritative: scope.json — code-enforced, deny-wins)
- In-scope:    $(echo "$IN_SCOPE" | sed 's/,/, /g')
- Out-of-scope: $([ -n "$OUT_SCOPE" ] && echo "$OUT_SCOPE" | sed 's/,/, /g' || echo "(none yet — fill scope.txt)")
- Full program scope text: see scope.txt
- Before the FIRST request, read scope.json. NEVER send a request out of scope.

## STEP 0 — set up scope myself (do this FIRST, before anything else)
If scope.txt has the program's raw scope pasted in, and scope.json is still the
default (just the apex), then BEFORE any recon:
1. Read scope.txt and explain in-scope vs out-of-scope in plain language.
2. Rewrite scope.json with the full in_scope + out_of_scope lists.
3. CRITICAL: an out-of-scope wildcard (e.g. *.foo.com) must NOT block an
   explicitly in-scope host (e.g. next.foo.com). Scope is deny-wins — so list
   the specific out-of-scope hosts individually rather than a wildcard that
   would swallow an in-scope target. (real example: *.flatmates.com.au as OOS
   wrongly blocks the in-scope next.flatmates.com.au.)
4. Verify with: python3 ~/Desktop/bughunting/Claude-BugHunter/engine/scope.py
   logic — test a few in-scope and out-of-scope hosts and show me the results.
The operator should NOT have to set scope by hand — you do it from scope.txt.

## Rules of engagement
- Authorized testing only. Stay strictly in scope.
- No destructive actions (no writes/deletes/spam/DoS). Read-only PoC.
- PoC or GTFO — no finding without a full, reproducible end-to-end PoC.
- Don't overstate impact. Kill weak/theoretical findings (7-Question Gate).
- Save everything under notes/ (reproducible: full URL, method, headers, body, response).

## Note structure (more at bottom, fewer reach the top)
- notes/recon/    — raw tool output, observed behavior
- notes/leads/    — interesting things to investigate
- notes/findings/ — validated bugs with full PoC
- notes/reports/  — polished, submission-ready

## Workflow (follow in order)
1. scope    — read scope.json / scope.txt, confirm what's in scope
2. recon    — /recon $TARGET   (subdomains, live hosts, tech, endpoints)
3. surface  — /surface $TARGET (rank — where to start)
4. intel    — /intel $TARGET   (CVEs + disclosed reports)
5. hunt     — /hunt $TARGET    (or: "test <url> for <vuln>")
6. validate — /validate        (7-Question Gate before any report)
7. chain    — /chain           (turn low → high)
8. report   — /report          (submission-ready)

Start by loading the **bb-methodology** skill, then read scope.json and propose a plan.
Resume later with **/pickup $TARGET**.

## The only question that matters
"Can an attacker do this RIGHT NOW against a normal user and cause real harm
(money / PII / ATO / RCE)?" — if no, STOP and move on.
EOF

cp "$DIR/CLAUDE.md" "$DIR/AGENTS.md"

echo "✓ New target workspace ready: $DIR"
echo ""
echo "  $DIR/"
echo "  ├── CLAUDE.md   (Claude auto-reads — target, scope, workflow)"
echo "  ├── AGENTS.md   (same, for OpenCode / Codex / Hermes)"
echo "  ├── scope.json  (in: $IN_SCOPE)"
echo "  ├── scope.txt   (paste full program scope here)"
echo "  └── notes/{recon,leads,findings,reports}/"
echo ""
echo "Next:"
echo "  1) paste the program's scope into  $DIR/scope.txt"
echo "  2) cd \"$DIR\" && claude"
echo "  3) say:  \"scope.txt পড়ে scope.json ঠিক করো, তারপর recon শুরু করো\""
