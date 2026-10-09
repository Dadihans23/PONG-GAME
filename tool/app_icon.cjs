/*
 * Icône de l'app Tilto, proposition 2a « Raquette inclinée ».
 *
 * Source de vérité : la géométrie ci-dessous, relevée dans
 * maquette/Corrections et validation des maquettes/Tilto Icone.dc.html (section #2a),
 * exprimée sur le canevas d'une icône adaptative Android (108 × 108 dp).
 *
 * Le script écrit les SVG (assets/icon/), puis les rend en PNG avec Chromium
 * (Playwright) : Android (icônes classiques, premier plan adaptatif), Play Store,
 * iOS et site. Il écrit aussi le fond et la silhouette monochrome d'Android
 * (res/drawable/ic_launcher_background.xml et ic_launcher_monochrome.xml),
 * en vector drawables, à partir des mêmes valeurs.
 *
 * Usage, depuis la racine du projet (sans téléchargement si un Chromium de
 * ms-playwright est déjà présent : il sert de secours) :
 *   npx -y playwright@1.64.0 --version   (met Playwright en cache une fois)
 *   node tool/app_icon.cjs
 * Si Playwright est installé ailleurs : PLAYWRIGHT_MODULE=<dossier du paquet> node tool/app_icon.cjs
 */
'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const C = 108; // canevas, en dp

// --- Géométrie de la maquette (pourcentages du canevas) ---------------------
const BG_FROM = '#1C1C28';
const BG_TO = '#0B0B10';
const BG_CENTER = { x: 0.5, y: 0.42 }; // radial-gradient(circle at 50% 42%, …)
const BG_STOP = 0.7; //                    … #1C1C28 0%, #0B0B10 70%)
const PINK = '#E91E63';

// Raquette : left 27 %, top 60 %, 46 % × 10 %, bouts ronds, rotate(-16deg) autour de son centre.
const PADDLE = { x: 0.27, y: 0.6, w: 0.46, h: 0.1, angle: -16 };
const PADDLE_GLOW = { blur: 0.07, color: 'rgba(233,30,99,.65)' }; // box-shadow 0 0 7cqw
// Balle : left 47 %, top 27 %, diamètre 17 %.
const BALL = { x: 0.47, y: 0.27, d: 0.17 };
const BALL_GLOW = { blur: 0.06, color: 'rgba(255,255,255,.55)' }; // box-shadow 0 0 6cqw

// Échelle du premier plan de l'icône adaptative Android, autour du centre.
// Un lanceur n'affiche que les 72 dp centraux du calque de 108 dp : à 0.667
// (72/108), le téléphone montre la même composition que les aperçus masqués de
// la maquette, halo compris. Les icônes pleines (classiques, Play Store, iOS,
// site) gardent le calque de la maquette tel quel (échelle 1).
const FOREGROUND_SCALE = 0.667;

// --- Dérivés, en unités du canevas ------------------------------------------
const r = (v) => Math.round(v * 1000) / 1000;
const p = {
  x: PADDLE.x * C, y: PADDLE.y * C, w: PADDLE.w * C, h: PADDLE.h * C,
};
p.cx = p.x + p.w / 2;
p.cy = p.y + p.h / 2;
const b = { cx: (BALL.x + BALL.d / 2) * C, cy: (BALL.y + BALL.d / 2) * C, r: (BALL.d / 2) * C };
// CSS : rayon « farthest-corner » depuis le centre du dégradé.
const bg = { cx: BG_CENTER.x * C, cy: BG_CENTER.y * C };
bg.r = Math.hypot(Math.max(bg.cx, C - bg.cx), Math.max(bg.cy, C - bg.cy));
// CSS : le flou d'une box-shadow vaut deux écarts-types de gaussienne.
const sigma = (blur) => r((blur * C) / 2);

