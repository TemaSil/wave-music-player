/**
 * Records docs/demo.gif — a short run through the app, in motion.
 *
 * Same setup as tool/capture_screenshots.mjs: it drives the demo-mode web
 * build in a headless browser, records the session, then trims and encodes the
 * result with ffmpeg. The trim point is measured at runtime so the page load
 * never ends up in the GIF.
 *
 *   flutter build web --release --no-web-resources-cdn \
 *     --dart-define=WAVE_DEMO=true --output=build/web-demo
 *   node tool/record_demo.mjs
 *
 * Environment overrides:
 *   BUILD_DIR / OUT_DIR / CHROMIUM / PORT  as in capture_screenshots.mjs
 *   FFMPEG    ffmpeg executable            (default `ffmpeg` on PATH)
 *   GIF_WIDTH output width in px           (default 300)
 *   GIF_FPS   output frame rate            (default 12)
 */
import { execFileSync } from 'node:child_process';
import { createServer } from 'node:http';
import { createReadStream, existsSync, mkdirSync, rmSync, statSync } from 'node:fs';
import { extname, join, normalize } from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { chromium } = require('playwright');

const BUILD_DIR = process.env.BUILD_DIR ?? 'build/web-demo';
const OUT_DIR = process.env.OUT_DIR ?? 'docs';
const PORT = Number(process.env.PORT ?? 8098);
const FFMPEG = process.env.FFMPEG ?? 'ffmpeg';
const GIF_WIDTH = Number(process.env.GIF_WIDTH ?? 264);
const GIF_FPS = Number(process.env.GIF_FPS ?? 10);
const VIEWPORT = { width: 390, height: 844 };

const MIME = {
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.json': 'application/json',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.wav': 'audio/wav',
  '.otf': 'font/otf',
  '.ttf': 'font/ttf',
  '.symbols': 'text/plain',
};

function serve(root, port) {
  const server = createServer((req, res) => {
    const path = decodeURIComponent(new URL(req.url, 'http://x').pathname);
    let file = join(root, normalize(path).replace(/^(\.\.[/\\])+/, ''));
    if (!existsSync(file) || statSync(file).isDirectory()) file = join(root, 'index.html');
    res.writeHead(200, { 'Content-Type': MIME[extname(file)] ?? 'application/octet-stream' });
    createReadStream(file).pipe(res);
  });
  return new Promise((resolve) => server.listen(port, '127.0.0.1', () => resolve(server)));
}

async function main() {
  if (!existsSync(BUILD_DIR)) {
    throw new Error(`No web build at ${BUILD_DIR} — see the header of this file.`);
  }
  mkdirSync(OUT_DIR, { recursive: true });
  const videoDir = join(OUT_DIR, '.video');
  rmSync(videoDir, { recursive: true, force: true });

  const server = await serve(BUILD_DIR, PORT);
  const browser = await chromium.launch({
    executablePath: process.env.CHROMIUM || undefined,
    args: [
      '--no-sandbox',
      '--use-gl=swiftshader',
      '--enable-unsafe-swiftshader',
      // Headless Chromium otherwise refuses to start the preview stream, and
      // the capture ends up showing a paused player.
      '--autoplay-policy=no-user-gesture-required',
    ],
  });

  const startedAt = Date.now();
  const context = await browser.newContext({
    viewport: VIEWPORT,
    recordVideo: { dir: videoDir, size: VIEWPORT },
  });
  const page = await context.newPage();

  await page.goto(`http://127.0.0.1:${PORT}/`, { waitUntil: 'load', timeout: 60_000 });
  await page.locator('[aria-label^="Aurora Drift"]').first().waitFor({ timeout: 60_000 });
  await page.waitForTimeout(2500);

  // Everything before this point is loading; the GIF starts here.
  const trimFrom = (Date.now() - startedAt) / 1000;
  const wait = (ms) => page.waitForTimeout(ms);
  const centre = VIEWPORT.width / 2;

  // Swipe the hero carousel to show the parallax.
  await page.mouse.move(centre + 110, 330);
  await page.mouse.down();
  for (let x = 110; x >= -110; x -= 28) {
    await page.mouse.move(centre + x, 330);
  }
  await page.mouse.up();
  await wait(900);

  // Play whichever card the swipe landed on. Only the centred card exposes its
  // play button to the semantics tree, so match on the prefix.
  await page.locator('[aria-label^="Play "]').last().click();
  await wait(1600);

  // Scroll: the tab bar spring-collapses and the play pill slides inline
  // between the tab glyph and the search capsule — the iOS 26 behaviour.
  await page.mouse.move(centre, 560);
  await page.mouse.wheel(0, 460);
  await wait(1600);
  await page.mouse.wheel(0, -460);
  await wait(1200);

  // Expand into the full player.
  await page.locator('[aria-label^="Now playing:"]').last().click();
  await wait(2200);

  // Scrub, so the liquid seek bar swells under the thumb.
  const seekY = VIEWPORT.height - 148;
  await page.mouse.move(40, seekY);
  await page.mouse.down();
  for (let x = 40; x <= 300; x += 32) {
    await page.mouse.move(x, seekY);
  }
  await wait(400);
  await page.mouse.up();
  await wait(700);

  // Queue sheet, then back out to the shell.
  await page.mouse.click(VIEWPORT.width - 34, VIEWPORT.height - 40);
  await wait(1500);
  await page.keyboard.press('Escape');
  await wait(700);
  await page.goBack();
  await wait(1100);

  // Appearance settings: the live-colour skin repaints the whole app.
  await page.mouse.click(VIEWPORT.width - 34, 22);
  await wait(1400);
  await page.mouse.click(centre, 490);
  await wait(1600);
  await page.keyboard.press('Escape');
  await wait(2000);

  const duration = (Date.now() - startedAt) / 1000 - trimFrom;
  const video = page.video();
  await context.close();
  const source = await video.path();
  await browser.close();
  server.close();

  const gif = join(OUT_DIR, 'demo.gif');
  // Two-pass palette generation: a global 256-colour palette plus dithering
  // keeps the gradients from banding into mush.
  const filters =
    `fps=${GIF_FPS},scale=${GIF_WIDTH}:-1:flags=lanczos,` +
    `split[a][b];[a]palettegen=max_colors=192[p];[b][p]paletteuse=dither=bayer:bayer_scale=3`;
  execFileSync(
    FFMPEG,
    ['-y', '-hide_banner', '-loglevel', 'error',
     '-ss', trimFrom.toFixed(2), '-t', duration.toFixed(2), '-i', source,
     '-filter_complex', filters, '-loop', '0', gif],
    { stdio: 'inherit' },
  );
  rmSync(videoDir, { recursive: true, force: true });

  const size = (statSync(gif).size / 1024 / 1024).toFixed(2);
  console.log(`\n✓ ${gif} — ${duration.toFixed(1)}s, ${size} MB`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
