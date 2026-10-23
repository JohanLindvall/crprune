#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Render the cell JSON from TestRenderSample as a self-contained SVG."""

import argparse
import html
import json
from pathlib import Path


def render(snapshot):
    columns, rows = snapshot["Width"], snapshot["Height"]
    cells = snapshot["Cells"]
    if columns <= 0 or rows <= 0 or len(cells) != columns * rows:
        raise ValueError("snapshot dimensions do not match its cells")

    cell_width, cell_height, padding, title_height = 10, 21, 18, 42
    width = columns * cell_width + padding * 2
    height = rows * cell_height + padding * 2 + title_height
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
        f'viewBox="0 0 {width} {height}" role="img" aria-labelledby="title desc">',
        "<title id=\"title\">Regtend statistics explorer</title>",
        "<desc id=\"desc\">Actual terminal UI rendered with synthetic sample data. "
        "Repository sizes, manifest counts, and the selected repository's details.</desc>",
        f'<rect width="{width}" height="{height}" rx="12" fill="#111923"/>',
        '<g fill="#98a9bc" font-family="ui-monospace,DejaVu Sans Mono,monospace" '
        'font-size="14">',
        '<text x="20" y="28">regtend explore examples/sample-stats.json</text>',
        "</g>",
        '<g font-family="ui-monospace,DejaVu Sans Mono,monospace" font-size="16">',
    ]
    for row in range(rows):
        col = 0
        while col < columns:
            cell = cells[row * columns + col]
            style = (cell["FG"], cell["BG"], cell["Bold"], cell["Reverse"])
            end = col + 1
            while end < columns:
                next_cell = cells[row * columns + end]
                if (next_cell["FG"], next_cell["BG"], next_cell["Bold"], next_cell["Reverse"]) != style:
                    break
                end += 1
            foreground, background, bold, reverse = style
            foreground = foreground if foreground >= 0 else 0xDCE4EE
            background = background if background >= 0 else 0x111923
            if reverse:
                foreground, background = background, foreground
            x = padding + col * cell_width
            y = padding + title_height + row * cell_height
            length = (end - col) * cell_width
            if background != 0x111923:
                parts.append(
                    f'<rect x="{x}" y="{y}" width="{length}" '
                    f'height="{cell_height}" fill="#{background:06x}"/>'
                )
            text = "".join(
                c["Text"] or " " for c in cells[row * columns + col : row * columns + end]
            )
            if text.strip():
                weight = ' font-weight="bold"' if bold else ""
                parts.append(
                    f'<text x="{x}" y="{y + 16}" fill="#{foreground:06x}"{weight} '
                    f'xml:space="preserve" textLength="{length}" lengthAdjust="spacingAndGlyphs">'
                    f"{html.escape(text)}</text>"
                )
            col = end
    parts.extend(["</g>", "</svg>"])
    return "\n".join(parts) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("snapshot", type=Path, help="JSON produced by TestRenderSample")
    parser.add_argument("output", type=Path, help="SVG output path")
    args = parser.parse_args()
    args.output.write_text(render(json.loads(args.snapshot.read_text(encoding="utf-8"))), encoding="utf-8")


if __name__ == "__main__":
    main()
