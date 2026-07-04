#!/usr/bin/env python3
"""B19 gate: char-limit + cross-field dedup checks for the store listing pack.

Usage: python3 scripts/check_store_listing.py

Parses product/store-listing/texts/{en-US,tr}.md. Field format:

    ### FIELD: <name> · limit <N>
    ```text
    <value>
    ```

Checks (issue #29 sub-task gates):
  1. Every field fits its ASC char limit (counted in Unicode chars, the way
     App Store Connect counts).
  2. No word token repeated across name / subtitle / keywords (indexed fields
     share one keyword pool; a repeat is a wasted slot).
  3. Keywords: no space after commas (wasted chars).
  4. Screenshot captions (FIELD: captions): every line <= 6 words.

Exit 0 = all gates pass. Any violation prints FAIL and exits 1.
"""

import re
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TEXTS = ROOT / "product" / "store-listing" / "texts"
LOCALES = ["en-US", "tr"]

FIELD_RE = re.compile(
    r"^### FIELD: (?P<name>[\w-]+) · limit (?P<limit>\d+)\s*\n```text\n(?P<value>.*?)\n```",
    re.M | re.S,
)

failures = []


def tokens(text: str) -> list[str]:
    # Unicode-aware word tokens, lowercased (py3 str.lower handles tr chars).
    return [t.lower() for t in re.findall(r"\w+", text, re.UNICODE)]


def check_locale(locale: str) -> dict:
    path = TEXTS / f"{locale}.md"
    if not path.exists():
        failures.append(f"{locale}: missing file {path}")
        return {}
    fields = {}
    for m in FIELD_RE.finditer(path.read_text(encoding="utf-8")):
        name, limit, value = m["name"], int(m["limit"]), m["value"]
        value = unicodedata.normalize("NFC", value)
        fields[name] = value
        n = len(value)
        status = "OK " if n <= limit else "FAIL"
        print(f"  {status} {locale:>5} {name:<12} {n:>4} / {limit}")
        if n > limit:
            failures.append(f"{locale}/{name}: {n} chars > limit {limit}")

    # Gate 2: cross-field dedup over the indexed fields.
    indexed = {f: fields.get(f, "") for f in ("name", "subtitle", "keywords")}
    seen: dict[str, str] = {}
    for fname, value in indexed.items():
        for tok in set(tokens(value)):
            if tok in seen and seen[tok] != fname:
                failures.append(
                    f"{locale}: token '{tok}' repeated across {seen[tok]} + {fname}"
                )
            seen.setdefault(tok, fname)

    # Gate 3: keyword hygiene.
    kw = fields.get("keywords", "")
    if ", " in kw:
        failures.append(f"{locale}/keywords: space after comma wastes chars")
    if kw.endswith(",") or kw != kw.strip():
        failures.append(f"{locale}/keywords: stray leading/trailing chars")

    # Gate 4: captions <= 6 words per line.
    for i, line in enumerate(fields.get("captions", "").splitlines(), 1):
        text = line.split("|", 1)[-1].strip() if "|" in line else line.strip()
        if not text:
            continue
        words = len(text.split())
        if words > 6:
            failures.append(
                f"{locale}/captions line {i}: {words} words > 6 ('{text}')"
            )
    return fields


def main() -> int:
    print("B19 store-listing gates")
    for locale in LOCALES:
        check_locale(locale)
    if failures:
        print("\nFAIL:")
        for f in failures:
            print(f"  - {f}")
        return 1
    print("\nAll gates pass (limits, dedup, keyword hygiene, caption length).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
