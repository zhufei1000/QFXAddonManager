"""Check maintained manager dictionaries, literal callers and format arguments."""
from collections import Counter
import json
from pathlib import Path
import re

from locale_deadkey_report import parse_dict, unescape

ROOT = Path(__file__).resolve().parents[1]
LANGUAGES = ("enUS", "zhCN", "zhTW")
STRING = r'''("(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*')'''
CALL = re.compile(r"(?<![\w.])(?:(ns|ui|M|F)\.)?L\(\s*" + STRING + r"\s*\)")
FIELD = re.compile(r"\b(?:titleKey|descKey)\s*=\s*" + STRING)
FORMAT = re.compile(r"%(?:\d+\$)?[-+ #0]*\d*(?:\.\d+)?([cdiouxXeEfgGqs])")


def literal(value):
    return unescape(value[1:-1]).replace("\\'", "'")


def signature(value):
    return FORMAT.findall(value.replace("%%", ""))


def main():
    issues, dictionaries, manager = [], {}, {}
    for language in LANGUAGES:
        entries = parse_dict(ROOT / f"QFXAddonManager/Toolbox/Locale/{language}.lua")
        duplicates = [key for key, count in Counter(key for key, _ in entries).items() if count > 1]
        issues.extend(f"{language}: duplicate builtin key {key}" for key in duplicates)
        dictionaries[language] = dict(entries)
        text = (ROOT / f"QFXAddonManager/Locale/{language}.lua").read_text(encoding="utf-8-sig")
        entries = [(m[1], literal(m[2])) for m in re.finditer(r"\bL\.(\w+)\s*=\s*" + STRING, text)]
        aliases = re.findall(r"\bL\.(\w+)\s*=\s*L\.(\w+)", text)
        duplicates = [key for key, count in Counter(key for key, _ in entries + aliases).items() if count > 1]
        issues.extend(f"{language}: duplicate manager key {key}" for key in duplicates)
        manager[language] = dict(entries)
        for key, source in aliases:
            manager[language][key] = manager[language][source]

    references = {}
    for folder in ROOT.glob("QFXAddonManager*"):
        if not folder.is_dir():
            continue
        for path in folder.rglob("*.lua"):
            if "Libs" in path.parts or path.parent == ROOT / "QFXAddonManager/Toolbox/Locale":
                continue
            text = path.read_text(encoding="utf-8-sig")
            whisper = folder.name == "QFXAddonManager_Toolbox_ChatBar" and path.name in {"Core.lua", "UI.lua", "Module.lua"}
            for match in CALL.finditer(text):
                key = literal(match[2])
                if whisper and match[1] in (None, "M"):
                    key = "WHISPER_HISTORY_" + key
                references.setdefault(key, []).append(path.relative_to(ROOT).as_posix())
            for match in FIELD.finditer(text):
                references.setdefault(literal(match[1]), []).append(path.relative_to(ROOT).as_posix())

    # Dynamic callers: frame strata and whisper prefixes are source-owned keys.
    for strata in ("BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP"):
        references.setdefault("Strata: " + strata, ["PlayerDeathAlert: dynamic strata label"])

    for language in ("zhCN", "zhTW"):
        missing = sorted(references.keys() - dictionaries[language].keys())
        issues.extend(f"{language}: untranslated builtin key {key}" for key in missing)
        for key in manager["enUS"]:
            if key not in manager[language]:
                issues.append(f"{language}: missing manager key {key}")
            elif signature(manager["enUS"][key]) != signature(manager[language][key]):
                issues.append(f"{language}: manager format mismatch {key}")
        for key, value in dictionaries[language].items():
            english = dictionaries["enUS"].get(key, key)
            if signature(english) != signature(value):
                issues.append(f"{language}: builtin format mismatch {key}")
    for key in dictionaries["zhCN"].keys() ^ dictionaries["zhTW"].keys():
        issues.append(f"Chinese dictionaries differ: {key}")
    for key in references:
        if re.fullmatch(r"[A-Z][A-Z0-9_]+", key) and key not in dictionaries["enUS"]:
            issues.append(f"enUS: missing symbolic builtin key {key}")

    report = {
        "manager_keys": {lang: len(values) for lang, values in manager.items()},
        "builtin_entries": {lang: len(values) for lang, values in dictionaries.items()},
        "literal_and_dynamic_builtin_keys": len(references),
        "english_fallback": "English sentence keys intentionally fall back to themselves; symbolic keys require an enUS entry.",
        "scope": "Maintained manager text only; external plugins own their native dictionaries and player-authored text is retained.",
        "issues": issues,
        "references": references,
    }
    (ROOT / "tools/language-audit.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: value for key, value in report.items() if key != "references"}, ensure_ascii=True))
    if issues:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
