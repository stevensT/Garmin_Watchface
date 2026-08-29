# fontgen

Turns a TTF into the BMFont pair Connect IQ wants: a `.fnt` and its atlas PNG.

Connect IQ does not accept TrueType directly. It reads a BMFont-generated `.fnt`,
and the `<font>` resource takes a `filter` attribute — a watch face needs only
`0123456789:`, so the atlas holds eleven glyphs instead of a full character set.
That is the difference between 12 kB and something that would not be worth doing.

## Reproducing the bundled font

```sh
npm install @napi-rs/canvas
curl -L -o Oswald.ttf \
  "https://github.com/google/fonts/raw/main/ofl/oswald/Oswald%5Bwght%5D.ttf"
node bmfont.js Oswald.ttf Oswald bold 117 ../../resources/fonts time_numbers
```

Oswald ships only as a variable font, so it is rasterised at bold from the
variable file rather than from a drawn Bold instance.

## Choosing a size

Families put very different amounts of ink into the same nominal size — measured
against the size requested, digit height came out at 0.719 for Barlow Condensed,
0.781 for Roboto Condensed and 0.854 for Oswald. Compare candidates at a matched
digit height, not a matched point size, or you are just looking at one of them
bigger than the others.

The script prints the metrics that matter, including `base`, which is where the
baseline falls inside the line box. Oswald's baseline sits 140 px down a 174 px
box, well below centre, which is why `Layout.TIME_Y` had to move up to keep the
digits off the second-time line.

## The 416x416 atlas

A bitmap font does not scale, but `Layout.mc` places everything as a fraction of
the screen. Shipping the 454's atlas to the 416 device therefore kept a 174 px
line box while the room around it shrank by 38 px, leaving one pixel between the
digits and the second-time line where the 454 has eight.

So the smaller face gets its own atlas at 416/454 of the size:

```sh
node bmfont.js Oswald.ttf Oswald bold 107 ../../resources-416x416/fonts time_numbers
```

`monkey.jungle` puts `resources-416x416` on `fenix843mm`'s resource path only, and
the font keeps the same id, so the device build overrides the default and no code
changes. Regenerate both when the face changes, or they drift apart.
