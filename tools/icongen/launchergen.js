// The launcher icon: a ZULU Z, in the face's accent green on a dark disc.
//
// Set in the same Oswald the numerals use, so the icon and the face are visibly
// the same object. The Z is what the face is about — a second time readout that
// defaults to ZULU — and a single letter is the only thing that survives being
// shrunk to 65 pixels.
//
// Two sizes, because the 43mm device asks for 60x60 where the 454 devices ask
// for 65x65. They are generated together so they cannot drift.
const fs = require('fs');
const path = require('path');
const { createCanvas, GlobalFonts } = require('@napi-rs/canvas');

const FAMILY = 'Oswald';
const TTF = path.join(__dirname, '../fontgen/Oswald.ttf');

const ACCENT = '#00E676';   // Theme.ACCENT_DEFAULT
const GROUND = '#101314';   // near-black, a shade off the face's own background
                            // so the disc still reads as a disc on a black list

// Cap height as a share of the icon's side. Large enough to carry at 65px,
// short enough to leave the disc a visible rim rather than a hairline.
const CAP_RATIO = 0.64;

const SIZES = [
  [65, '../../resources/drawables/launcher_icon.png'],
  [60, '../../resources-416x416/drawables/launcher_icon.png'],
];

GlobalFonts.registerFromPath(TTF, FAMILY);

for (const [side, rel] of SIZES) {
  const c = createCanvas(side, side);
  const ctx = c.getContext('2d');

  // The disc, inset a pixel so its edge is antialiased rather than clipped.
  ctx.fillStyle = GROUND;
  ctx.beginPath();
  ctx.arc(side / 2, side / 2, (side / 2) - 1, 0, Math.PI * 2);
  ctx.fill();

  // Find the em size that gives the cap height we asked for, by measuring rather
  // than assuming: Oswald puts about 0.72 of its em into a capital, but that is
  // the kind of number that changes when a font is revised.
  const target = side * CAP_RATIO;
  let em = Math.round(target / 0.72);
  for (let i = 0; i < 12; i++) {
    ctx.font = `700 ${em}px "${FAMILY}"`;
    const m = ctx.measureText('Z');
    const cap = m.actualBoundingBoxAscent + m.actualBoundingBoxDescent;
    if (Math.abs(cap - target) <= 0.5) break;
    em = Math.max(1, Math.round(em * (target / cap)));
  }

  ctx.font = `700 ${em}px "${FAMILY}"`;
  const m = ctx.measureText('Z');
  const capH = m.actualBoundingBoxAscent + m.actualBoundingBoxDescent;
  const capW = m.actualBoundingBoxRight + m.actualBoundingBoxLeft;

  // Centre on the ink box, not on the baseline or the advance. A Z has no
  // descender and Oswald's advance carries side bearings, so both would sit it
  // low and left.
  ctx.fillStyle = ACCENT;
  ctx.textBaseline = 'alphabetic';
  ctx.textAlign = 'left';
  ctx.fillText('Z',
    (side / 2) - (capW / 2) + m.actualBoundingBoxLeft,
    (side / 2) + (capH / 2) - m.actualBoundingBoxDescent);

  const out = path.join(__dirname, rel);
  fs.mkdirSync(path.dirname(out), { recursive: true });
  fs.writeFileSync(out, c.toBuffer('image/png'));
  console.log(`${path.basename(path.dirname(out))}/${path.basename(out)}: ` +
    `${side}x${side} em=${em} cap=${capH.toFixed(1)}x${capW.toFixed(1)} ` +
    `${fs.statSync(out).size}B`);
}
