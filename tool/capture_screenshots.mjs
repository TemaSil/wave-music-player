/**
 * Captures the README screenshots and the demo animation from the web build.
 *
 * Runs the app in demo mode (`--dart-define=WAVE_DEMO=true`), which serves the
 * bundled offline catalogue, so the output is reproducible and needs no
 * network and no music API.
 *
 *   flutter build web --release --no-web-resources-cdn \
 *     --dart-define=WAVE_DEMO=true --output=build/web-demo
 *   npx playwright@latest install chromium      # if you have no browser yet
 *   node tool/capture_screenshots.mjs
 *
 * Environment overrides:
 *   BUILD_DIR   web build to serve          (default build/web-demo)
 *   OUT_DIR     where PNGs are written      (default docs/screenshots)
 *   CHROMIUM    Chromium executable path    (default: Playwright's own)
 *   PORT        local server port           (default 8099)
 */
import { createServer } from 'node:http';
import { createReadStream, existsSync, mkdirSync, statSync } from 'node:fs';
import { extname, join, normalize } from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { chromium } = require('playwright');

const BUILD_DIR = process.env.BUILD_DIR ?? 'build/web-demo';
const OUT_DIR = process.env.OUT_DIR ?? 'docs/screenshots';
const PORT = Number(process.env.PORT ?? 8099);
const VIEWPORT = { width: 390, height: 844 };

const MIME = {
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.mjs': 'text/javascript',
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
    res.writeHead(200, {
      'Content-Type': MIME[extname(file)] ?? 'application/octet-stream',
      // The engine needs these for its multi-threaded rendering paths.
      'Cross-Origin-Opener-Policy': 'same-origin',
      'Cross-Origin-Embedder-Policy': 'require-corp',
    });
    createReadStream(file).pipe(res);
  });
  return new Promise((resolve) => server.listen(port, '127.0.0.1', () => resolve(server)));
}

const settle = (page, ms = 1400) => page.waitForTimeout(ms);

async function shoot(page, name) {
  const file = join(OUT_DIR, `${name}.png`);
  await page.screenshot({ path: file });
  console.log('✓', file);
}

/** Semantic nodes are duplicated by the engine; the last one is the live one. */
function node(page, label) {
  return page.locator(`[aria-label="${label}"]`).last();
}

async function main() {
  if (!existsSync(BUILD_DIR)) {
    throw new Error(`No web build at ${BUILD_DIR} — see the header of this file.`);
  }
  mkdirSync(OUT_DIR, { recursive: true });

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

  const context = await browser.newContext({
    viewport: VIEWPORT,
    deviceScaleFactor: 2,
  });
  const page = await context.newPage();

  await page.goto(`http://127.0.0.1:${PORT}/`, { waitUntil: 'load', timeout: 60_000 });
  // Wait for the first list row to prove the catalogue resolved.
  await page.locator('[aria-label^="Aurora Drift"]').first().waitFor({ timeout: 60_000 });
  await settle(page, 2500);

  await shoot(page, '01-discover');

  // Appearance settings, where the live-colour skin lives. Captured first,
  // because the header fades out after 30px of scroll. Clicked by position:
  // the scaffold merges the header's semantics into its parent, so the button
  // has no addressable node of its own.
  await page.mouse.click(VIEWPORT.width - 34, 22);
  await settle(page, 2200);
  await shoot(page, '06-settings');
  await page.keyboard.press('Escape');
  await settle(page, 1400);

  // Start playback from the hero carousel and expand into the full player.
  await node(page, 'Play Aurora Drift').click();
  await settle(page, 2500);
  await page.locator('[aria-label^="Now playing:"]').last().click();
  await settle(page, 6000);
  await shoot(page, '03-now-playing');

  // Queue sheet, then back to the player and out to the shell.
  await page.mouse.click(VIEWPORT.width - 34, VIEWPORT.height - 40);
  await settle(page, 1800);
  await shoot(page, '04-queue-sheet');
  await page.keyboard.press('Escape');
  await settle(page);
  await page.goBack();
  await settle(page, 1600);

  // Back on the shell, with the play pill settled and playing.
  await shoot(page, '02-mini-player');

  // Scrolling collapses the tab bar and pulls the pill inline — the iOS 26
  // behaviour this redesign is built around.
  await page.mouse.move(VIEWPORT.width / 2, 500);
  await page.mouse.wheel(0, 420);
  await settle(page, 1800);
  await shoot(page, '05-collapsed-bar');
  await page.mouse.wheel(0, -420);
  await settle(page, 1200);

  // Like a few rows so the library has something in it.
  for (let i = 0; i < 3; i++) {
    await page.locator('[aria-label="Add to library"]').first().click();
    await page.waitForTimeout(700);
  }

  // Library.
  await node(page, 'Медиатека').click();
  await settle(page, 2000);
  await shoot(page, '07-library');

  await context.close();
  await browser.close();
  server.close();
  console.log('\nDone. For the animated demo, run tool/record_demo.mjs.');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
