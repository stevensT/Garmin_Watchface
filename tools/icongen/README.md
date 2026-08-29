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

## The launcher icon

`launchergen.js` is separate, and draws neither Material Symbols nor a slot icon:
it writes the app's launcher icon, a ZULU `Z` in the accent green on a dark disc,
set in the same Oswald as the numerals so the icon and the face read as one
object.

```sh
node launchergen.js
```

It writes **both sizes at once**, and that is the point of it. Launcher icon size
is a *device* property rather than a resolution one: the 454 devices ask for
65x65 and `fenix843mm` asks for **60x60**. Shipping only the 65 made the compiler
scale it and warn. The ratio between the letter and the disc is what makes the two
files look like the same icon, and it does not survive being rescaled by hand.

The em size is found by measuring the rendered cap height against `CAP_RATIO`
rather than by assuming a ratio. Oswald puts about 0.72 of its em into a capital,
but that is exactly the sort of number a font revision changes quietly.

**Do not put a red cross on it.** The placeholder this replaced was one. The red
cross is protected under the Geneva Conventions and by national law in most
countries, and unauthorised commercial use is an offence rather than merely a
trademark question.
