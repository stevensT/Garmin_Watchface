// Rasterises Material Symbols glyphs into the small PNGs a slot draws in place
// of its text label.
//
// The colour is baked in rather than tinted at runtime: Connect IQ draws a
// bitmap as it finds it, and the label colour these stand in for is a constant.
const fs = require('fs');
const path = require('path');
const { createCanvas, GlobalFonts } = require('@napi-rs/canvas');

const FAMILY = 'MaterialSymbols';
const COLOUR = '#808080';   // Theme.MUTED_DEFAULT
const SIZE = 30;            // rasterised em size; the ink lands nearer 24
const PAD = 6;

const ICONS = [
  ['monitor_heart',         'icon_heart_rate'],
  ['directions_walk',       'icon_steps'],
  ['battery_horiz_050',     'icon_battery'],
  ['bolt',                  'icon_body_battery'],
  ['local_fire_department', 'icon_calories'],
  ['stairs',                'icon_floors'],
  ['thermostat',            'icon_temperature'],
  ['terrain',               'icon_altitude'],
  ['wb_sunny',              'icon_sunrise'],
  ['wb_twilight',           'icon_sunset'],
  ['notifications',         'icon_notifications'],
  ['bedtime',               'icon_sleep'],
  ['water_drop',            'icon_pulse_ox'],
  ['air',                   'icon_respiration'],
  ['timer',                 'icon_intensity'],
  ['calendar_month',        'icon_date'],
];

const codepoints = {};
for (const line of fs.readFileSync(path.join(__dirname, 'icons/codepoints'), 'utf8').split('\n')) {
  const [name, hex] = line.trim().split(' ');
  if (name && hex) codepoints[name] = String.fromCodePoint(parseInt(hex, 16));
}

GlobalFonts.registerFromPath(path.join(__dirname, 'icons/MaterialSymbols.ttf'), FAMILY);
const outDir = process.argv[2];
fs.mkdirSync(outDir, { recursive: true });

for (const [name, file] of ICONS) {
  const glyph = codepoints[name];
  if (!glyph) { throw new Error(`no codepoint for ${name}`); }

  const side = SIZE + PAD * 2;
  const c = createCanvas(side, side);
  const ctx = c.getContext('2d');
  ctx.font = `${SIZE}px "${FAMILY}"`;
  ctx.fillStyle = COLOUR;
  ctx.textBaseline = 'alphabetic';
  ctx.fillText(glyph, PAD, PAD + SIZE);

  // Crop to the ink, so every icon is its own size and the slot can centre it.
  const d = ctx.getImageData(0, 0, side, side).data;
  let minX = side, minY = side, maxX = -1, maxY = -1;
  for (let y = 0; y < side; y++) {
    for (let x = 0; x < side; x++) {
      if (d[(y * side + x) * 4 + 3] > 0) {
        if (x < minX) minX = x; if (x > maxX) maxX = x;
        if (y < minY) minY = y; if (y > maxY) maxY = y;
      }
    }
  }
  const w = maxX - minX + 1, h = maxY - minY + 1;
  const out = createCanvas(w, h);
  out.getContext('2d').drawImage(c, minX, minY, w, h, 0, 0, w, h);
  fs.writeFileSync(path.join(outDir, `${file}.png`), out.toBuffer('image/png'));
  console.log(`${file}: ${w}x${h}`);
}
