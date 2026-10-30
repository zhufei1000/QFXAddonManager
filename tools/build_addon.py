"""Validate or package the manager family and shared assets."""
import argparse
import hashlib
import json
import re
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANAGER_PACKAGES = {"QFXAddonManager", "QFXAddonManager_Config", "QFXAddonManager_Toolbox_Daily",
                    "QFXAddonManager_Toolbox_Combat", "QFXAddonManager_Toolbox_ChatBar",
                    "QFXAddonManager_Libraries_GlowFallback"}


def excluded(path):
    parts = {part.lower() for part in path.parts}
    name = path.name.lower()
    return bool(parts & {".git", ".github", ".workbuddy", "__pycache__", "archive", "node_modules", "tests", "tools", "docs"}) or (
        path.suffix.lower() in {".bak", ".log", ".pyc"}
        or name in {"agents.md", ".pkgmeta", ".ds_store", "addon_version.txt", "dd_author.toc", "overview.md"}
        or name.startswith("pid-")
        or name.startswith(("changelog", "release_notes", "release-notes", "devlog")))


def folders():
    packages = {path.name: path for path in ROOT.glob("QFXAddonManager*") if path.is_dir()}
    assert set(packages) == MANAGER_PACKAGES, "Manager distribution must contain the main addon and exactly five companions"
    packages["QFX_SharedMedia"] = ROOT / "QFX_SharedMedia"
    assert (packages["QFX_SharedMedia"] / "Media").is_dir(), "Shared media assets missing"
    return packages, {"QFX_SharedMedia"}


def asset_manifest(packages):
    # CurseForge requires a matching TOC in every top-level archive folder.
    # Keep the maintained media tree script-free; generate metadata only.
    main = packages["QFXAddonManager"] / "QFXAddonManager.toc"
    text = main.read_text(encoding="utf-8-sig")
    def header(key):
        match = re.search(r"^##\s*" + re.escape(key) + r":\s*([^\r\n]+)", text, re.M)
        assert match, "Missing main addon metadata: " + key
        return match[1].strip()
    return (f"## Interface: {header('Interface')}\n"
            "## Title: QFX Addon Manager - Shared Assets\n"
            "## Title-zhCN: QFX 插件管理中心 - 共享素材\n"
            "## Title-zhTW: QFX 插件管理中心 - 共享素材\n"
            "## Notes: Shared assets for QFXAddonManager. No scripts are loaded.\n"
            f"## Author: {header('Author')}\n"
            f"## Version: {header('Version')}\n"
            "## Dependencies: QFXAddonManager\n"
            "## LoadOnDemand: 1\n"
            "## X-QFX-Asset-Only: 1\n").encode("utf-8")


def validate_archive(output, packages, media):
    with zipfile.ZipFile(output) as archive:
        assert archive.testzip() is None, "Archive CRC check failed"
        entries = set(archive.namelist())
        roots = {name.split("/", 1)[0] for name in entries}
        assert roots == set(packages), "Archive omitted an addon folder"
        expected = {f"{name}/{path.relative_to(folder).as_posix()}"
                    for name, folder in packages.items() for path in folder.rglob("*")
                    if path.is_file() and not excluded(path.relative_to(folder))}
        expected.update(f"{name}/{name}.toc" for name in media)
        assert entries == expected, "Archive omitted or added unexpected files"
        for name, folder in packages.items():
            manifest = f"{name}/{name}.toc"
            assert manifest in entries, "Missing matching top-level TOC: " + name
            if name in media:
                assert archive.read(manifest) == asset_manifest(packages), "Invalid asset declaration"
            for path in folder.rglob("*"):
                if path.is_file() and not excluded(path.relative_to(folder)):
                    entry = f"{name}/{path.relative_to(folder).as_posix()}"
                    assert archive.read(entry) == path.read_bytes(), "Archive/source mismatch: " + entry


def validate(packages, media):
    assert "qfxtoolbox" not in {name.lower() for name in packages}, "QFXToolBox migration bridge is no longer distributed"
    issues = []
    for name, folder in packages.items():
        toc = folder / (name + ".toc")
        if name in media:
            # A retired addon turned plain asset folder: no TOC may reintroduce
            # a separate addon entry or a second LibSharedMedia registration.
            scripts = [p for p in folder.rglob("*") if p.is_file() and p.suffix.lower() in {".toc", ".lua", ".xml"}]
            if scripts:
                issues.append(f"Media folder must stay script/TOC-free: {scripts}")
        else:
            if not toc.exists():
                issues.append(f"Missing TOC: {toc}")
                continue
            for line in toc.read_text(encoding="utf-8-sig").splitlines():
                line = line.strip()
                if not line or line.startswith("#"):
                    if re.match(r"##\s*(Dependencies|RequiredDeps):", line, re.I):
                        for dependency in line.split(":", 1)[1].split(","):
                            dependency = dependency.strip()
                            if dependency and dependency not in packages:
                                issues.append(f"{name} requires unbundled addon {dependency}")
                    continue
                # The client may append per-file load annotations after the path.
                relative = re.sub(r"\s+\[[^]]+\]\s*$", "", line).replace("\\", "/")
                if not (folder / relative).is_file():
                    issues.append(f"Missing TOC entry: {name}/{relative}")
        for path in folder.rglob("*.xml"):
            text = path.read_text(encoding="utf-8-sig", errors="replace")
            text = re.sub(r"<!--.*?-->", "", text, flags=re.S)
            for relative in re.findall(r'<(?:Script|Include)\b[^>]*\bfile=["\']([^"\']+)', text):
                if not (path.parent / relative.replace("\\", "/")).is_file():
                    issues.append(f"Missing XML include: {name}/{path.relative_to(folder)} -> {relative}")
    if issues:
        raise RuntimeError("\n".join(issues))
    asset_manifest(packages)
    return len(media) + sum(1 for folder in packages.values() for path in folder.rglob("*")
                           if path.is_file() and not excluded(path.relative_to(folder)))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="Create this zip; without --output only validate")
    args = parser.parse_args()
    packages, media = folders()
    count = validate(packages, media)
    if args.output:
        output = args.output.resolve()
        assert output.suffix.lower() == ".zip", "Output must be a zip"
        assert not any(output.is_relative_to(folder.resolve()) for folder in packages.values()), "Keep zip output outside addon source folders"
        assert not output.exists(), "Choose a new output name rather than overwriting an existing package"
        output.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(output, "x", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
            for name, folder in sorted(packages.items()):
                for path in sorted(folder.rglob("*")):
                    relative = path.relative_to(folder)
                    if path.is_file() and not excluded(relative):
                        archive.write(path, (Path(name) / relative).as_posix())
                if name in media:
                    archive.writestr(f"{name}/{name}.toc", asset_manifest(packages))
        validate_archive(output, packages, media)
        print("Created:", output)
    print(f"Validated {len(packages)} addon folders / {count} packaged files; matching root TOCs, TOC/XML references, dependency policy and payload verified")


if __name__ == "__main__":
    main()
