const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');

const root = path.resolve(__dirname, '../..');
const { chromium } = require(require.resolve('playwright', {
  paths: [path.join(root, '.dart_tool/browser-checks')],
}));

const appUrl = new URL(
  process.argv[2] ?? 'http://127.0.0.1:8787/passportcomparison/',
);

async function enableSemantics(page) {
  const gate = page.getByLabel('Enable accessibility', { exact: true });
  const ready = page.getByRole('button', { name: /^Passport A/ });
  const state = await Promise.race([
    gate.waitFor({ state: 'attached' }).then(() => 'gate'),
    ready.waitFor().then(() => 'ready'),
  ]);
  if (state === 'gate') await gate.dispatchEvent('click');
  await ready.waitFor();
}

async function selectPassport(page, slot, query, country, keyboard = false) {
  const button = page.getByRole('button', { name: `Passport ${slot}`, exact: true });
  if (keyboard) {
    await button.focus();
    await page.keyboard.press('Enter');
  } else {
    await button.click();
  }
  const search = page.getByRole('textbox', { name: 'Search passports' });
  await search.fill(query);
  await page.getByRole('button', { name: country, exact: true })
    .or(page.getByLabel(country, { exact: true })).first().click();
}

async function main() {
  const browser = await chromium.launch();
  const providerRequests = [];
  let page;
  try {
    const context = await browser.newContext({
      viewport: { width: 1280, height: 900 },
      locale: 'en-US',
      serviceWorkers: 'block',
      permissions: ['clipboard-read', 'clipboard-write'],
    });
    await context.route('**/*', async route => {
      const request = new URL(route.request().url());
      if (request.origin === appUrl.origin) return route.continue();
      if (/(^|\.)(henleypassportindex\.com|henleyglobal\.com|travelrequirements\.info)$/
        .test(request.hostname)) providerRequests.push(request.href);
      await route.abort();
    });
    page = await context.newPage();
    page.setDefaultTimeout(25_000);
    await page.goto(appUrl.href);
    await enableSemantics(page);

    await page.getByRole('button', { name: 'Passport B', exact: true }).waitFor();
    assert.equal(await page.getByRole('button', { name: 'Passport C', exact: true }).count(), 0);
    const about = page.getByRole('button', { name: /About the data/i })
      .or(page.getByLabel(/About the data/i)).first();
    await about.click();
    await page.getByText(/Bundled snapshot imported on/)
      .or(page.getByLabel(/Bundled snapshot imported on/)).first().waitFor();
    await about.click();

    await selectPassport(page, 'A', 'Taiw', 'Taiwan', true);
    await selectPassport(page, 'B', 'Japa', 'Japan');
    await page.getByRole('heading', { name: 'Travel access summary' }).waitFor();

    await page.getByRole('heading', { name: 'Destination comparison' }).waitFor();
    await page.getByRole('textbox', { name: 'Search destinations' }).waitFor();
    await page.getByRole('button', { name: 'Afghanistan', exact: true }).click();
    await page.getByRole('button', { name: 'Close', exact: true }).click();
    await page.getByRole('button', { name: 'Copy comparison link' }).click();
    await page.waitForFunction(async () => (await navigator.clipboard.readText()).includes('passports='));
    const sharedUrl = new URL(await page.evaluate(() => navigator.clipboard.readText()));
    assert.equal(sharedUrl.origin, appUrl.origin);
    assert.equal(sharedUrl.pathname, appUrl.pathname);
    assert.equal(sharedUrl.searchParams.get('passports'), 'TW,JP');

    for (const [label, filename] of [
      ['Full comparison PDF', 'passport-comparison.pdf'],
      ['Differences-only PDF', 'passport-differences.pdf'],
    ]) {
      await page.getByRole('button', { name: 'Export PDF' }).click();
      const download = page.waitForEvent('download');
      await page.getByText(label, { exact: true })
        .or(page.getByLabel(label, { exact: true })).first().click();
      const file = await download;
      assert.equal(file.suggestedFilename(), filename);
      const bytes = await fs.readFile(await file.path());
      assert.equal(bytes.subarray(0, 5).toString(), '%PDF-');
    }

    const presetTitle = 'E2E Taiwan and Japan';
    await page.getByRole('button', { name: 'Save preset' }).click();
    await page.getByRole('textbox', { name: 'Comparison title' }).fill(presetTitle);
    await page.getByRole('button', { name: 'Save', exact: true }).click();
    await page.getByText('Comparison preset saved.', { exact: true }).last().waitFor();
    await page.reload();
    await enableSemantics(page);
    await page.getByRole('button', { name: 'Saved presets' }).click();
    await page.getByText(presetTitle, { exact: true })
      .or(page.getByLabel(new RegExp(presetTitle))).first().click();
    await page.getByRole('button', { name: 'Passport A: Taiwan' }).waitFor();
    await page.getByRole('button', { name: 'Passport B: Japan' }).waitFor();

    await page.setViewportSize({ width: 390, height: 844 });
    await page.goto(sharedUrl.href);
    await enableSemantics(page);
    await page.getByRole('button', { name: 'Passport A: Taiwan' }).waitFor();
    await page.getByRole('button', { name: 'Passport B: Japan' }).waitFor();
    await page.getByRole('heading', { name: 'Travel access summary' }).waitFor();
    assert.deepEqual(providerRequests, []);
    console.log(`Browser flow passed at desktop and mobile widths: ${appUrl.href}`);
  } catch (error) {
    if (page) console.error((await page.locator('body').ariaSnapshot()).slice(0, 4000));
    throw error;
  } finally {
    await browser.close();
  }
}

main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
