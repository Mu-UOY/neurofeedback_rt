#!/usr/bin/env python3
"""Generate or verify the deterministic MATLAB-only repository summary."""

from __future__ import annotations

import argparse
from pathlib import Path
import sys


MATLAB_PATTERN = "*.m"
EXCLUDED_TOP_LEVEL_DIRECTORIES = {".git", "dev-archive", "logs", "outputs"}
SEPARATOR = "=" * 88


def project_root() -> Path:
    return Path(__file__).resolve().parents[2]


def matlab_files(root: Path) -> list[Path]:
    files: list[Path] = []
    for path in root.rglob(MATLAB_PATTERN):
        relative = path.relative_to(root)
        if relative.parts and relative.parts[0] in EXCLUDED_TOP_LEVEL_DIRECTORIES:
            continue
        if path.is_file():
            files.append(path)
    return sorted(files, key=lambda path: path.relative_to(root).as_posix())


def normalized_source(path: Path) -> str:
    text = path.read_text(encoding="utf-8-sig")
    return text.replace("\r\n", "\n").replace("\r", "\n").rstrip("\n")


def render_summary(root: Path) -> str:
    files = matlab_files(root)
    lines = [
        "neurofeedback_rt MATLAB code summary",
        f"Project root: {root}",
        f"MATLAB files: {len(files)}",
        "",
    ]
    for path in files:
        relative = path.relative_to(root).as_posix()
        lines.extend(
            [
                SEPARATOR,
                f"FILE: {relative}",
                SEPARATOR,
                "```matlab",
                normalized_source(path),
                "```",
                "",
            ]
        )
    return "\n".join(lines)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    check_group = parser.add_mutually_exclusive_group()
    check_group.add_argument(
        "--check",
        action="store_true",
        help="exit nonzero unless code_summary.txt exactly matches fresh output",
    )
    check_group.add_argument(
        "--check-file",
        type=Path,
        help="exit nonzero unless the supplied file exactly matches fresh output",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = project_root()
    output = Path(__file__).resolve().with_name("code_summary.txt")
    expected = render_summary(root)
    check_path = args.check_file if args.check_file is not None else output
    if args.check or args.check_file is not None:
        if not check_path.is_file():
            print(f"[FAIL] missing generated summary: {check_path}", file=sys.stderr)
            return 1
        actual = check_path.read_text(encoding="utf-8")
        if actual != expected:
            print(
                "[FAIL] code_summary.txt is stale or contains non-generator content",
                file=sys.stderr,
            )
            return 1
        print(f"[PASS] code summary matches {len(matlab_files(root))} MATLAB files")
        return 0

    with output.open("w", encoding="utf-8", newline="\n") as stream:
        stream.write(expected)
    print(f"Wrote {output} from {len(matlab_files(root))} MATLAB files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
