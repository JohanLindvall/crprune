# README preview

[`explorer.svg`](explorer.svg) is rendered from the actual explorer's terminal
cells with [`examples/sample-stats.json`](../../examples/sample-stats.json).
It contains synthetic data and no live registry information.

To refresh it from the repository root (Go and Python 3 standard library only):

```sh
mkdir -p /tmp/crprune-render
CRPRUNE_RENDER_DIR=/tmp/crprune-render go test ./internal/explore -run '^TestRenderSample$' -count=1
python3 scripts/render_terminal.py /tmp/crprune-render/explore-140x28.json docs/assets/explorer.svg
```

Open the SVG and check text, colors, and clipping before committing. The same
render helper also exports an 80×24 snapshot for inspecting smaller terminals.
