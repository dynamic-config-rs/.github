"""Constructions that read as commentary rather than documentation.

Run over every book:

    python prose-check.py                 # counts per book
    python prose-check.py --list          # every hit, with file and line
    python prose-check.py <book>/book/src # one book

The rule these encode: state the behaviour, then the reason it matters to
the reader. Never the deliberation behind it, the repository's history, or
the documentation's own structure.
"""

from __future__ import annotations

import re
import sys
from collections import Counter
from pathlib import Path

#: Each entry is (name, pattern). Deliberately narrow: a checker that flags
#: ordinary prose gets switched off, and one nobody runs catches nothing.
BANNED = [
    ("first person", r"\b(we|our|us)\b(?! )(?<!\bour\b)"),
    ("first person", r"\b(we|our)\s+(own|have|do|are|chose|decided|think)\b"),
    ("deliberately", r"\bdeliberate(ly)?\b"),
    ("that is the point", r"\b(that|which|this) is (exactly )?the (whole )?point\b"),
    ("the whole reason", r"\bthe whole reason\b"),
    ("worth stating", r"\bworth (stating|saying|writing down)\b"),
    ("rather than pretending", r"\brather than pretend(ing)?\b"),
    ("meta: this repository", r"\bthis (repository|repo)\b"),
    ("meta: this book/page", r"\bthis (book|page|chapter) (is|exists|used|says|carries)"),
    ("meta: separate book", r"\bseparate book\b"),
    ("heading: X, and why Y", r"^#+ .*,\s+and why\b"),
    ("heading: Why not", r"^#+ Why (not|it)\b"),
    ("decision-not-oversight", r"\bdecision rather than (an? )?(oversight|gap|omission)\b"),
    ("a lie about", r"\bwould be a lie\b"),
    ("theatre", r"\bwould be theatre\b"),
]

COMPILED = [(name, re.compile(pattern, re.IGNORECASE | re.MULTILINE)) for name, pattern in BANNED]


def hits(path: Path) -> list[tuple[int, str, str]]:
    """Every banned construction in one file."""
    found = []

    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        for name, pattern in COMPILED:
            match = pattern.search(line)

            if match:
                found.append((number, name, line.strip()[:96]))

    return found


def main() -> int:
    """Counts, or lists, depending on the arguments."""
    listing = "--list" in sys.argv
    roots = [Path(argument) for argument in sys.argv[1:] if not argument.startswith("--")]

    if not roots:
        roots = sorted(Path().glob("*/book/src"))

    total = 0

    for root in roots:
        pages = sorted(root.rglob("*.md"))
        counts: Counter[str] = Counter()
        book_total = 0

        for page in pages:
            for number, name, text in hits(page):
                counts[name] += 1
                book_total += 1

                if listing:
                    print(f"{page}:{number}: [{name}] {text}")

        total += book_total
        flag = "clean" if book_total == 0 else f"{book_total} hits"
        print(f"{str(root):48} {flag}")

        if counts and not listing:
            for name, count in counts.most_common():
                print(f"{'':48}   {count:3}  {name}")

    print(f"\n{total} in total")

    return 1 if total else 0


if __name__ == "__main__":
    raise SystemExit(main())
