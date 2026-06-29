# 🎯 BugHunter Combo — আমার হান্টিং গাইড (সবসময় ফলো করব)

> এই নোটটা খোলা রাখো হান্টিংয়ের সময়। এলোমেলো লাগলে এখানে ফিরে আসো।
> টুলের অবস্থান: `~/Desktop/bughunting/bughunter-combo/`

---

## ০. সবচেয়ে আগে — ৩টা জিনিস মাথায় রাখো

1. **শুধু authorized target** — bug bounty program-এর in-scope asset, অথবা practice lab (testasp.vulnweb.com, DVWA, Juice Shop, PortSwigger Academy)। কখনো random সাইট নয়।
2. **THE ONLY QUESTION:** "একজন অ্যাটাকার কি **এই মুহূর্তে** এটা দিয়ে সত্যিকারের ক্ষতি করতে পারবে (টাকা / PII / ATO / RCE)?" — না হলে **থামো, পরেরটায় যাও।**
3. **5-minute rule:** কোনো লিডে ৫ মিনিটে অগ্রগতি না হলে ছেড়ে দাও।

---

## ১. সিস্টেমটা কীভাবে কাজ করে (২ স্তর)

| স্তর | কী | কোথায় চলে | AI কী ব্যবহার করে |
|---|---|---|---|
| **A. Knowledge** | ৭৯ skill + ২৭ command + ৯ agent | Claude Code · OpenCode · Codex · Hermes | harness-এর নিজের মডেল (আলাদা key লাগে না) |
| **B. Standalone** | `bughunter` CLI + engine | যেকোনো terminal | free provider (Ollama/Groq/…) — subscription ছাড়া |

> মূল কথা: **Claude Code-এ কাজ করলে provider সেটআপ লাগে না।** `bughunter` CLI চালালে শুধু তখন free provider লাগে।

**ইনস্টল কোথায় বসেছে:**
- Claude Code → `~/.claude/{skills,commands,agents}`
- OpenCode → `~/.config/opencode/...`
- Hermes → `~/.hermes/skills`
- CLI → `/usr/local/bin/bughunter`

---

## ২. পূর্ণ হান্টিং ওয়ার্কফ্লো (এই ক্রমে চলব)

```
scope → recon → surface → intel → hunt → validate → chain → report
         │                          │
    attack surface ম্যাপ      7-Question Gate (দুর্বল bug মারো)
```

### ধাপে ধাপে — কোন command, কী করে

| # | Phase | Command | কী করে |
|---|---|---|---|
| 1 | **Scope** | `/scope-aggregate <program>` | সব in-scope asset টেনে আনে (H1/Bugcrowd/Intigriti/YWH) |
| | | `/scope <asset>` | টেস্টের আগে চেক — এটা in-scope কিনা |
| 2 | **Recon** | `/recon target.com` | subdomain enum · live host · URL crawl · tech · nuclei |
| 3 | **Rank** | `/surface target.com` | কোথায় আগে শুরু করব — ranked attack surface |
| 4 | **Intel** | `/intel target.com` | এই target-এর CVE + disclosed report |
| 5 | **Hunt** | `/hunt target.com` | IDOR/XSS/SSRF/SQLi/auth… টেস্ট |
| | | (অথবা ভাষায় বলো) | "api.x.com এ IDOR খোঁজো" → ঠিক skill auto-load |
| 6 | **Validate** | `/validate` | 7-Question Gate — submit করার মতো কিনা |
| | | `/triage` | দ্রুত go/no-go |
| 7 | **Chain** | `/chain` | low bug → B, C চেইন করে high বানায় |
| 8 | **Report** | `/report` | H1/Bugcrowd/Intigriti ফরম্যাটে submission |

### Session resume / memory
| Command | কাজ |
|---|---|
| `/pickup target.com` | আগের session যেখানে ছিল সেখান থেকে |
| `/remember` | finding/technique hunt memory-তে সেভ |

---

## ৩. নির্দিষ্ট vuln খুঁজতে — skill সরাসরি ডাকো

ভাষায় বললেই অটো-লোড হয়। উদাহরণ: "testasp.vulnweb.com এ XSS টেস্ট করো" → `hunt-xss` লোড।

| যা খুঁজছ | skill |
|---|---|
| IDOR / BOLA | `hunt-idor` |
| XSS (reflected/stored/DOM) | `hunt-xss`, `hunt-dom` |
| SQL injection | `hunt-sqli` |
| SSRF | `hunt-ssrf` |
| Auth bypass | `hunt-auth-bypass`, `hunt-session` |
| OAuth / SAML | `hunt-oauth`, `hunt-saml` |
| GraphQL | `hunt-graphql` |
| File upload → RCE | `hunt-file-upload`, `hunt-rce` |
| SSTI / XXE / LFI | `hunt-ssti`, `hunt-xxe`, `hunt-lfi` |
| Race condition | `hunt-race-condition` |
| Business logic | `hunt-business-logic` |
| API misconfig (JWT/CORS/mass-assign) | `hunt-api-misconfig`, `hunt-cors` |
| Web3 / token | `web3-audit`, `meme-coin-audit` |

