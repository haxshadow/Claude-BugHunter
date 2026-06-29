<h1 align="center">BugHunter Combo</h1>

<p align="center">
  <b>One bug-bounty toolkit · four AI harnesses · free-first AI.</b><br>
  <sub>Recon → hunt → validate → report. Works with or without a subscription.</sub>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square" alt="MIT">
  <img src="https://img.shields.io/badge/Python-3.9+-3776AB.svg?style=flat-square" alt="Python 3.9+">
  <img src="https://img.shields.io/badge/Harnesses-Claude%20·%20OpenCode%20·%20Codex%20·%20Hermes-D97706.svg?style=flat-square" alt="4 harnesses">
  <img src="https://img.shields.io/badge/AI-Ollama%20·%20Groq%20·%20DeepSeek%20·%20Claude%20·%20OpenAI-brightgreen.svg?style=flat-square" alt="multi-provider">
</p>

---

## What is this?

A merge of three bug-bounty toolkits into one — see [`CREDITS.md`](CREDITS.md). It gives you **two layers** that work together:

- **Knowledge layer** — 79 skills + 27 slash commands + 9 specialist agents. Installs into **Claude Code · OpenCode · Codex CLI · Hermes Agent**. Describe your target in plain English and the right skill auto-loads.
- **Standalone engine** — a `bughunter` CLI powered by a **free-first multi-provider** AI layer. No subscription required: it auto-detects Ollama → Groq → DeepSeek → Claude → OpenAI (free options first).

> **harness ≠ AI provider.** Harnesses (Claude Code, OpenCode, Codex, Hermes) run skills/commands on their own model. The standalone CLI is what gives you the free providers — and the deterministic engine now falls back to those free providers too when no `claude` binary is present.

---

## Free AI Providers (auto-detected, free-first priority)

| Provider | Cost | Privacy | Speed | Get started |
|---|---|---|---|---|
| **Ollama** | 100% free · local | Full — stays on your machine | Fast | `ollama pull qwen2.5:14b` |
| **Groq** | Free tier | Cloud | Very fast | console.groq.com → API key |
| **DeepSeek** | Very cheap | Cloud | Fast | platform.deepseek.com |
| Claude API | Paid | Cloud | Fast | console.anthropic.com |
| OpenAI | Paid | Cloud | Fast | platform.openai.com |

Auto-detect order: **Ollama → Groq → DeepSeek → Claude → OpenAI** (and 8 more in `brain.py`). Switch anytime with `bughunter setup`.

---

## Install

```bash
git clone <this-repo> bughunter-combo
cd bughunter-combo
chmod +x install.sh
./install.sh                 # both layers: detect harnesses + install standalone CLI
```

Selective installs:

```bash
./install.sh --skills-only            # just the harness skills/commands/agents
./install.sh --standalone-only        # just the `bughunter` CLI
./install.sh --harness opencode       # one harness only
./install.sh --with-tools             # also install subfinder/httpx/nuclei/…
./install.sh --burp-mcp               # wire Burp MCP into non-Claude harnesses
```

As a Claude Code plugin:

```text
/plugin marketplace add <this-repo>
/plugin install bughunter-combo@bughunter-combo
```

---

## Use

**Standalone (no subscription):**

```bash
bughunter setup                # pick a free provider
bughunter providers            # see availability + free-first priority
bughunter recon target.com
bughunter hunt  target.com
bughunter validate "<finding>" # 7-Question Gate
bughunter report
bughunter chat                 # interactive AI hunting shell
```

**In any harness:** describe the target in plain English (skills auto-load), or use
`/recon /hunt /validate /report /chain /web3-audit /token-scan …`.

**Deterministic engagement engine** (scope enforced in code, adversarial hunt→validate):

```bash
python3 engine/engine.py --scope engine/engagement.example.json --mock   # dry-run
# free-provider engine (no claude binary needed):
BBHUNT_ENGINE_PROVIDER=ollama python3 engine/engine.py --scope my.json --hunt
```

---

## What's inside

- **79 skills** — 48 `hunt-*` per-class (sqli, xss, idor, ssrf, oauth, saml, …), enterprise/red-team (M365/Entra, Okta, vCenter, VPN, SharePoint, APK), recon/OSINT, web3 + meme-coin audit, mobile, CI/CD, credential-attack, methodology, reporting, validation gates, and a strict Bugcrowd N/A-prevention triager.
- **27 commands** · **9 agents** · **Burp + HackerOne MCP** · **web3 audit guide** · **cross-session hunt memory**.
- **Multi-provider `brain.py`** (13 providers) · **standalone CLI** · **ReAct autonomous agent** · **deterministic engagement engine** with code-enforced scope.

---

<sub>MIT. For authorized security testing only — always test within an approved program scope. See <a href="TERMS.md">TERMS.md</a> and <a href="CREDITS.md">CREDITS.md</a>.</sub>
