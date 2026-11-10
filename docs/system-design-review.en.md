# Passport Comparison architecture

The Flutter app runs on static hosting. Entry requirements are imported and validated before release, then loaded from bundled assets when the app starts. The comparison flow uses the bundled snapshot, so provider downtime cannot interrupt an already published comparison. The browser needs access to the deployed app and its assets on first load.

## Data flow

1. The importer reads a traceable TravelRequirements.info revision and validates the upstream data and normalized output. The application assets include comparison data and metadata. Large upstream audit and change-log files stay outside the application.
2. The dataset repository loads the bundled assets into typed passport, destination, requirement, and metadata records. A missing record resolves to **Not confirmed**. If the bundled dataset cannot load, the interface shows an unavailable state.
3. A pure comparison computes summaries and destination rows from two to five distinct passports. The same normalized categories feed the summary, filters, details, and PDF report.
4. SharedPreferences stores local comparison presets. Legacy entries can be read from the existing preferences key. Saved codes are resolved against the bundled passport registry when reopened.
5. Shared URLs carry passport codes. The app validates codes against the loaded snapshot before restoring a selection. The URL stays within the GitHub Pages base path.
6. PDF generation uses the loaded comparison and dataset metadata. Full reports include all eligible destination rows. Differences-only reports use the comparison's category-difference predicate. Both report formats label unknown requirements and include the source and dataset version.

See [data methodology](data-methodology.md) for category definitions, evidence levels, licensing, and release checks.
