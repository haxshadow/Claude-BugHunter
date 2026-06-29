# Credits & Attribution

**BugHunter Combo** merges three open-source bug-bounty toolkits. All three are MIT-licensed; this combo is MIT as well. Full credit to the original authors:

| Source project | Author | What was taken |
|---|---|---|
| [claude-bug-bounty](https://github.com/shuvonsec/claude-bug-bounty) | **shuvonsec** | `brain.py` free-first multi-provider LLM layer (13 providers), standalone `bughunter` CLI (`engine.py`), ReAct autonomous agent (`agent.py`), `tools/` scanner pipeline, `memory/`, `web3/` audit guide, 9 specialist agents, slash commands, `security-arsenal` / `web2-vuln-classes` / `credential-attack` / `mobile-pentest` / `cicd-security` / `graphql-audit` skills |
| [Claude-BugHunter](https://github.com/elementalsouls/Claude-BugHunter) | **Sachin Sharma (elementalsouls)** | 48 `hunt-*` per-class skills (built from 681 disclosed HackerOne reports), enterprise/red-team skills (M365/Entra, Okta, vCenter, VPN, SharePoint, APK), deterministic engagement engine (`engine/` — scope/state enforced in code, adversarial hunt→validate), 4-harness installer pattern, Burp MCP wiring |
| [claude-code-bb](https://github.com/) (LoganSec) | **LoganSec** | Strict Bugcrowd N/A-prevention `triage-bugcrowd` skill, `report-draft` and `hypothesis-gen` skills, hunter-mindset configuration |

### How the merge works
- **Skills** deduplicated by name; where two projects shipped the same skill the richer copy was kept (e.g. `security-arsenal` from shuvonsec, most `hunt-*` from elementalsouls).
- **Engine** made provider-aware: the deterministic `engine/agent.py` now falls back to `brain.py`'s free providers when the `claude` binary is absent.
- **One installer** routes the knowledge layer to all four harnesses and installs the standalone CLI.

For authorized security testing only. See `TERMS.md`.