পদ্ধতি/সাহায্যকারী skill: `bb-methodology` (শুরুতে), `security-arsenal` (payload), `triage-validation` + `triage-bugcrowd` (submit করার আগে), `report-writing`।

---

## ৪. Burp Suite + Caido (তোমার দুটোই আছে)

প্রফেশনাল হান্টিং = **প্রতিটা request Burp/Caido দিয়ে দেখা।** এগুলো proxy — ব্রাউজার ট্রাফিক ধরে, modify করে replay করতে দেয়।

**Burp MCP যুক্ত করতে** (Claude সরাসরি Burp-এর হাত পায়):
```bash
cd ~/Desktop/bughunting/bughunter-combo
./install.sh --burp-mcp
```
এতে Claude `mcp__burp__send_http1_request` ইত্যাদি দিয়ে live request পাঠাতে পারবে, Collaborator দিয়ে blind SSRF/XXE ধরতে পারবে।

**প্র্যাকটিক্যাল ভাগাভাগি:**
- **Recon/স্ক্যান** → combo command (`/recon`, `/hunt`)
- **ম্যানুয়াল verify / payload tweak / replay** → Burp Repeater বা Caido
- **Blind/OOB** (SSRF, XXE, blind SQLi) → Burp Collaborator

---

## ৫. Validation — N/A এড়ানোই প্রফেশনাল হওয়া

রিপোর্ট লেখার **আগে** প্রতিটা finding এই গেট পার করাও:

**7-Question Gate** (`/validate`):
1. এখনই real PoC request দিয়ে exploit করা যায়?
2. সাধারণ user (অস্বাভাবিক কিছু না করেই) আক্রান্ত হয়?
3. concrete impact — টাকা/PII/ATO/RCE?
4. scope-এ আছে?
5. duplicate/known নয়?
6. always-rejected লিস্টে নেই?
7. একজন triager "হ্যাঁ, real bug" বলবে?

**Bugcrowd-এ পাঠানোর আগে:** `triage-bugcrowd` skill দিয়ে critique করাও — দুর্বল হলে আগেই মেরে দেবে।

**কখনো জমা দেবে না (always-rejected):** শুধু missing security header, SPF/DKIM, GraphQL introspection একা, version disclosure (working CVE ছাড়া), self-XSS, open redirect একা, logout CSRF, CORS (credential exfil PoC ছাড়া)।

---

## ৬. Standalone CLI (subscription ছাড়া, যেকোনো terminal)

```bash
bughunter setup                  # provider বাছো (Ollama/Groq/DeepSeek)
bughunter providers              # কোনটা ready
bughunter recon target.com
bughunter hunt  target.com
bughunter validate "<finding>"
bughunter report
bughunter chat                   # interactive hunting shell
```
Free provider:
- **Ollama** (লোকাল, ফ্রি): `curl -fsSL https://ollama.ai/install.sh | sh && ollama pull qwen2.5:14b`
- **Groq** (ফ্রি cloud): console.groq.com → `export GROQ_API_KEY="..."`

---

## ৭. একটা পূর্ণ session দেখতে কেমন (টেমপ্লেট)

```
1. /scope-aggregate acme           → in-scope asset
2. /recon acme.com                 → 47 sub, 12 live, GraphQL পেলাম
3. /surface acme.com               → api.acme.com আগে (introspection ON)
4. /intel acme.com                 → সাম্প্রতিক IDOR report
5. "api.acme.com/graphql এ IDOR + introspection টেস্ট করো"
6. Burp Repeater-এ verify          → অন্য user-এর data এলো
7. /validate                       → 7-Q Gate PASS
8. /chain                          → IDOR(read)+IDOR(write) → ATO
9. /report                         → submission-ready
```

---

## ৮. Do / Don't (দ্রুত রেফারেন্স)

✅ **করব:** scope আগে পড়ব · এক bug class এক সময়ে · প্রতিটা request Burp-এ দেখব · impact আগে · validate তারপর report · নোট নেব (`/remember`)

❌ **করব না:** scope-এর বাইরে যাব না · theoretical "could" bug রিপোর্ট করব না · severity বাড়িয়ে বলব না · একটা লিডে আটকে থাকব না (5-min rule) · PoC ছাড়া finding দাবি করব না

---

## ৯. আটকে গেলে — দ্রুত কমান্ড

| অবস্থা | কী করব |
|---|---|
| কোথায় আছি বুঝছি না | `bb-methodology` skill ডাকো / `/pickup target.com` |
| কী টেস্ট করব জানি না | `/surface target.com` বা `hypothesis-gen` skill |
| Claude API error (405 ইত্যাদি) | retry / `/model` দিয়ে Sonnet / অথবা `bughunter` CLI |
| finding দুর্বল মনে হচ্ছে | `/validate` + `triage-bugcrowd` |
| external tool নেই | `./install.sh --with-tools` |

---

*মনে রেখো: টুল ২০%, তুমি ৮০%। ধৈর্য রাখো — প্রথম valid bug-এ সময় লাগে, এটাই স্বাভাবিক।*