function foregroundShapes({ glow = true, fill = null, scale = 1 } = {}) {
  const paddle = (extra) => `<rect x="${r(p.x)}" y="${r(p.y)}" width="${r(p.w)}" height="${r(p.h)}" rx="${r(p.h / 2)}" ${extra} transform="rotate(${PADDLE.angle} ${r(p.cx)} ${r(p.cy)})"/>`;
  const ball = (extra) => `<circle cx="${r(b.cx)}" cy="${r(b.cy)}" r="${r(b.r)}" ${extra}/>`;
  const parts = [];
  if (glow) parts.push(paddle(`fill="${PADDLE_GLOW.color}" filter="url(#glowPaddle)"`));
  parts.push(paddle(`fill="${fill || PINK}"`));
  if (glow) parts.push(ball(`fill="${BALL_GLOW.color}" filter="url(#glowBall)"`));
  parts.push(ball(`fill="${fill || '#FFFFFF'}"`));
  const s = scale;
  const t = s === 1 ? '' : ` transform="translate(${r(C / 2 * (1 - s))} ${r(C / 2 * (1 - s))}) scale(${s})"`;
  return `  <g${t}>\n    ${parts.join('\n    ')}\n  </g>`;
}

const defsGlow = `    <filter id="glowPaddle" filterUnits="userSpaceOnUse" x="-${C}" y="-${C}" width="${3 * C}" height="${3 * C}"><feGaussianBlur stdDeviation="${sigma(PADDLE_GLOW.blur)}"/></filter>
    <filter id="glowBall" filterUnits="userSpaceOnUse" x="-${C}" y="-${C}" width="${3 * C}" height="${3 * C}"><feGaussianBlur stdDeviation="${sigma(BALL_GLOW.blur)}"/></filter>`;
// Dégradé du fond, mis à l'échelle autour du centre comme le premier plan :
// le fond adaptatif suit FOREGROUND_SCALE pour que les 72 dp visibles
// reproduisent le dégradé de la maquette, l'icône pleine reste à 1.
const bgAt = (s) => ({ cx: C / 2 + (bg.cx - C / 2) * s, cy: C / 2 + (bg.cy - C / 2) * s, r: bg.r * s });
const gradient = (s) => {
  const g = bgAt(s);
  return `    <radialGradient id="bg" gradientUnits="userSpaceOnUse" cx="${r(g.cx)}" cy="${r(g.cy)}" r="${r(g.r)}">
      <stop offset="0" stop-color="${BG_FROM}"/>
      <stop offset="${BG_STOP}" stop-color="${BG_TO}"/>
    </radialGradient>`;
};
const defsBg = gradient(1);
const defsBgAdaptive = gradient(FOREGROUND_SCALE);

// Fond adaptatif Android en vector drawable (même dégradé que tilto_icon_background.svg).
function backgroundXml() {
  const g = bgAt(FOREGROUND_SCALE);
  const argb = (hex) => `#FF${hex.slice(1).toUpperCase()}`;
  return `<?xml version="1.0" encoding="utf-8"?>
<!-- Fond de l'icône adaptative : même dégradé que assets/icon/tilto_icon_background.svg
     (celui de la maquette, mis à l'échelle ${FOREGROUND_SCALE} comme le premier plan).
     Généré par tool/app_icon.cjs : ne pas modifier à la main. -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:aapt="http://schemas.android.com/aapt"
    android:width="${C}dp"
    android:height="${C}dp"
    android:viewportWidth="${C}"
    android:viewportHeight="${C}">
    <path android:pathData="M0,0h${C}v${C}h-${C}z">
        <aapt:attr name="android:fillColor">
            <gradient
                android:type="radial"
                android:centerX="${r(g.cx)}"
                android:centerY="${r(g.cy)}"
                android:gradientRadius="${r(g.r)}">
                <item android:offset="0" android:color="${argb(BG_FROM)}"/>
                <item android:offset="${BG_STOP}" android:color="${argb(BG_TO)}"/>
            </gradient>
        </aapt:attr>
    </path>
</vector>
`;
}
const head = `<svg xmlns="http://www.w3.org/2000/svg" width="${C}" height="${C}" viewBox="0 0 ${C} ${C}">`;
const note = '  <!-- Tilto, icône 2a « Raquette inclinée ». Généré par tool/app_icon.cjs : ne pas modifier à la main. -->';

