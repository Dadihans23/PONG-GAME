/*
 * Image de partage du site (Open Graph, Twitter, données structurées) :
 * store/play/feature-graphic.png, 1024 × 500 (image de présentation du Play Store).
 *
 * Même style que le site (site/app/static/css/site.css) : fond #0B0B10, Archivo,
 * « TILTO » en 900 espacé avec le halo rose du titre, et le terrain de la démo
 * de l'accueil (cadre #101016 bordé de #2A2A36, ligne médiane en pointillés,
 * raquette verte de l'ordinateur en haut, balle blanche, raquette bleue du
 * joueur en bas, avec leurs halos). Rien d'autre : ni icône, ni dégradé.
 *
 * Polices : les TTF Archivo de l'app (assets/fonts/), chargés en local.
 *
 * Usage, depuis la racine du projet (Playwright comme pour tool/app_icon.cjs) :
 *   npx -y playwright@1.64.0 --version   (met Playwright en cache une fois)
 *   node tool/og_image.cjs
 * Si Playwright est installé ailleurs : PLAYWRIGHT_MODULE=<dossier du paquet> node tool/og_image.cjs
 */
'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const { pathToFileURL } = require('url');

const ROOT = path.resolve(__dirname, '..');
const OUT = path.join(ROOT, 'store', 'play', 'feature-graphic.png');
const FONTS = path.join(ROOT, 'assets', 'fonts');
const W = 1024;
const H = 500;

// Jetons du thème sombre du site (site.css).
const C = {
  bg: '#0B0B10',
  card: '#101016',
  border: '#2A2A36',
  text: '#F2F2F5',
  muted: '#9E9EAB',
  faint: '#7E7E8E',
  courtLine: 'rgba(255, 255, 255, .12)',
  player: '#2196F3',
  enemy: '#4CAF50',
  ball: '#FFFFFF',
  glowTitle: 'rgba(233, 30, 99, .5)',
  glowBlue: '0 0 16px rgba(33, 150, 243, .6)',
  glowGreen: '0 0 16px rgba(76, 175, 80, .55)',
  glowBall: '0 0 12px rgba(255, 255, 255, .8), 0 0 32px rgba(255, 255, 255, .3)',
};

function font(weight, file) {
  const url = pathToFileURL(path.join(FONTS, file)).href;
  return `@font-face { font-family: "Archivo"; src: url("${url}"); font-weight: ${weight}; }`;
}

const html = `<!doctype html>
<html lang="fr"><head><meta charset="utf-8"><style>
${font(800, 'Archivo-ExtraBold.ttf')}
${font(900, 'Archivo-Black.ttf')}
* { margin: 0; padding: 0; box-sizing: border-box; }
html, body { width: ${W}px; height: ${H}px; background: ${C.bg}; overflow: hidden; }
body { font-family: "Archivo", sans-serif; color: ${C.text}; position: relative; }
.text { position: absolute; left: 72px; top: 0; bottom: 0; width: 560px;
  display: flex; flex-direction: column; justify-content: center; gap: 22px; }
.kicker { font-size: 18px; font-weight: 800; letter-spacing: .3em; color: ${C.muted}; }
h1 { font-size: 120px; font-weight: 900; line-height: .9; letter-spacing: .22em;
  text-shadow: 0 0 52px ${C.glowTitle}; }
.tagline { font-size: 34px; font-weight: 800; line-height: 1.18; max-width: 520px; }
.site { position: absolute; left: 72px; bottom: 40px; font-size: 18px; font-weight: 800;
  letter-spacing: .3em; color: ${C.faint}; }
/* Terrain vertical, comme la démo de l'accueil. */
.court { position: absolute; right: 80px; top: 40px; width: 250px; height: 420px;
  border: 2px solid ${C.border}; border-radius: 24px; background: ${C.card}; overflow: hidden; }
.line { position: absolute; left: 0; right: 0; top: 209px; height: 3px;
  background: repeating-linear-gradient(90deg, ${C.courtLine} 0 16px, transparent 16px 32px); }
.pad { position: absolute; width: 88px; height: 16px; border-radius: 8px; }
.pad--top { left: 124px; top: 40px; background: ${C.enemy}; box-shadow: ${C.glowGreen}; }
.pad--me { left: 50px; top: 364px; background: ${C.player}; box-shadow: ${C.glowBlue}; }
.ball { position: absolute; left: 124px; top: 266px; width: 24px; height: 24px; border-radius: 50%;
  background: ${C.ball}; box-shadow: ${C.glowBall}; }
.tag { position: absolute; right: 18px; font-size: 13px; font-weight: 800; letter-spacing: .25em; color: ${C.faint}; }
.tag--them { top: 16px; } .tag--me { bottom: 16px; }
</style></head><body>
<div class="text">
  <p class="kicker">JEU DE PONG · ANDROID</p>
  <h1>TILTO</h1>
  <p class="tagline">Le Pong qu’on joue en inclinant son téléphone</p>
</div>
<p class="site">TILTO.FUN</p>
<div class="court">
  <span class="tag tag--them">ORDINATEUR</span>
  <span class="tag tag--me">TOI</span>
  <i class="line"></i>
  <i class="pad pad--top"></i>
  <i class="ball"></i>
  <i class="pad pad--me"></i>
</div>
</body></html>`;

function loadPlaywright() {
  const tries = [];
  if (process.env.PLAYWRIGHT_MODULE) tries.push(process.env.PLAYWRIGHT_MODULE);
  tries.push('playwright');
  for (const dir of [path.join(os.homedir(), 'AppData', 'Local', 'npm-cache', '_npx'),
    path.join(os.homedir(), '.npm', '_npx')]) {
    if (!fs.existsSync(dir)) continue;
    for (const h of fs.readdirSync(dir)) tries.push(path.join(dir, h, 'node_modules', 'playwright'));
  }
  for (const t of tries) {
    try { return require(t); } catch (_) { /* suivant */ }
  }
  throw new Error('Playwright introuvable : lancer « npx -y playwright@1.64.0 --version » puis relancer.');
}

// Chromium de Playwright ; à défaut, un Chromium déjà présent (CHROMIUM_PATH,
// puis les révisions de ms-playwright), comme tool/app_icon.cjs.
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
    return chromium.launch({ executablePath: exe });
  }
}

(async () => {
  const { chromium } = loadPlaywright();
  const browser = await launch(chromium);
  const page = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
  // Fichier local (les polices sont chargées en file://).
  const tmp = path.join(os.tmpdir(), 'tilto-play-feature.html');
  fs.writeFileSync(tmp, html);
  await page.goto(pathToFileURL(tmp).href);
  await page.evaluate(() => document.fonts.ready);
  const missing = await page.evaluate(() => ['800', '900']
    .filter((w) => !document.fonts.check(`${w} 20px Archivo`)));
  if (missing.length) throw new Error(`Police Archivo non chargée : ${missing.join(', ')}`);
  await page.screenshot({ path: OUT, clip: { x: 0, y: 0, width: W, height: H } });
  await browser.close();
  fs.unlinkSync(tmp);
  console.log(`${path.relative(ROOT, OUT)} : ${W} × ${H}, ${(fs.statSync(OUT).size / 1024).toFixed(1)} Ko`);
})().catch((e) => { console.error(e); process.exit(1); });
