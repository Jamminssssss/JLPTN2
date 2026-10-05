#!/usr/bin/env python3
"""Generate compact N2 writing-practice stroke data from KanjiVG."""

from __future__ import annotations

import argparse
import csv
import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
VOCAB_PATH = ROOT / "N2TestApp/Resources/N2_vocab.csv"
OUTPUT_PATH = ROOT / "N2TestApp/Resources/StrokeOrder/strokes.json"
SVG_NAMESPACE = {"svg": "http://www.w3.org/2000/svg"}
NUMBER_PATTERN = re.compile(r"matrix\([^)]*?\s(-?[\d.]+)\s+(-?[\d.]+)\)")


def required_characters() -> set[str]:
    characters: set[str] = set()
    with VOCAB_PATH.open(encoding="utf-8-sig", newline="") as vocab_file:
        for index, row in enumerate(csv.reader(vocab_file)):
            if index == 0 or not row:
                continue
            characters.update(row[0])

    # Keep modern kana available when the vocabulary list is expanded later.
    characters.update(chr(codepoint) for codepoint in range(0x3041, 0x3097))
    characters.update(chr(codepoint) for codepoint in range(0x30A1, 0x30FB))
    characters.add("ー")
    return characters


def extract_glyph(svg_path: Path) -> dict[str, list] | None:
    root = ET.parse(svg_path).getroot()
    paths_group = next(
        (
            group
            for group in root.findall("svg:g", SVG_NAMESPACE)
            if group.get("id", "").startswith("kvg:StrokePaths_")
        ),
        None,
    )
    if paths_group is None:
        return None

    paths = [
        path.get("d")
        for path in paths_group.iterfind(".//svg:path", SVG_NAMESPACE)
        if path.get("d")
    ]
    number_group = next(
        (
            group
            for group in root.findall("svg:g", SVG_NAMESPACE)
            if group.get("id", "").startswith("kvg:StrokeNumbers_")
        ),
        None,
    )
    numbers: list[list[float]] = []
    if number_group is not None:
        for label in number_group.findall("svg:text", SVG_NAMESPACE):
            match = NUMBER_PATTERN.fullmatch(label.get("transform", ""))
            if match:
                numbers.append([float(match.group(1)), float(match.group(2))])

    return {"paths": paths, "numbers": numbers}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "kanjivg",
        type=Path,
        help="KanjiVG checkout path (the directory containing kanji/)",
    )
    args = parser.parse_args()
    source_directory = args.kanjivg / "kanji"

    glyphs: dict[str, dict[str, list]] = {}
    missing: list[str] = []
    for character in sorted(required_characters()):
        svg_path = source_directory / f"{ord(character):05x}.svg"
        if not svg_path.exists():
            missing.append(character)
            continue
        glyph = extract_glyph(svg_path)
        if glyph is not None:
            glyphs[character] = glyph

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(
        json.dumps(glyphs, ensure_ascii=False, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )
    print(f"Wrote {len(glyphs)} glyphs to {OUTPUT_PATH}")
    if missing:
        print("No KanjiVG file: " + "".join(missing))


if __name__ == "__main__":
    main()
