# icongen

Rasterises Material Symbols glyphs into the small PNGs a slot draws in place of
its text label.

Material Symbols is Apache 2.0, so the glyphs can ship. Using an icon font rather
than hand-drawn art means the set is consistent, and extending it is a one-line
change here rather than a drawing job.

## Reproducing the icons

```sh
npm install @napi-rs/canvas
mkdir -p icons
BASE=https://github.com/google/material-design-icons/raw/master/variablefont
FONT='MaterialSymbolsOutlined%5BFILL%2CGRAD%2Copsz%2Cwght%5D'
curl -L -o icons/MaterialSymbols.ttf "$BASE/$FONT.ttf"
curl -L -o icons/codepoints        "$BASE/$FONT.codepoints"
node icongen.js ../../resources/drawables
```

## Adding an icon

Add a row to `ICONS` here, a `<bitmap>` to `resources/drawables/drawables.xml`,
and a branch to `SlotIcons.resourceFor`. The glyph name must appear in the
`codepoints` file; grep it before guessing, because the names are not always what
you would expect.

## Two things that are deliberate

The colour is baked in at `#808080`, matching `Theme.MUTED_DEFAULT`. Connect IQ
draws a bitmap as it finds it, and the label colour these stand in for is a
constant, so tinting at runtime would buy nothing.

Each PNG is cropped to its own ink rather than padded to a common square, so the
slot centres each icon on the label's line. Icon shapes vary a lot — the altitude
glyph is 28x16 and the battery is 14x26 — and a common box would leave some of
them visibly off-centre.
