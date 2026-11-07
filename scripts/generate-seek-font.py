#!/usr/bin/env python3
"""Build the two seek glyphs from their SVG sources.

Install scripts/seek-font-requirements.txt in a Python virtual environment,
then run this script. The generated font is committed; Flutter builds do not
need Python. Stroke expansion happens here, so runtime uses Flutter's Icon
font rasterizer, as lucide_icons_flutter does.
"""

from pathlib import Path
from xml.etree import ElementTree

import pathops
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.svgLib.path import parse_path


ROOT = Path(__file__).resolve().parent.parent
UNITS_PER_EM = 1000  # Match Lucide's square em, ascent, descent and advance.
ICONS = {0xE000: "backward", 0xE001: "forward"}


def main():
    glyphs = {".notdef": TTGlyphPen(None).glyph()}
    for name in ICONS.values():
        svg = ElementTree.parse(
            ROOT / f"assets/icons/seek_{name}_10.svg"
        ).getroot()
        x, y, width, height = map(float, svg.attrib["viewBox"].split())
        if width != height:
            raise ValueError("Seek glyphs require a square viewBox")
        outline = pathops.Path()
        for node in svg:
            parse_path(node.attrib["d"], outline.getPen())
        outline.stroke(
            float(svg.attrib["stroke-width"]),
            pathops.LineCap.ROUND_CAP,
            pathops.LineJoin.ROUND_JOIN,
            4,
        )
        outline.convertConicsToQuads(0.001)
        outline = pathops.simplify(outline)
        scale = UNITS_PER_EM / width
        outline = outline.transform(
            scale, 0, 0, -scale, -x * scale, (y + height) * scale
        )
        pen = TTGlyphPen(None)
        # At 28 px, 0.5 font units is at most 0.014 px of curve error.
        outline.draw(Cu2QuPen(pen, max_err=0.5, reverse_direction=True))
        glyphs[name] = pen.glyph()

    font = FontBuilder(UNITS_PER_EM, isTTF=True)
    font.setupGlyphOrder(list(glyphs))
    font.setupCharacterMap(ICONS)
    font.setupGlyf(glyphs)
    font.setupHorizontalMetrics(
        {name: (UNITS_PER_EM, getattr(glyph, "xMin", 0))
         for name, glyph in glyphs.items()}
    )
    font.setupHorizontalHeader(ascent=UNITS_PER_EM, descent=0)
    font.setupNameTable({
        "familyName": "VpflSeek",
        "styleName": "Regular",
        "uniqueFontIdentifier": "VpflSeek-Regular-1.0",
        "fullName": "VpflSeek Regular",
        "psName": "VpflSeek-Regular",
        "version": "Version 1.0",
        "copyright": "Copyright (c) 2020-2026 Pawel Kuna; MIT License",
        "licenseDescription": (ROOT / "assets/icons/LICENSE.tabler").read_text(),
    })
    font.setupOS2(
        sTypoAscender=UNITS_PER_EM, sTypoDescender=0,
        usWinAscent=UNITS_PER_EM, usWinDescent=0,
    )
    font.setupPost()
    font.font.recalcTimestamp = False
    font.font["head"].created = font.font["head"].modified = 2082844800
    font.save(ROOT / "assets/fonts/VpflSeek.ttf")


if __name__ == "__main__":
    main()
