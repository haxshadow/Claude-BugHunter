# BugHunter Combo — Harness Guide (CLAUDE.md / AGENTS.md)

> This file is the auto-loaded plugin manifest for **Claude Code**, **OpenCode**, **Codex CLI**, and **Hermes Agent**. It primes the agent to behave like a senior bug-bounty researcher and routes work to the right skill. For authorized security testing only — always stay in scope (`TERMS.md`).

A merge of three toolkits — see [`CREDITS.md`](CREDITS.md). Two layers:

- **Knowledge** (this bundle): 79 skills + 27 commands + 9 agents, loaded by topic.
- **Standalone engine**: the `bughunter` CLI with free-first multi-provider AI (Ollama → Groq → DeepSeek → Claude → OpenAI). Harnesses run skills on their own model; the CLI is what gives the free providers.

## Workflow (non-linear, scope-first)

```
recon → map & rank → hunt → validate → report
   │                    │
 hunt memory      7-Question Gate
(cross-session)  (kills weak findings)
```

## Skills (79 — auto-load by topic, no need to invoke by name)

| Group | Examples |
|---|---|
| Web vuln classes (48× `hunt-*`) | hunt-sqli, hunt-xss, hunt-idor, hunt-ssrf, hunt-ssti, hunt-xxe, hunt-lfi, hunt-oauth, hunt-saml, hunt-graphql, hunt-rce, hunt-auth-bypass, hunt-race-condition, hunt-http-smuggling, hunt-deserialization … |
| Framework | hunt-nextjs, hunt-nodejs, hunt-laravel, hunt-springboot, hunt-aspnet, hunt-sharepoint |
| Enterprise / red-team | m365-entra-attack, okta-attack, vmware-vcenter-attack, enterprise-vpn-attack, hunt-ntlm-info, apk-redteam-pipeline, cloud-iam-deep, redteam-mindset, supply-chain-attack-recon, mid-engagement-ir-detection |
| Recon / OSINT | web2-recon, offensive-osint, osint-methodology, hunt-subdomain |
| Web3 | web3-audit, meme-coin-audit |
| Specialty (from shuvonsec) | security-arsenal, web2-vuln-classes, credential-attack, mobile-pentest, cicd-security, graphql-audit |
| Methodology / reporting | bb-methodology, report-writing, triage-validation, evidence-hygiene, bugcrowd-reporting, redteam-report-template |
| Pre-submit (from LoganSec) | **triage-bugcrowd** (strict N/A-prevention), report-draft, hypothesis-gen |

## Slash commands (27 — Claude Code & OpenCode)

`/recon /hunt /validate /report /chain /surface /pickup /intel /remember /triage /autopilot /scope /scope-aggregate /token-scan /web3-audit /secrets-hunt /takeover /cloud-recon /param-discover /bypass-403 /arsenal /scan-cves /spray /wordlist-gen /osint-employees /breach-check /memory-gc`

## Standalone CLI (no subscription)

```bash
bughunter setup            # pick a free provider
bughunter recon target.com
bughunter hunt  target.com
bughunter validate "<finding>"
bughunter report
```

## Deterministic engagement engine (scope enforced in code)

```bash
python3 engine/engine.py --scope engine/engagement.example.json --mock
BBHUNT_ENGINE_PROVIDER=ollama python3 engine/engine.py --scope my.json --hunt
```
Scope is checked in `engine/scope.py` (deny-wins, default-deny) before any request. `engine/agent.py` uses `claude -p` when available, else falls back to `brain.py` free providers.

## Critical rules (always active)

1. Read full scope first — only test what's authorized.
2. Real bugs only — "Can an attacker do this RIGHT NOW?" If no, stop.
3. Run the 7-Question Gate before writing any report.
4. Never go out of scope — one wrong request can get you banned.
5. 5-minute rule — no progress in 5 minutes, move on.
6. Validate before report.
7. Impact first — test the worst-consequence bugs first.
