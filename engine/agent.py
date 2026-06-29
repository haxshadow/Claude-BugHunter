#!/usr/bin/env python3
"""
agent.py — the engine's LLM dispatch. Only recon/hunt/validate are model-driven;
the orchestrator, scope, and state are deterministic code.

Two backends (auto-selected):
  1. claude  — headless `claude -p`: skills auto-activate, Burp MCP is the hands.
               Used when the `claude` binary is on PATH (Claude Code harness).
  2. brain   — free-first multi-provider fallback (Ollama / Groq / DeepSeek / Claude
               API / OpenAI) via the combo's brain.py. Used when `claude` is absent.
               NOTE: this backend is REASONING-ONLY — it has no Burp MCP / curl hands,
               so it cannot send live HTTP. It produces the structured ```json``` verdict
               from the evidence/task text. Best for --mock runs, analysis, and free-only
               setups; real live hunting needs the claude backend or the standalone tools.

Selection:
  BBHUNT_ENGINE_PROVIDER=claude|ollama|groq|deepseek|claude-api|openai|...  forces a backend
    - "claude" forces the `claude -p` subprocess backend
    - any other value forces the brain backend with that provider
  (unset) -> use `claude` if on PATH, else fall back to brain (free-first auto-detect)

Agents are asked to end with a fenced ```json``` block which we parse into structured data.
"""
import json
import os
import re
import shutil
import subprocess
import sys
import time

ENGINE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(ENGINE)  # combo root holds brain.py
MCP_CONFIG = os.path.join(ENGINE, "burp-mcp.json")
ALLOWED_TOOLS = " ".join([
    "mcp__burp__send_http1_request", "mcp__burp__send_http2_request",
    "mcp__burp__get_collaborator_interactions", "mcp__burp__generate_collaborator_payload",
    "Bash(curl:*)", "Bash(python3:*)", "Bash(jq:*)", "Bash(openssl:*)", "Bash(base64:*)",
])


def _claude_backend_available():
    return shutil.which("claude") is not None


def _select_backend():
    """Return (backend, provider) where backend is 'claude' or 'brain'."""
    forced = os.environ.get("BBHUNT_ENGINE_PROVIDER", "").strip().lower()
    if forced == "claude":
        return "claude", None
    if forced:
        # any non-"claude" provider name -> brain backend, that provider
        return "brain", ("claude" if forced == "claude-api" else forced)
    if _claude_backend_available():
        return "claude", None
    return "brain", None  # brain auto-detects free-first


def _run_agent_brain(task, provider=None, timeout=600):
    """Reasoning-only fallback using the combo's multi-provider brain.py.

    No Burp MCP / curl — the model reasons over the task text and returns the
    required fenced ```json``` verdict. Free-first provider auto-detect unless a
    provider is forced via BBHUNT_ENGINE_PROVIDER.
    """
    t0 = time.time()
    if REPO_ROOT not in sys.path:
        sys.path.insert(0, REPO_ROOT)
    try:
        from brain import LLMClient, BRAIN_SYSTEM  # noqa: PLC0415
    except Exception as e:
        return {"result": "", "error": f"brain-import:{e}", "duration_s": round(time.time() - t0, 1)}

    client = LLMClient(provider)
    if not client.available:
        return {"result": "", "error": "no-provider",
                "duration_s": round(time.time() - t0, 1)}

    model = os.environ.get("BBHUNT_ENGINE_MODEL") or None
    system = (BRAIN_SYSTEM + "\n\nYou have NO live HTTP tools in this mode. Reason over the "
              "task and any provided evidence, then output ONLY the requested fenced ```json``` "
              "object as your final answer. Be conservative: if impact is not proven by the "
              "evidence, set vulnerable/real to false.")
    try:
        text = client.chat(model, system, task, max_tokens=2000, temperature=0.1)
    except Exception as e:
        return {"result": "", "error": f"brain-chat:{e}", "duration_s": round(time.time() - t0, 1)}
    if not text:
        return {"result": "", "error": "empty", "duration_s": round(time.time() - t0, 1)}
    return {"result": text, "error": None, "backend": f"brain/{client.provider}",
            "duration_s": round(time.time() - t0, 1)}


def _run_agent_claude(task, skills_on=False, model="claude-sonnet-4-6", max_turns=40, timeout=600):
    # skills OFF by default: the eval showed they add ~0 capability but cost ~12-15k tokens/agent.
    cmd = ["claude", "-p", task,
           "--mcp-config", MCP_CONFIG, "--strict-mcp-config",
           "--permission-mode", "bypassPermissions",
           "--allowedTools", ALLOWED_TOOLS,
           "--max-turns", str(max_turns), "--model", model,
           "--output-format", "json"]
    if not skills_on:
        cmd.append("--disable-slash-commands")
    t0 = time.time()
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return {"result": "", "error": "timeout", "duration_s": round(time.time() - t0, 1)}
    try:
        d = json.loads(p.stdout)
        res = d.get("result") or ""
        # usage-limit / API errors come back as a short result with no real work
        if "usage limit" in res.lower() or "session limit" in res.lower():
            return {"result": res, "error": "rate-limited", "duration_s": round(time.time() - t0, 1)}
        return {"result": res, "cost_usd": d.get("total_cost_usd"),
                "num_turns": d.get("num_turns"), "error": None,
                "duration_s": round(time.time() - t0, 1)}
    except Exception as e:
        return {"result": p.stdout[:300], "error": f"parse:{e}", "duration_s": round(time.time() - t0, 1)}


def run_agent(task, skills_on=False, model="claude-sonnet-4-6", max_turns=40, timeout=600):
    """Dispatch to the claude backend (live HTTP via Burp MCP) or the brain
    free-provider fallback (reasoning-only). See module docstring for selection."""
    backend, provider = _select_backend()
    if backend == "claude":
        return _run_agent_claude(task, skills_on=skills_on, model=model,
                                 max_turns=max_turns, timeout=timeout)
    return _run_agent_brain(task, provider=provider, timeout=timeout)


def extract_json(text):
    """Pull the last valid JSON array/object out of an agent reply."""
    if not text:
        return None
    blocks = re.findall(r"```json\s*(.*?)```", text, re.S)
    blocks += re.findall(r"```\s*(\[.*?\]|\{.*?\})\s*```", text, re.S)
    for b in reversed(blocks):
        try:
            return json.loads(b.strip())
        except Exception:
            pass
    for b in reversed(re.findall(r"(\[.*\]|\{.*\})", text, re.S)):
        try:
            return json.loads(b)
        except Exception:
            pass
    return None


if __name__ == "__main__":
    # offline self-test of the JSON extractor (no agent call)
    assert extract_json('blah ```json\n[{"a":1}]\n``` end') == [{"a": 1}]
    assert extract_json('text {"x": "y"} more') == {"x": "y"}
    assert extract_json("no json here") is None
    assert extract_json('first {"a":1} then ```json\n{"b":2}\n```') == {"b": 2}  # prefers fenced/last
    # backend selection (no model call)
    os.environ["BBHUNT_ENGINE_PROVIDER"] = "claude"
    assert _select_backend() == ("claude", None)
    os.environ["BBHUNT_ENGINE_PROVIDER"] = "ollama"
    assert _select_backend() == ("brain", "ollama")
    os.environ["BBHUNT_ENGINE_PROVIDER"] = "claude-api"
    assert _select_backend() == ("brain", "claude")
    os.environ.pop("BBHUNT_ENGINE_PROVIDER")
    b, _ = _select_backend()
    assert b in ("claude", "brain")
    print("agent.py extractor + backend self-test: PASS")
