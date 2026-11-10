# Passport Comparison

Compare entry requirements for two to five passports. See where travelers share visa-free access, where requirements differ, and where the data is unconfirmed.

[Open Passport Comparison](https://leo0331.github.io/passportcomparison/)

## Compare and share

1. Search for and select two passports. Use **Add Passport** to compare up to five.
2. Read the summary, then search or filter by destination, region, or type of difference. Open a destination to see the requirements and supporting information for each passport.
3. Save a comparison preset on this device, share a comparison link, or export a full or differences-only PDF. Screenshot sharing is available on supported platforms.

A saved preset keeps your passport selections and uses the bundled dataset when reopened. A PDF records the comparison and dataset version used at the time of export.

## Data and methodology

The app reads a validated snapshot of the TravelRequirements.info Entry Requirements Dataset bundled with the Flutter app. Comparisons run locally after the asset loads. The snapshot includes current entry requirements and provenance. **About the Data** shows the version, update date, coverage, and verification information available in the snapshot.

TravelRequirements.info — Entry Requirements Dataset, AXG Sp. z o.o., https://travelrequirements.info/data/ ([CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)). The bundled dataset is adapted for this app.

Entry requirements can change. Check the destination's official sources before traveling.

- [Data methodology and updates](docs/data-methodology.md)
- [Architecture](docs/system-design-review.en.md)
- [Architecture in Traditional Chinese](docs/system-design-review.zh-TW.md)

## Development and deployment

Use Flutter stable with Dart 3.11 or later.

```sh
git clone https://github.com/LEO0331/passportcomparison.git
cd passportcomparison
flutter pub get
flutter run -d chrome
```

Run the local checks and build with the GitHub Pages base path.

```sh
flutter analyze
flutter test
flutter build web --release --base-href "/passportcomparison/" --no-web-resources-cdn
```

The build flag bundles Flutter web renderer resources with the app. For local release checks, serve `build/web/` at `/passportcomparison/` and include that subpath when opening a shared URL.

In **Settings → Pages → Build and deployment**, set **Source** to **GitHub Actions**. The **Deploy Flutter Web** workflow builds and publishes on pushes to `main`. To republish the current build, run the workflow manually from the Actions tab with `main` selected.

## Browser checks

The Playwright flow exercises the release build at the GitHub Pages base path. Install the test-only dependency in the ignored Flutter tooling directory, then install Chromium.

```sh
npm install --prefix .dart_tool/browser-checks --no-audit --no-fund playwright@1.65.0
npx --prefix .dart_tool/browser-checks playwright install chromium
```

Serve the build at the repository's Pages subpath. For example, from a POSIX shell:

```sh
mkdir -p .dart_tool/browser-checks/site/passportcomparison
cp -R build/web/. .dart_tool/browser-checks/site/passportcomparison/
python -m http.server 8787 --bind 127.0.0.1 --directory .dart_tool/browser-checks/site
```

Run the check in a second terminal. It blocks external requests and verifies the comparison at desktop and mobile widths.

```sh
node scripts/e2e/playwright_user_flow.cjs http://127.0.0.1:8787/passportcomparison/
```

## Rollback

To roll back a released change, revert its commit on a branch and review the revert through a pull request. For a data-only rollback, restore the last validated data assets together so their metadata and requirements stay in sync.
