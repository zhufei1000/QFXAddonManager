"""Validate, package and publish the maintained addon; never change versions."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import urllib.error
import urllib.request
import uuid

import build_addon

ROOT = Path(__file__).resolve().parents[1]
PROJECT_ID = 1773703
CF_BASE = "https://wow.curseforge.com/api"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def header(text, key):
    match = re.search(r"^##\s*" + re.escape(key) + r":\s*([^\r\n]+)", text, re.M)
    if not match:
        raise ValueError("Missing TOC header: " + key)
    return match[1].strip()


def release_info(tag=""):
    packages, media = build_addon.folders()
    main = (packages["QFXAddonManager"] / "QFXAddonManager.toc").read_text(encoding="utf-8-sig")
    version = header(main, "Version")
    if not re.fullmatch(r"(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)", version):
        raise ValueError("Version must use X.Y.Z")
    if tag and tag != "v" + version:
        raise ValueError(f"Tag {tag} does not match TOC version v{version}")
    if header(main, "X-Curse-Project-ID") != str(PROJECT_ID):
        raise ValueError("CurseForge project ID must be 1773703")
    for name, folder in packages.items():
        if name not in media:
            text = (folder / (name + ".toc")).read_text(encoding="utf-8-sig")
            if header(text, "Version") != version:
                raise ValueError("Version mismatch: " + name)
    readme = (packages["QFXAddonManager"] / "README.txt").read_text(encoding="utf-8-sig")
    if readme.splitlines()[0] != "QFXAddonManager v" + version:
        raise ValueError("Bundled README version does not match TOC")
    notes = ROOT / "docs" / ("RELEASE_" + version + ".md")
    if not notes.is_file() or not notes.read_text(encoding="utf-8").strip():
        raise ValueError("Missing release notes: " + str(notes.relative_to(ROOT)))
    versions = []
    for value in header(main, "Interface").split(","):
        interface = int(value.strip())
        versions.append(f"{interface // 10000}.{interface // 100 % 100}.{interface % 100}")
    return {"version": version, "tag": "v" + version, "project_id": PROJECT_ID,
            "game_version_names": list(dict.fromkeys(versions)),
            "asset": "QFXAddonManager_" + version + ".zip",
            "notes": notes.relative_to(ROOT).as_posix()}


def check():
    release_info()
    packages, media = build_addon.folders()
    build_addon.validate(packages, media)
    compiler = shutil.which("luac5.4") or shutil.which("luac")
    lua = shutil.which("lua5.4") or shutil.which("lua")
    if not compiler or not lua:
        raise ValueError("Lua 5.4 and luac are required")
    syntax_count = 0
    for name, folder in sorted(packages.items()):
        for path in sorted(folder.rglob("*.lua")):
            subprocess.run([compiler, "-p", str(path)], check=True, cwd=ROOT)
            syntax_count += 1
    subprocess.run([sys.executable, "tools/audit_localization.py"], check=True, cwd=ROOT)
    for locale in ("enUS", "zhCN", "zhTW"):
        for test in ("validate_addon_title_language", "validate_class_card_picker"):
            subprocess.run([lua, "tools/" + test + ".lua", locale], check=True, cwd=ROOT)
    print(f"Verified {syntax_count} Lua files and UI behavior in three languages")


def prepare(output, tag=""):
    info = release_info(tag)
    output = output.resolve()
    package = output / info["asset"]
    subprocess.run([sys.executable, str(ROOT / "tools/build_addon.py"), "--output", str(package)],
                   check=True, cwd=ROOT)
    info["sha256"] = digest(package)
    package.with_suffix(".zip.sha256").write_text(info["sha256"] + "  " + package.name + "\n", encoding="ascii")
    (output / "release-manifest.json").write_text(json.dumps(info, indent=2) + "\n", encoding="utf-8")
    print(f"Prepared {info['asset']} for CurseForge project {PROJECT_ID}")
    return info


def upload_metadata(info, notes):
    return {"changelog": notes, "changelogType": "markdown", "displayName": "QFXAddonManager " + info["version"],
            "gameVersionNames": info["game_version_names"], "releaseType": "release"}


def upload_curseforge(package, info, notes, token):
    if not token.strip():
        raise ValueError("Add repository Actions secret CF_API_KEY before publishing")
    boundary = "qfx-" + uuid.uuid4().hex
    metadata = json.dumps(upload_metadata(info, notes), ensure_ascii=False).encode("utf-8")
    body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"metadata\"\r\n"
            "Content-Type: application/json\r\n\r\n").encode() + metadata
    body += (f"\r\n--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"{package.name}\"\r\n"
             "Content-Type: application/zip\r\n\r\n").encode() + package.read_bytes()
    body += f"\r\n--{boundary}--\r\n".encode()
    request = urllib.request.Request(f"{CF_BASE}/projects/{PROJECT_ID}/upload-file", data=body, method="POST",
                                     headers={"X-Api-Token": token.strip(),
                                              "Content-Type": "multipart/form-data; boundary=" + boundary})
    # An interrupted POST can already have succeeded; never blindly retry uploads.
    try:
        with urllib.request.urlopen(request, timeout=180) as response:
            result = json.load(response)
    except urllib.error.HTTPError as error:
        raise ValueError(f"CurseForge upload failed (HTTP {error.code}); inspect the project before retrying") from None
    file_id = result.get("id") if isinstance(result, dict) else None
    if not isinstance(file_id, int) or isinstance(file_id, bool) or file_id <= 0:
        raise ValueError("CurseForge did not return a valid file ID; inspect the project before retrying")
    return {"project_id": PROJECT_ID, "version": info["version"], "sha256": info["sha256"], "file_id": file_id}


def gh(*args, capture=False, check=True):
    return subprocess.run(["gh", *args], cwd=ROOT, check=check, capture_output=capture,
                          encoding="utf-8", errors="replace")


def publish(output, tag):
    info = release_info(tag)
    if not tag:
        raise ValueError("Publishing requires an explicit vX.Y.Z tag")
    if os.getenv("GITHUB_REF") and os.environ["GITHUB_REF"] != "refs/tags/" + tag:
        raise ValueError("Only a pushed version tag can publish")
    output = output.resolve()
    saved = json.loads((output / "release-manifest.json").read_text(encoding="utf-8"))
    package = output / info["asset"]
    if any(saved.get(key) != value for key, value in info.items()) or digest(package) != saved.get("sha256"):
        raise ValueError("Release artifact metadata/checksum does not match the checked-out tag")
    info = saved
    packages, media = build_addon.folders()
    build_addon.validate_archive(package, packages, media)
    checksum = output / (info["asset"] + ".sha256")
    if checksum.read_text(encoding="ascii") != info["sha256"] + "  " + info["asset"] + "\n":
        raise ValueError("Checksum attachment mismatch")
    token = os.getenv("CF_API_KEY", "")
    if not token.strip():
        raise ValueError("Add repository Actions secret CF_API_KEY before publishing")
    existing = gh("release", "view", tag, "--json", "assets,isDraft", capture=True, check=False)
    receipt_name = "curseforge-upload.json"
    if existing.returncode == 0:
        existing_release = json.loads(existing.stdout)
        assets = existing_release["assets"]
        if receipt_name in {asset["name"] for asset in assets}:
            previous = gh("release", "download", tag, "--pattern", receipt_name, "--output", "-", capture=True)
            receipt = json.loads(previous.stdout)
            if any(receipt.get(key) != info[key] for key in ("project_id", "version", "sha256")):
                raise ValueError("Existing release receipt differs; refusing to overwrite")
            if existing_release["isDraft"]:
                gh("release", "edit", tag, "--draft=false", "--latest")
            print(f"Already published: {tag}, CurseForge file {receipt['file_id']}")
            return
        raise ValueError("A GitHub release already exists without an upload receipt; inspect CurseForge before retrying")
    notes = (ROOT / info["notes"]).read_text(encoding="utf-8")
    # Stage the GitHub release; a rejected CF upload leaves a reviewable draft.
    gh("release", "create", tag, str(package), str(checksum), "--verify-tag", "--draft",
       "--title", "QFXAddonManager " + info["version"], "--notes-file", str(ROOT / info["notes"]))
    receipt = upload_curseforge(package, info, notes, token)
    receipt_path = output / receipt_name
    receipt_path.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    gh("release", "upload", tag, str(receipt_path))
    gh("release", "edit", tag, "--draft=false", "--latest")
    print(f"Published {tag}; CurseForge file {receipt['file_id']}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("check", "prepare", "publish"))
    parser.add_argument("--tag", default="")
    parser.add_argument("--output-dir", type=Path, default=ROOT / "dist")
    args = parser.parse_args()
    try:
        if args.command == "check":
            check()
        elif args.command == "prepare":
            prepare(args.output_dir, args.tag)
        else:
            publish(args.output_dir, args.tag)
    except (ValueError, subprocess.CalledProcessError) as error:
        parser.exit(1, str(error) + "\n")


if __name__ == "__main__":
    main()