const SVG = {
  background: `${head}\n${note}\n  <defs>\n${defsBgAdaptive}\n  </defs>\n  <rect width="${C}" height="${C}" fill="url(#bg)"/>\n</svg>\n`,
  // Premier plan adaptatif, à FOREGROUND_SCALE.
  foreground: `${head}\n${note}\n  <defs>\n${defsGlow}\n  </defs>\n${foregroundShapes({ scale: FOREGROUND_SCALE })}\n</svg>\n`,
  // Composition d'un lanceur (fond + premier plan adaptatif), pour la planche de contrôle.
  adaptive: `${head}\n  <defs>\n${defsBgAdaptive}\n${defsGlow}\n  </defs>\n  <rect width="${C}" height="${C}" fill="url(#bg)"/>\n${foregroundShapes({ scale: FOREGROUND_SCALE })}\n</svg>\n`,
  // Icône pleine : calque de la maquette tel quel.
  full: `${head}\n${note}\n  <defs>\n${defsBg}\n${defsGlow}\n  </defs>\n  <rect width="${C}" height="${C}" fill="url(#bg)"/>\n${foregroundShapes()}\n</svg>\n`,
};

// Silhouette monochrome (Android 13) : raquette et balle sans halo, à la même échelle.
function monochromeXml() {
  const s = FOREGROUND_SCALE;
  const x1 = r(p.x + p.h / 2);
  const x2 = r(p.x + p.w - p.h / 2);
  const rr = r(p.h / 2);
  return `<?xml version="1.0" encoding="utf-8"?>
<!-- Silhouette pour les icônes thématiques d'Android 13 : la raquette et la balle
     de assets/icon/tilto_icon_foreground.svg, sans halo. Le système choisit la teinte.
     Généré par tool/app_icon.cjs : ne pas modifier à la main. -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="${C}dp"
    android:height="${C}dp"
    android:viewportWidth="${C}"
    android:viewportHeight="${C}">
    <group
        android:pivotX="${C / 2}"
        android:pivotY="${C / 2}"
        android:scaleX="${s}"
        android:scaleY="${s}">
        <group
            android:pivotX="${r(p.cx)}"
            android:pivotY="${r(p.cy)}"
            android:rotation="${PADDLE.angle}">
            <path
                android:fillColor="#FFFFFFFF"
                android:pathData="M${x1},${r(p.y)}H${x2}A${rr},${rr} 0,0 1,${x2} ${r(p.y + p.h)}H${x1}A${rr},${rr} 0,0 1,${x1} ${r(p.y)}Z"/>
        </group>
        <path
            android:fillColor="#FFFFFFFF"
            android:pathData="M${r(b.cx)},${r(b.cy - b.r)}A${r(b.r)},${r(b.r)} 0,1 1,${r(b.cx)} ${r(b.cy + b.r)}A${r(b.r)},${r(b.r)} 0,1 1,${r(b.cx)} ${r(b.cy - b.r)}Z"/>
    </group>
</vector>
`;
}

// --- Sorties ------------------------------------------------------------------
const RES = path.join(ROOT, 'android', 'app', 'src', 'main', 'res');
const DENSITIES = { mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 };
const SQUIRCLE = '22%'; // coins du « Carré arrondi » de la maquette

function loadPlaywright() {
  const tries = [];
  if (process.env.PLAYWRIGHT_MODULE) tries.push(process.env.PLAYWRIGHT_MODULE);
  tries.push('playwright');
  const npx = path.join(os.homedir(), 'AppData', 'Local', 'npm-cache', '_npx');
  const npxUnix = path.join(os.homedir(), '.npm', '_npx');
  for (const dir of [npx, npxUnix]) {
    if (!fs.existsSync(dir)) continue;
    for (const h of fs.readdirSync(dir)) tries.push(path.join(dir, h, 'node_modules', 'playwright'));
  }
  for (const t of tries) {
    try { return require(t); } catch (_) { /* suivant */ }
  }
  throw new Error('Playwright introuvable : lancer « npx -y playwright@1.64.0 --version » puis relancer.');
}

