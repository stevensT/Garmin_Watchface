// Status icons are generated at their own smaller size, so they read as a
// discreet column beside the time rather than as more data.
const fs = require('fs');
const path = require('path');
const { createCanvas, GlobalFonts } = require('@napi-rs/canvas');

const SIZE = 24, PAD = 6, COLOUR = '#808080', FAMILY = 'MaterialSymbols';
const ICONS = [
  ['bluetooth',            'icon_status_ble'],
  ['wifi',                 'icon_status_wifi'],
  ['lte_mobiledata',       'icon_status_lte'],
  ['notifications_active', 'icon_status_notify'],
];

const codepoints = {};
for (const line of fs.readFileSync(path.join(__dirname, 'icons/codepoints'), 'utf8').split('\n')) {
  const [name, hex] = line.trim().split(' ');
  if (name && hex) codepoints[name] = String.fromCodePoint(parseInt(hex, 16));
}
GlobalFonts.registerFromPath(path.join(__dirname, 'icons/MaterialSymbols.ttf'), FAMILY);

const outDir = process.argv[2];
for (const [name, file] of ICONS) {
  const side = SIZE + PAD * 2;
  const c = createCanvas(side, side);
  const ctx = c.getContext('2d');
  ctx.font = `${SIZE}px "${FAMILY}"`;
  ctx.fillStyle = COLOUR;
  ctx.textBaseline = 'alphabetic';
  ctx.fillText(codepoints[name], PAD, PAD + SIZE);
  const d = ctx.getImageData(0, 0, side, side).data;
  let minX = side, minY = side, maxX = -1, maxY = -1;
  for (let y = 0; y < side; y++) for (let x = 0; x < side; x++) {
    if (d[(y * side + x) * 4 + 3] > 0) {
      if (x < minX) minX = x; if (x > maxX) maxX = x;
      if (y < minY) minY = y; if (y > maxY) maxY = y;
    }
  }
  const w = maxX - minX + 1, h = maxY - minY + 1;
  const out = createCanvas(w, h);
  out.getContext('2d').drawImage(c, minX, minY, w, h, 0, 0, w, h);
  fs.writeFileSync(path.join(outDir, `${file}.png`), out.toBuffer('image/png'));
  console.log(`${file}: ${w}x${h}`);
}
