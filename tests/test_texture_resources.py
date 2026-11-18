"""Read-only texture structure/decode audit; no client or player data writes."""
import hashlib
import io
import json
import re
import struct
from collections import Counter
from pathlib import Path

from PIL import Image, ImageFont

ROOT = Path(__file__).resolve().parents[1]
CLIENTS = [Path("D:/World of Warcraft") / name for name in ("_forever_", "_retail_")]
EXTENSIONS = {".blp", ".png", ".tga", ".jpg", ".jpeg", ".dds"}


def verify_image(path):
    blob = path.read_bytes()
    if blob[:4] != b"BLP2":
        with Image.open(io.BytesIO(blob)) as image:
            image.load()
        return
    assert len(blob) >= 148, "truncated BLP2 header"
    _, kind, encoding, depth, alpha, mips, width, height = struct.unpack_from("<4sIBBBBII", blob)
    assert kind == 1 and width > 0 and height > 0, "invalid BLP2 dimensions/type"
    assert width & (width - 1) == height & (height - 1) == 0, "non-power-of-two BLP2"
    assert encoding in (1, 2, 3), "unknown BLP2 encoding"
    offsets = struct.unpack_from("<16I", blob, 20)
    lengths = struct.unpack_from("<16I", blob, 84)
    previous_end, count = 148, 0
    for level, (offset, length) in enumerate(zip(offsets, lengths)):
        if not length:
            assert not any(lengths[level:]), "sparse mip chain"
            assert all(p == 0 or p == len(blob) for p in offsets[level:]), "invalid unused mip offset"
            break
        w, h = max(1, width >> level), max(1, height >> level)
        assert offset >= previous_end and length > 0 and offset + length <= len(blob), "mip outside file/overlap"
        if encoding == 2:
            assert alpha in (0, 1, 7), "invalid DXT format"
            expected = ((w + 3) // 4) * ((h + 3) // 4) * (8 if alpha == 0 else 16)
        elif encoding == 3:
            expected = w * h * 4
        else:
            expected = w * h + (w * h * depth + 7) // 8
        assert length == expected, f"mip {level}: {length} != {expected}"
        # Decode each mip separately; pad tiny DXT levels to a full block.
        dw, dh = (max(4, w), max(4, h)) if encoding == 2 else (w, h)
        single = bytearray(blob[:offsets[0]])
        struct.pack_into("<II", single, 12, dw, dh)
        single[11] = 0
        struct.pack_into("<16I", single, 20, len(single), *([0] * 15))
        struct.pack_into("<16I", single, 84, length, *([0] * 15))
        if encoding == 3:
            Image.frombytes("RGBA", (w, h), blob[offset:offset + length], "raw", "BGRA").load()
        else:
            with Image.open(io.BytesIO(single + blob[offset:offset + length])) as image:
                image.load()
        previous_end, count = offset + length, count + 1
    assert count > 0, "no mip data"
    if mips:
        assert count >= max(width, height).bit_length(), "incomplete mip chain"


def main():
    images, failures, mismatches, native, missing = [], [], [], [], []
    packages = [p for p in ROOT.glob("QFXAddonManager*") if p.is_dir()] + [ROOT / "QFX_SharedMedia"]
    for package in packages:
        for path in package.rglob("*"):
            if not path.is_file():
                continue
            if path.suffix.lower() in EXTENSIONS:
                images.append(path)
                try:
                    verify_image(path)
                except Exception as error:
                    failures.append({"path": str(path.relative_to(ROOT)), "error": str(error)})
            elif path.suffix.lower() in {".ttf", ".otf"}:
                try:
                    ImageFont.truetype(str(path), 12).getmask("QFX")
                except Exception as error:
                    failures.append({"path": str(path.relative_to(ROOT)), "error": str(error)})
    for client in CLIENTS:
        addons = client / "Interface/AddOns"
        for path in images:
            copy = addons / path.relative_to(ROOT)
            if not copy.exists() or hashlib.sha256(path.read_bytes()).digest() != hashlib.sha256(copy.read_bytes()).digest():
                mismatches.append({"client": client.name, "path": str(path.relative_to(ROOT)), "state": "missing" if not copy.exists() else "different"})
        for toc in addons.glob("*/*.toc"):
            for value in re.findall(r"^##\s*IconTexture:\s*(.+)$", toc.read_text(encoding="utf-8-sig", errors="replace"), re.M):
                value = value.strip().replace("\\", "/")
                row = {"client": client.name, "addon": toc.parent.name, "toc": toc.name, "icon": value}
                if value.lower().startswith("interface/addons/"):
                    target = client / value
                    candidates = [target] if target.suffix else [target.with_suffix(ext) for ext in EXTENSIONS]
                    found = next((p for p in candidates if p.is_file()), None)
                    if not found:
                        missing.append(row)
                    else:
                        try:
                            verify_image(found)
                        except Exception as error:
                            failures.append({**row, "error": str(error)})
                else:
                    native.append(row)
    report = {"images": len(images), "formats": dict(Counter(p.suffix for p in images)),
              "failures": failures, "client_mismatches": mismatches, "native_toc_icons": native,
              "missing_toc_icons": missing,
              "limitations": "Local files only; does not decode CASC resources or exercise the WoW native renderer. TOCs include inactive branch variants."}
    output = ROOT / "tools/texture-safety-audit.json"
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"images": len(images), "failures": len(failures), "client_mismatches": len(mismatches),
                      "native_toc_icons": len(native), "missing_toc_icons": len(missing), "report": str(output)}, ensure_ascii=False))
    for row in failures:
        print("FAIL", row)
    return bool(failures)


if __name__ == "__main__":
    raise SystemExit(main())