// Chromium de Playwright ; à défaut (révision pas encore téléchargée), un
// Chromium déjà présent : CHROMIUM_PATH, puis les autres révisions de ms-playwright.
async function launch(chromium) {
  try {
    return await chromium.launch();
  } catch (e) {
    const candidates = [];
    if (process.env.CHROMIUM_PATH) candidates.push(process.env.CHROMIUM_PATH);
    const cache = path.join(os.homedir(), 'AppData', 'Local', 'ms-playwright');
    if (fs.existsSync(cache)) {
      for (const d of fs.readdirSync(cache).filter((n) => /^chromium-\d+$/.test(n)).sort().reverse()) {
        candidates.push(path.join(cache, d, 'chrome-win64', 'chrome.exe'), path.join(cache, d, 'chrome-win', 'chrome.exe'));
      }
    }
    const exe = candidates.find((c) => fs.existsSync(c));
    if (!exe) throw e;
    console.log(`Chromium de secours : ${exe}`);
    return chromium.launch({ executablePath: exe });
  }
}

// Page HTML d'un rendu : le SVG à la taille voulue, éventuellement découpé
// (masque) et recadré (zoom autour du centre, pour la zone visible d'Android).
function page(svg, size, { radius = '0', zoom = 1 } = {}) {
  const inner = size * zoom;
  const off = (size - inner) / 2;
  const src = `data:image/svg+xml;base64,${Buffer.from(svg).toString('base64')}`;
  return `<!doctype html><html><head><style>html,body{margin:0;background:transparent}
  .m{width:${size}px;height:${size}px;border-radius:${radius};overflow:hidden;position:relative}
  img{position:absolute;left:${off}px;top:${off}px;width:${inner}px;height:${inner}px;display:block}</style></head>
  <body><div class="m"><img src="${src}"></div></body></html>`;
}

async function render(browser, svg, size, file, opts = {}) {
  const ctx = await browser.newContext({ viewport: { width: size, height: size }, deviceScaleFactor: 1 });
  const pg = await ctx.newPage();
  await pg.setContent(page(svg, size, opts));
  await pg.waitForFunction(() => document.images[0].complete);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  await pg.screenshot({ path: file, omitBackground: !opts.opaque, clip: { x: 0, y: 0, width: size, height: size } });
  await ctx.close();
}

// ICO contenant des PNG (format accepté par tous les navigateurs actuels).
function writeIco(pngFiles, file) {
  const pngs = pngFiles.map((f) => ({ data: fs.readFileSync(f), size: pngSize(f) }));
  const header = Buffer.alloc(6);
  header.writeUInt16LE(0, 0); header.writeUInt16LE(1, 2); header.writeUInt16LE(pngs.length, 4);
  let offset = 6 + 16 * pngs.length;
  const dirs = pngs.map(({ data, size }) => {
    const d = Buffer.alloc(16);
    d.writeUInt8(size >= 256 ? 0 : size, 0); d.writeUInt8(size >= 256 ? 0 : size, 1);
    d.writeUInt16LE(1, 4); d.writeUInt16LE(32, 6);
    d.writeUInt32LE(data.length, 8); d.writeUInt32LE(offset, 12);
    offset += data.length;
    return d;
  });
  fs.writeFileSync(file, Buffer.concat([header, ...dirs, ...pngs.map((x) => x.data)]));
}
const pngSize = (f) => fs.readFileSync(f).readUInt32BE(16);

