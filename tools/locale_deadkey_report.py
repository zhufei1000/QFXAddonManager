#!/usr/bin/env python3
"""Dead-key analysis for the QFXAddonManager_Locale dictionaries.

A key is alive when it appears as an exact quoted string literal in any
shipped Lua source, or when it is constructed dynamically by a known wrapper
(WHISPER_HISTORY_* prefix in ChatBar whisper-history files, "Strata: X" in
PlayerDeathAlert). Report only; pass --apply to rewrite the dictionaries.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Only scan maintained manager source in this addon workspace.
SHIPPED_DIRS = [p.name for p in ROOT.glob("QFXAddonManager*") if p.is_dir()]

STRATA = ["BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG",
          "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP"]

ENTRY = re.compile(r'^\s*\[(?:"((?:[^"\\]|\\.)*)"|\'((?:[^\'\\]|\\.)*)\')\]\s*=\s*"((?:[^"\\]|\\.)*)"\s*,\s*$')
L_CALL = re.compile(r'\bL\(\s*(?:"((?:[^"\\]|\\.)*)"|\'((?:[^\'\\]|\\.)*)\')\s*\)')


def unescape(s: str) -> str:
    return s.replace('\\"', '"').replace("\\\\", "\\").replace("\\n", "\n")


def tokenize_lua(text: str):
    """Yield ('string', content) tokens for every Lua string literal, skipping
    comments so unpaired quotes in prose cannot flip quote parity."""
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c == "-" and text[i:i + 2] == "--":
            # line or block comment
            j = i + 2
            if text[j:j + 1] == "[":
                k = j + 1
                while k < n and text[k] == "=":
                    k += 1
                if text[k:k + 1] == "[":
                    close = "]" + "=" * (k - j - 1) + "]"
                    end = text.find(close, k + 1)
                    i = n if end == -1 else end + len(close)
                    continue
            end = text.find("\n", i)
            i = n if end == -1 else end
            continue
        if c == '"' or c == "'":
            quote = c
            j = i + 1
            buf = []
            while j < n:
                ch = text[j]
                if ch == "\\" and j + 1 < n:
                    buf.append(text[j:j + 2])
                    j += 2
                    continue
                if ch == quote:
                    break
                buf.append(ch)
                j += 1
            yield "string", "".join(buf)
            i = j + 1
            continue
        if c == "[":
            k = i + 1
            while k < n and text[k] == "=":
                k += 1
            if text[k:k + 1] == "[":
                close = "]" + "=" * (k - i - 1) + "]"
                end = text.find(close, k + 1)
                if end != -1:
                    yield "string", text[k + 1:end]
                    i = end + len(close)
                    continue
        i += 1


def collect_literals():
    used = set()
    whisper_args = set()
    for d in SHIPPED_DIRS:
        base = ROOT / d
        if not base.exists():
            continue
        for f in base.rglob("*.lua"):
            text = f.read_text(encoding="utf-8", errors="replace")
            is_whisper = d == "QFXAddonManager_Toolbox_ChatBar" and f.name in ("Core.lua", "UI.lua", "Module.lua")
            for _, content in tokenize_lua(text):
                used.add(unescape(content))
            if is_whisper:
                for m in L_CALL.finditer(text):
                    whisper_args.add(unescape(m.group(1) if m.group(1) is not None else m.group(2)))
    used.update("WHISPER_HISTORY_" + a for a in whisper_args)
    used.update("Strata: " + s for s in STRATA)
    return used


def parse_dict(path: Path):
    entries = []
    for line in path.read_text(encoding="utf-8").splitlines():
        m = ENTRY.match(line)
        if m:
            key = unescape(m.group(1) if m.group(1) is not None else m.group(2))
            entries.append((key, unescape(m.group(3))))
    return entries


def main():
    apply = "--apply" in sys.argv
    used = collect_literals()
    for locale in ("zhCN", "zhTW", "enUS"):
        path = ROOT / "QFXAddonManager" / "Toolbox" / "Locale" / f"{locale}.lua"
        entries = parse_dict(path)
        if not entries:
            print(f"{locale}: PARSE FAILED")
            continue
        kept, dropped = [], []
        for key, value in entries:
            alive = key in used
            if locale == "enUS" and value == key:
                alive = False  # identity entries are covered by key fallback
            (kept if alive else dropped).append((key, value))
        print(f"{locale}: {len(entries)} entries, keep {len(kept)}, drop {len(dropped)} "
              f"({100.0 * len(dropped) / len(entries):.1f}%)")
        families = {}
        for key, _ in dropped:
            prefix = key.split(" ")[0][:28]
            families[prefix] = families.get(prefix, 0) + 1
        top = sorted(families.items(), key=lambda kv: -kv[1])[:12]
        print("  dropped families:", ", ".join(f"{k}×{v}" for k, v in top))
        if apply:
            kept_keys = {k for k, _ in kept}
            out = []
            for line in path.read_text(encoding="utf-8").splitlines():
                m = ENTRY.match(line)
                if m:
                    key = unescape(m.group(1) if m.group(1) is not None else m.group(2))
                    if key not in kept_keys:
                        continue
                out.append(line)
            path.write_text("\n".join(out) + "\n", encoding="utf-8", newline="\n")
            print(f"  rewrote {path.name}")


if __name__ == "__main__":
    main()
