# fontgen

Turns a TTF into the BMFont pair Connect IQ wants: a `.fnt` and its atlas PNG.

Connect IQ does not accept TrueType directly. It reads a BMFont-generated `.fnt`,
and the `<font>` resource takes a `filter` attribute — a watch face needs only
`0123456789:`, so the atlas holds eleven glyphs instead of a full character set.
That is the difference between 12 kB and something that would not be worth doing.

## Reproducing the bundled fonts

```sh
npm install @napi-rs/canvas
curl -L -o Oswald.ttf \
  "https://github.com/google/fonts/raw/main/ofl/oswald/Oswald%5Bwght%5D.ttf"

# The numerals, one atlas per screen size. TABULAR is not optional here.
TABULAR=1 node bmfont.js Oswald.ttf Oswald bold 117 ../../resources/fonts        time_numbers
TABULAR=1 node bmfont.js Oswald.ttf Oswald bold 107 ../../resources-416x416/fonts time_numbers

# The gauge readout.
CHARS='0123456789%' \
  node bmfont.js Oswald.ttf Oswald bold 19 ../../resources/fonts arc_value

# The slot labels, uppercase only, tracked out a pixel.
export CHARS='ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/ -+.'
TRACKING=1 node bmfont.js Oswald.ttf Oswald 500 23 ../../resources/fonts         slot_label
TRACKING=1 node bmfont.js Oswald.ttf Oswald 500 21 ../../resources-416x416/fonts slot_label
```

Oswald ships only as a variable font, so it is rasterised from the variable file
at a weight rather than from a drawn instance. The numerals take `bold`; the
labels take `500`, because at 23 px a bold condensed cap is a blob.

`Oswald.ttf` and `node_modules/` are gitignored — fetch them when you need to
regenerate, and note that **the atlases for the two screen sizes have to be
regenerated together or they drift.**

## Three knobs

- **`CHARS`** — which glyphs land in the atlas. This is the whole economy of the
  thing: the numerals need eleven, the labels 41, and a full character set would
  cost more than the face can spend. Whatever you set here must match the
  `filter` attribute on the `<font>` in `fonts.xml`, or the resource compiler and
  the atlas disagree about what exists.
- **`TRACKING`** — pixels added to every glyph's advance. A condensed face set in
  all caps at label size sets too tightly to read at a glance; a pixel opens it
  up. Digits in a time readout want none, so it defaults to 0.
- **`TABULAR`** — give every digit the widest digit's advance and centre its ink
  in it. **The numerals must be built with this.** Oswald sets digits
  proportionally: at 117 px a `1` advances 45 px against a `0`'s 61. Centre a
  proportional `HH:MM` and the colon slides as the digits change — 32 px between
  `11:00` and `00:11` on the 454 — and the whole readout reflows every minute.
  Trevor caught this on the wrist as "the time doesn't look centred" before it
  had a name. With equal advances the colon does not move at all. The cost is
  that a `1` carries more air around it, which is how every digital clock looks.
  Off by default: the labels and the gauge readout are prose, not a clock.

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
