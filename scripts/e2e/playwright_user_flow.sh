#!/usr/bin/env bash
set -euo pipefail

command -v npx >/dev/null 2>&1 || {
  echo "npx is required. Install Node.js/npm first." >&2
  exit 1
}

CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
PWCLI="$CODEX_HOME/skills/playwright/scripts/playwright_cli.sh"
if [[ ! -x "$PWCLI" ]]; then
  echo "Playwright wrapper not found: $PWCLI" >&2
  exit 1
fi

APP_URL="${1:-http://127.0.0.1:8787}"
SESSION="passport-e2e-flow"
TITLE="E2E Brazil vs Belgium"

export CODEX_HOME
export PWCLI
export PLAYWRIGHT_CLI_SESSION="$SESSION"

run() {
  "$PWCLI" "$@" --raw >/dev/null
}

run_js() {
  "$PWCLI" run-code "$1" --raw >/dev/null
}

# 1) Open app
run open "$APP_URL"

# 2) Enable Flutter semantics/a11y (required for stable role-based interactions)
run_js "async (page) => {
  const gate = page.getByLabel('Enable accessibility');
  if (await gate.count()) {
    await gate.first().click({ force: true });
  }
}"

# 3) Start 2-passport flow
run_js "async (page) => {
  await page.getByRole('button', { name: '2' }).click();
  await page.getByRole('button', { name: 'Start' }).click();
}"

# 4) Pick passports
run_js "async (page) => {
  await page.getByRole('button', { name: 'Passport 1' }).click();
  await page.getByRole('menuitem', { name: 'Brazil' }).click();
  await page.getByRole('button', { name: 'Passport 2' }).click();
  await page.getByRole('menuitem', { name: 'Belgium' }).click();
}"

# 5) Compare and validate result actions unlocked
run_js "async (page) => {
  await page.getByRole('button', { name: 'Compare' }).click();
  await page.getByText('Rank: 15').first().waitFor({ timeout: 15000 });
  await page.getByRole('button', { name: 'Details' }).waitFor({ timeout: 15000 });
  await page.getByRole('button', { name: 'Add to Favorite' }).waitFor({ timeout: 15000 });
}"

# 6) Open Details and run search interaction
run_js "async (page) => {
  await page.getByRole('button', { name: 'Details' }).click();
  const search = page.getByRole('textbox', { name: 'Search destination...' });
  await search.fill('Japan');
  await page.getByText('Japan').first().waitFor({ timeout: 10000 });
}"

# 7) Save favorite
run_js "async (page) => {
  await page.getByRole('button', { name: 'Add to Favorite' }).click();
  const title = page.getByRole('textbox', { name: 'Comparison Title' });
  await title.fill('$TITLE');
  await page.getByRole('button', { name: 'Save' }).click();
}"

# 8) Verify favorite exists in Favorites screen
run_js "async (page) => {
  await page.getByRole('button', { name: 'Open navigation menu' }).click();
  await page.getByRole('button', { name: 'Favorites' }).click();
  await page.getByText('$TITLE').first().waitFor({ timeout: 15000 });
}"

mkdir -p output/playwright
"$PWCLI" screenshot --raw > output/playwright/last-run.txt || true

echo "E2E flow passed: $APP_URL"
