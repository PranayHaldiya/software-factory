// Screenshot each route at desktop size, and optionally record one video walking through them.
// Usage: node evidence.mjs <base-url> <comma-separated-routes> <label> <output-dir> [--video]
// Writes <label>-<route>.png per route, and <label>.webm with --video.
import { chromium } from 'playwright';
import { mkdir, readdir, rename, rm } from 'node:fs/promises';
import path from 'node:path';

const [baseUrl, routesArg, label, outDir, flag] = process.argv.slice(2);
const routes = routesArg.split(',').filter(Boolean);
const video = flag === '--video';
const size = { width: 1280, height: 800 };
const videoDir = path.join(outDir, `${label}-video-tmp`);

const slug = (route) =>
  route === '/' ? 'home' : route.replace(/^\/|\/$/g, '').replace(/[^a-z0-9]+/gi, '-').toLowerCase();

await mkdir(outDir, { recursive: true });
const browser = await chromium.launch();
const context = await browser.newContext({
  viewport: size,
  ...(video ? { recordVideo: { dir: videoDir, size } } : {}),
});
const page = await context.newPage();

for (const route of routes) {
  await page.goto(new URL(route, baseUrl).href, { waitUntil: 'networkidle' });
  await page.waitForTimeout(500);
  await page.screenshot({ path: path.join(outDir, `${label}-${slug(route)}.png`), fullPage: true });
  if (video) {
    await page.mouse.wheel(0, 1200);
    await page.waitForTimeout(1200);
    await page.mouse.wheel(0, -1200);
    await page.waitForTimeout(800);
  }
}

await context.close();
await browser.close();

if (video) {
  const [file] = await readdir(videoDir);
  if (file) await rename(path.join(videoDir, file), path.join(outDir, `${label}.webm`));
  await rm(videoDir, { recursive: true, force: true });
}
