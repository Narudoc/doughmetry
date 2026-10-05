#!/usr/bin/env python3
"""L("…")/LF("…")의 한국어 키마다 Localization.swift의 영어 사전(en)에 항목이 있는지 본다.

CI(.github/workflows/ios.yml)와 같은 검사 — 푸시 전에 `python3 ios/scripts/check_l10n.py`로 돌린다.
출력의 ::error/::notice 줄은 GitHub Actions 주석 형식이라 경로는 저장소 루트 기준이다.
"""
import pathlib
import re
import sys

root = pathlib.Path(__file__).resolve().parents[2]
src = root / "ios" / "LevainCalc"
loc_path = src / "Localization.swift"
loc = loc_path.read_text()
lit = r'"((?:[^"\\\n]|\\.)*)"'


def rel(path):
    return path.relative_to(root)


def table(name):
    m = re.search(r"private let %s: \[String: String\] = \[(.*?)\n\]" % name, loc, re.S)
    if not m:
        sys.exit(f"::error::{rel(loc_path)}: table '{name}' not found")
    return set(re.findall(r"^\s*" + lit + r"\s*:", m.group(1), re.M))


en, en_one = table("en"), table("enOne")
used, skipped = {}, 0
call = re.compile(r"(?<![\w.])(?<!func )(LF?)\(\s*")
for path in sorted(src.rglob("*.swift")):
    text = path.read_text()
    for m in call.finditer(text):
        start = text.rfind("\n", 0, m.start()) + 1
        if "//" in text[start:m.start()]:
            continue
        line = text.count("\n", 0, m.start()) + 1
        key = re.match(lit, text[m.end():])
        if key:
            used.setdefault(key.group(1), (path, line))
        else:
            skipped += 1
            print(f"::notice file={rel(path)},line={line}::{m.group(1)}() argument is not a literal - not checked")

missing = sorted(k for k in used if k not in en)
for k in missing:
    path, line = used[k]
    print(f"::error file={rel(path)},line={line}::no English entry in Localization.swift for \"{k}\"")
orphans = sorted(en_one - en)
for k in orphans:
    print(f"::error file={rel(loc_path)}::enOne key \"{k}\" is missing from en (LF(_:count:) falls back to en)")
print(f"{len(used)} keys, {len(missing)} missing, {skipped} non-literal calls skipped")
sys.exit(1 if missing or orphans else 0)
