"""Run the production Swift CSV parsers/loaders against bundled quiz content.

Usage: python3 Scripts/check_quiz_content.py
Requires a macOS Xcode installation; set DEVELOPER_DIR to select one.
"""
import csv
import os
from pathlib import Path
import platform
import plistlib
import shutil
import subprocess
import tempfile


def main():
    root = Path(__file__).resolve().parents[1]
    env = dict(os.environ)
    desktop_xcode = Path.home() / "Desktop/Xcode.app/Contents/Developer"
    if "DEVELOPER_DIR" not in env and desktop_xcode.exists():
        env["DEVELOPER_DIR"] = str(desktop_xcode)
    swiftc = subprocess.check_output(["xcrun", "--find", "swiftc"], env=env, text=True).strip()
    sdk = subprocess.check_output(["xcrun", "--sdk", "macosx", "--show-sdk-path"], env=env, text=True).strip()
    sources = [
        "N2TestApp/Models/Question.swift",
        "N2TestApp/Models/AudioQuestion.swift",
        "N2TestApp/Models/AudioQuestionGroup.swift",
        "N2TestApp/Utils/QuizCSVParser.swift",
        "N2TestApp/Utils/DataLoader.swift",
        "N2TestApp/Utils/AudioDataLoader.swift",
        "Scripts/check_quiz_content.swift",
    ]
    with tempfile.TemporaryDirectory(prefix="n2-quiz-check-") as directory:
        temporary = Path(directory)
        contents = temporary / "QuizChecks.app/Contents"
        resources = contents / "Resources"
        resources.mkdir(parents=True)
        (contents / "MacOS").mkdir()
        (contents / "Info.plist").write_bytes(plistlib.dumps({
            "CFBundleExecutable": "QuizContentChecks",
            "CFBundleIdentifier": "local.n2.contentchecks",
            "CFBundlePackageType": "APPL",
        }))
        for path in (root / "N2TestApp/Resources").glob("jlpt*.csv"):
            with path.open(encoding="utf-8-sig", newline="") as stream:
                records = list(csv.reader(stream, strict=True))
            assert all(len(row) == len(records[0]) for row in records[1:]), path
            shutil.copy2(path, resources / path.name)
        for kind, name in [("reading", "jlptn2_reading_set4.csv"), ("audio", "jlptn2_audio_set3.csv")]:
            with (resources / name).open(encoding="utf-8-sig", newline="") as stream:
                records = list(csv.reader(stream))
            invalid_answer = records[1].copy()
            invalid_answer[5] = ""
            with (resources / f"invalid-{kind}.csv").open("w", encoding="utf-8", newline="") as stream:
                csv.writer(stream).writerows([records[0], invalid_answer, records[1] + ["extra"]])
        executable = contents / "MacOS/QuizContentChecks"
        subprocess.run([
            swiftc, "-sdk", sdk, "-target", f"{platform.machine()}-apple-macos14.0",
            "-module-cache-path", str(temporary / "module-cache"),
            *[str(root / source) for source in sources], "-o", str(executable),
        ], env=env, check=True)
        result = subprocess.run([str(executable), str(root / "N2TestApp/Audio")], env=env, text=True, capture_output=True)
        if result.returncode:
            print(result.stdout)
            print(result.stderr)
            raise SystemExit(result.returncode)
        print(result.stdout.splitlines()[-1])


if __name__ == "__main__":
    main()