async function main() {
  const iconDir = path.join(ROOT, 'assets', 'icon');
  fs.mkdirSync(iconDir, { recursive: true });
  fs.writeFileSync(path.join(iconDir, 'tilto_icon_background.svg'), SVG.background);
  fs.writeFileSync(path.join(iconDir, 'tilto_icon_foreground.svg'), SVG.foreground);
  fs.writeFileSync(path.join(iconDir, 'tilto_icon.svg'), SVG.full);
  fs.writeFileSync(path.join(RES, 'drawable', 'ic_launcher_monochrome.xml'), monochromeXml());
  fs.writeFileSync(path.join(RES, 'drawable', 'ic_launcher_background.xml'), backgroundXml());

  const { chromium } = loadPlaywright();
  const browser = await launch(chromium);
  try {
    // Android : premier plan adaptatif (108 dp) et icônes classiques (48 dp, avant Android 8).
    for (const [d, k] of Object.entries(DENSITIES)) {
      await render(browser, SVG.foreground, 108 * k, path.join(RES, `drawable-${d}`, 'ic_launcher_foreground.png'));
      await render(browser, SVG.full, 48 * k, path.join(RES, `mipmap-${d}`, 'ic_launcher.png'), { radius: SQUIRCLE });
      await render(browser, SVG.full, 48 * k, path.join(RES, `mipmap-${d}`, 'ic_launcher_round.png'), { radius: '50%' });
    }
    // Play Store : carré plein, Google applique lui-même le masque.
    await render(browser, SVG.full, 512, path.join(iconDir, 'tilto_play_store_512.png'), { opaque: true });
    // iOS : carrés pleins, sans transparence (iOS arrondit lui-même).
    const ios = path.join(ROOT, 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset');
    for (const f of fs.readdirSync(ios).filter((n) => n.endsWith('.png'))) {
      const m = /Icon-App-([\d.]+)x[\d.]+@(\d)x\.png/.exec(f);
      if (!m) continue;
      await render(browser, SVG.full, Math.round(parseFloat(m[1]) * parseInt(m[2], 10)), path.join(ios, f), { opaque: true });
    }
    // Site : apple-touch-icon (carré plein) et favicon.ico (coins arrondis, comme favicon.svg).
    const img = path.join(ROOT, 'site', 'app', 'static', 'img');
    await render(browser, SVG.full, 180, path.join(img, 'apple-touch-icon.png'), { opaque: true });
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'tilto-ico-'));
    const icoParts = [];
    for (const s of [16, 32, 48]) {
      const f = path.join(tmp, `${s}.png`);
      await render(browser, SVG.full, s, f, { radius: SQUIRCLE });
      icoParts.push(f);
    }
    writeIco(icoParts, path.join(img, 'favicon.ico'));
    fs.rmSync(tmp, { recursive: true, force: true });

    // Planche de contrôle (facultatif) : node tool/app_icon.cjs --preview <dossier>
    const i = process.argv.indexOf('--preview');
    if (i > 0 && process.argv[i + 1]) {
      const out = path.resolve(process.argv[i + 1]);
      const masks = { rond: '50%', carre_arrondi: SQUIRCLE, goutte: '50% 50% 15% 50%' };
      await render(browser, SVG.full, 512, path.join(out, 'full_512.png'));
      await render(browser, SVG.full, 48, path.join(out, 'full_48.png'), { radius: SQUIRCLE });
      for (const [name, radius] of Object.entries(masks)) {
        // Calque entier dans le masque (convention de la maquette).
        await render(browser, SVG.full, 160, path.join(out, `maquette_${name}.png`), { radius });
        // Ce qu'affiche un lanceur Android : seuls les 72 dp centraux sur 108 sont visibles.
        await render(browser, SVG.adaptive, 160, path.join(out, `android_${name}.png`), { radius, zoom: 108 / 72 });
        await render(browser, SVG.adaptive, 48, path.join(out, `android_${name}_48.png`), { radius, zoom: 108 / 72 });
      }
    }
  } finally {
    await browser.close();
  }
  console.log('Icône Tilto générée.');
}

main().catch((e) => { console.error(e); process.exit(1); });
