# Data methodology

## Source and license

TravelRequirements.info publishes current entry requirements for approximately 199 passports and 199 destinations. We selected it because it provides canonical destination records, a documented schema, verification dates and source provenance, and an open license that allows the app to bundle an adapted snapshot. [Dataset documentation](https://travelrequirements.info/en/data/) · [Upstream repository](https://github.com/travel-requirements/entry-requirements)

TravelRequirements.info — Entry Requirements Dataset, AXG Sp. z o.o., https://travelrequirements.info/data/ ([CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)). This project normalizes country identifiers and requirement categories and selects the fields needed for comparison. Keep the creator credit, source and license links, and a description of the changes when redistributing the adapted dataset.

## Requirement categories

| Category | How to read it |
| --- | --- |
| Visa-free | No visa required under the listed conditions. |
| Visa on arrival | Visa issued through an arrival process where eligible. |
| Electronic travel authorization | A distinct electronic authorization process, typically before departure. |
| Electronic visa | Visa obtained through an electronic application process. |
| Embassy visa required | Visa application through a diplomatic mission or its designated process. |
| Visa required | A visa is required. Check the source for the process. |
| Freedom of movement | Access under a free-movement arrangement with its own rules. |
| Travel permit | An applicable permit process. |
| Entry restriction | The dataset reports a ban or restriction. Read the supporting conditions. |
| Not confirmed | The source reports an unconfirmed rule or the snapshot lacks the applicable record. |

The bundled version 1.3.0 contains 199 passport records and 199 destination records. Its 39,601 passport–destination pairs include 199 domestic pairs and 3,060 unconfirmed entries. The included primary source verification dates span August 26 through October 22, 2026. Check **About the Data** for the details of the snapshot in use.

The summary excludes domestic destinations for all selected passports. Shared visa-free access counts destinations with confirmed visa-free access for every selected passport. Combined visa-free access counts destinations with confirmed visa-free access for at least one selected passport. Shared access can help groups plan. Combined access is most relevant when someone legally holds multiple passports. Read conditions and stay limits before using either count to plan travel.

A category difference requires two confirmed categories. An unknown record is counted separately and cannot create a visa-free difference. Eligibility warnings stay in the destination details, and a conditionally visa-free row stays out of the confirmed visa-free totals. Expired temporary rules are shown as unconfirmed. A visa-on-arrival process, an electronic authorization, and an electronic visa each have distinct eligibility and application rules. Check the destination detail for conditions and the available source.

## Evidence and dates

A passport-specific citation is tied to a particular matrix row. A destination-policy citation supports the general policy and can cover multiple passport rows. Source provenance describes who publishes the cited material, which may be the destination authority, a designated operator, an intergovernmental body, or a different government. Some sources were inaccessible at the provider's last check. [Provider methodology](https://travelrequirements.info/en/methodology/)

- **Dataset version and revision** identify the source snapshot.
- **Local import date** records when the snapshot was built.
- **Verification date** records when the provider last checked a fact against its cited source, where available.
- **Rule-change date** records a change to the requirement when the provider has that information.
- **Deployment date** records when an application build was published.

Coverage describes the available records. It does not guarantee a confirmed rule for every traveler or destination. The comparison covers the recorded passport and destination rules. Border authorities make final entry decisions. Confirm requirements with the issuing authority before travel.

## Current requirements and historical rankings

Historical Henley rankings used their own mobility scoring methodology. The old app could display a year-specific ranking next to current destination requirements. The current comparison uses the TravelRequirements.info snapshot, which represents current rules. The historical view is disabled because the app lacks a verified, reusable historical ranking series and year-specific destination rules.

The former Openness indicator described inbound access to a destination. The outbound comparison now shows the requirements that travelers face when they use each selected passport.

## Refresh the bundled data

Refreshes run monthly and can also be triggered manually from the default branch. The workflow proposes a pull request with a dataset diff. Enable GitHub Actions to create pull requests in repository settings to use the automated proposal step. Review coverage, category distributions, and any missing pairs before accepting the change. The production snapshot stays in place if retrieval or validation fails. Deployments continue to use the snapshot already checked in to the application.

To prepare a refresh locally, choose the upstream commit you intend to import and use a clean checkout.

```sh
git clone https://github.com/travel-requirements/entry-requirements.git ../entry-requirements
git -C ../entry-requirements checkout <upstream-commit>
python -m pip install -r scripts/data/requirements.txt
python scripts/data/import_travel_requirements.py --source ../entry-requirements --report dataset-diff.md
python scripts/data/import_travel_requirements.py --validate-only
flutter analyze
flutter test
```

The importer validates canonical destination records against the upstream schema. For the initial revision, narrowly scoped exceptions cover errors in upstream fields outside the imported comparison data. The importer validates the normalized snapshot before replacing the asset. Review the diff summary and changes to `assets/data/` in the same pull request. An import of a new upstream revision updates the local import timestamp. The source verification dates retain their upstream values. To roll back the data, restore the previous validated assets together and rerun validation.
