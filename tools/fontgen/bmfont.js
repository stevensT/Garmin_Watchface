// Minimal BMFont generator for Connect IQ.
//
// Connect IQ takes a BMFont .fnt plus its page PNG, and a watch face only needs
// digits and a colon, so the atlas stays tiny. Glyph boxes are found by scanning
// pixels rather than trusting canvas metrics, whose sign conventions differ
// between engines.
const fs = require('fs');
const path = require('path');
const { createCanvas, GlobalFonts } = require('@napi-rs/canvas');

const CHARS = '0123456789:';
const PAD = 8;

function generate(ttfPath, family, weight, size, outDir, outName) {
  GlobalFonts.registerFromPath(ttfPath, family);

  const probe = createCanvas(64, 64).getContext('2d');
  probe.font = `${weight} ${size}px "${family}"`;
  const fm = probe.measureText('0');
  const ascent = Math.ceil(fm.fontBoundingBoxAscent);
  const descent = Math.ceil(fm.fontBoundingBoxDescent);
  const lineHeight = ascent + descent;

  // Rasterise each glyph on its own, then find its real ink box.
  const glyphs = CHARS.split('').map((ch) => {
    const advance = Math.ceil(probe.measureText(ch).width);
    const w = advance + PAD * 2;
    const h = lineHeight + PAD * 2;
    const c = createCanvas(w, h);
    const ctx = c.getContext('2d');
    ctx.font = `${weight} ${size}px "${family}"`;
    ctx.fillStyle = '#fff';
    ctx.textBaseline = 'alphabetic';
    ctx.fillText(ch, PAD, PAD + ascent);

    const data = ctx.getImageData(0, 0, w, h).data;
    let minX = w, minY = h, maxX = -1, maxY = -1;
    for (let y = 0; y < h; y++) {
      for (let x = 0; x < w; x++) {
        if (data[(y * w + x) * 4 + 3] > 0) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }
    if (maxX < 0) { minX = 0; minY = 0; maxX = 0; maxY = 0; }

    return {
      ch,
      advance,
      canvas: c,
      sx: minX, sy: minY,
      width: maxX - minX + 1,
      height: maxY - minY + 1,
      xoffset: minX - PAD,
      yoffset: minY - PAD,
    };
  });

  // Pack into rows inside a power-of-two atlas.
  const maxW = 512;
  let x = 0, y = 0, rowH = 0, atlasW = 0;
  for (const g of glyphs) {
    if (x + g.width > maxW) { x = 0; y += rowH + 1; rowH = 0; }
    g.x = x; g.y = y;
    x += g.width + 1;
    rowH = Math.max(rowH, g.height);
    atlasW = Math.max(atlasW, x);
  }
  const atlasH = y + rowH;
  const pot = (n) => { let p = 1; while (p < n) p *= 2; return p; };
  const sheetW = pot(atlasW), sheetH = pot(atlasH);

  const sheet = createCanvas(sheetW, sheetH);
  const sctx = sheet.getContext('2d');
  for (const g of glyphs) {
    sctx.drawImage(g.canvas, g.sx, g.sy, g.width, g.height, g.x, g.y, g.width, g.height);
  }

  fs.mkdirSync(outDir, { recursive: true });
  const png = `${outName}.png`;
  fs.writeFileSync(path.join(outDir, png), sheet.toBuffer('image/png'));

  const lines = [
    `info face="${family}" size=${size} bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=1,1 outline=0`,
    `common lineHeight=${lineHeight} base=${ascent} scaleW=${sheetW} scaleH=${sheetH} pages=1 packed=0 alphaChnl=0 redChnl=4 greenChnl=4 blueChnl=4`,
    `page id=0 file="${png}"`,
    `chars count=${glyphs.length}`,
  ];
  for (const g of glyphs) {
    lines.push(
      `char id=${g.ch.charCodeAt(0)} x=${g.x} y=${g.y} width=${g.width} height=${g.height} ` +
      `xoffset=${g.xoffset} yoffset=${g.yoffset} xadvance=${g.advance} page=0 chnl=15`
    );
  }
  lines.push('kernings count=0');
  fs.writeFileSync(path.join(outDir, `${outName}.fnt`), lines.join('\n') + '\n');

  const digit = glyphs[0];
  console.log(`${outName}: size=${size} lineHeight=${lineHeight} base=${ascent} ` +
    `atlas=${sheetW}x${sheetH} digitInk=${digit.width}x${digit.height} advance=${digit.advance} ` +
    `png=${fs.statSync(path.join(outDir, png)).size}B`);
}

const [, , ttf, family, weight, size, outDir, outName] = process.argv;
generate(ttf, family, weight, parseInt(size, 10), outDir, outName);
