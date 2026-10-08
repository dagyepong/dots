#!/usr/bin/env python3

# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   E M O J I                                                              │
# │   emoji index for the launcher · read from the unicode data files        │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""List every emoji with its name, keywords, group and skin tones.

Usage: emoji.py [language]

The sequences and groups come from emoji-test.txt (unicode-emoji). Names
come from the CLDR annotations (unicode-cldr-annotations) in the given
language; keywords in it, in the system's language and in English, so a
search finds an emoji in any of them. A flag is named after its country, from
iso-codes. Skin-tone variants are folded
into their base emoji as `tones`, five glyphs from light to dark.
"""

import gettext
import json
import os
import sys
import unicodedata
import xml.etree.ElementTree as ElementTree

SOURCE = "/usr/share/unicode/emoji/emoji-test.txt"
ANNOTATIONS = "/usr/share/unicode/cldr/common/annotations"

TONES = [chr(code) for code in range(0x1F3FB, 0x1F400)]
VARIATION = "️"


def fold(text):
    """Lowercase without accents, so `corazon` finds `corazón`."""
    decomposed = unicodedata.normalize("NFD", text.lower())
    return "".join(char for char in decomposed if not unicodedata.combining(char))


def bare(glyph):
    return glyph.replace(VARIATION, "")


def annotations(language):
    """Glyph without variation selectors -> (name, keywords)."""
    path = os.path.join(ANNOTATIONS, f"{language}.xml")
    names, keywords = {}, {}
    try:
        tree = ElementTree.parse(path)
    except (OSError, ElementTree.ParseError):
        return {}
    for node in tree.iter("annotation"):
        glyph = bare(node.get("cp", ""))
        text = (node.text or "").strip()
        if node.get("type") == "tts":
            names[glyph] = text
        else:
            keywords[glyph] = " ".join(word.strip() for word in text.split("|"))
    return {glyph: (name, keywords.get(glyph, "")) for glyph, name in names.items()}


def countries(language):
    """Flag glyph -> country name in the language, from iso-codes."""
    try:
        with open("/usr/share/iso-codes/json/iso_3166-1.json", encoding="utf-8") as source:
            table = json.load(source)["3166-1"]
    except (OSError, ValueError, KeyError):
        return {}
    translate = gettext.translation("iso_3166-1", languages=[language], fallback=True).gettext
    return {
        entry["flag"]: translate(entry.get("common_name", entry["name"]))
        for entry in table if "flag" in entry
    }


def compose(key, names):
    """A joined sequence CLDR does not name, named after its parts."""
    parts = [names.get(part, ("", ""))[0] for part in key.split("\u200d")]
    return ", ".join(parts) if len(parts) > 1 and all(parts) else ""


def tone_of(glyph):
    """Index of the one skin tone in a sequence, or None if it has none or several."""
    found = {TONES.index(char) for char in glyph if char in TONES}
    return found.pop() if len(found) == 1 else None


def system_language():
    locale = os.environ.get("LC_MESSAGES") or os.environ.get("LANG") or ""
    return locale.split("_")[0].split(".")[0] or "en"


def read(language):
    local = annotations(language)
    english = annotations("en") if language != "en" else local
    spoken = system_language()
    system = annotations(spoken) if spoken not in (language, "en") else {}
    flags = countries(language)
    system_flags = countries(spoken) if system else {}

    emoji = []
    by_bare = {}
    group = subgroup = ""
    with open(SOURCE, encoding="utf-8") as source:
        for line in source:
            line = line.strip()
            if line.startswith("# group:"):
                group = line.split(":", 1)[1].strip()
                continue
            if line.startswith("# subgroup:"):
                subgroup = line.split(":", 1)[1].strip()
                continue
            if not line or line.startswith("#") or "; fully-qualified" not in line:
                continue
            if group == "Component":
                continue

            # 1F600 ; fully-qualified # 😀 E1.0 grinning face
            glyph, _, unicode_name = line.split("#", 1)[1].strip().split(" ", 2)

            if any(char in TONES for char in glyph):
                tone = tone_of(glyph)
                base = by_bare.get(bare("".join(char for char in glyph if char not in TONES)))
                if tone is not None and base is not None:
                    base["tones"][tone] = glyph
                continue

            key = bare(glyph)
            system_name, system_words = system.get(key, ("", ""))
            system_name = system_flags.get(glyph, system_name)
            name, words = local.get(key, ("", ""))
            if not name and language != "en":
                name = compose(key, local)
            english_name, english_words = english.get(key, (unicode_name, ""))
            if group == "Flags" and glyph in flags:
                name = flags[glyph]
            name = name or english_name

            item = {
                "glyph": glyph,
                "name": name[:1].upper() + name[1:],
                "group": group,
                "tones": [""] * len(TONES),
                "keywords": fold(" ".join([
                    name, words, english_name, english_words, unicode_name,
                    system_name, system_words,
                    subgroup.replace("-", " "), group,
                ])),
            }
            emoji.append(item)
            by_bare[key] = item

    for item in emoji:
        if not all(item["tones"]):
            del item["tones"]
    return emoji


def main():
    language = sys.argv[1] if len(sys.argv) > 1 else "en"
    try:
        emoji = read(language)
    except OSError as error:
        sys.stderr.write(f"Cannot read {SOURCE}: {error}\n")
        emoji = []
    json.dump(emoji, sys.stdout, ensure_ascii=False, separators=(",", ":"))


if __name__ == "__main__":
    main()
