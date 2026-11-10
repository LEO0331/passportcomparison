"""Validate and normalize a clean checkout of TravelRequirements.info."""

import argparse
from collections import Counter
from datetime import UTC, date, datetime
import json
from pathlib import Path
import re
import subprocess
from tempfile import NamedTemporaryFile
from urllib.parse import urlsplit

from jsonschema import Draft202012Validator, FormatChecker
import pycountry


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "assets/data/passport_requirements.json"
SOURCE = "https://travelrequirements.info/data/"
REPOSITORY = "https://github.com/travel-requirements/entry-requirements"
LICENSE = "CC-BY-4.0"
LICENSE_URL = "https://creativecommons.org/licenses/by/4.0/"
ATTRIBUTION = (
    "TravelRequirements.info — Entry Requirements Dataset, AXG Sp. z o.o., "
    f"{SOURCE} (CC BY 4.0)"
)
STATUSES = [
    "visa-free", "visa-on-arrival", "eta", "evisa", "embassy-visa",
    "visa-required", "freedom-of-movement", "travel-permit", "banned",
    "unconfirmed",
]
STATUS_INDEX = {status: index for index, status in enumerate(STATUSES)}
ISO_CODES = {country.alpha_2 for country in pycountry.countries} | {"XK"}
VISA_NEEDED = {"embassy-visa", "visa-required", "evisa"}
# This published revision predates corrections to the schema for these fields.
# None of the exceptions changes any primary source, rule, or date we import.
SCHEMA_EXCEPTION_COMMIT = "a566cc4c396f5da50c9235ba48cac860f2fff525"
ELIGIBILITY_WARNING = re.compile(
    r"\b(?:biometric passport|electronic passport|e-passport|personal id|"
    r"identity (?:card )?number|household registration|non-biometric passport|"
    r"limited to passport holders|(?:only|limited to) (?:holders|through|at|if|when)|"
    r"holders of (?:a )?(?:valid .+ visa|.+ residence permit)|"
    r"if entering|entering and departing through|must have a return ticket|"
    r"requires? a (?:confirmed|return|onward) ticket|"
    r"confirmed (?:hotel reservation|return or onward ticket)|"
    r"permanent residents of|British citizens only)\b",
    re.IGNORECASE,
)


def check(condition, message):
    if not condition:
        raise ValueError(message)


def read_json(path):
    def object_with_unique_keys(pairs):
        result = dict(pairs)
        check(len(result) == len(pairs), f"{path.name}: duplicate JSON key")
        return result

    return json.loads(path.read_text(encoding="utf-8"),
                      object_pairs_hook=object_with_unique_keys)


def git(source, *args):
    return subprocess.check_output(
        ["git", "-C", str(source), *args], encoding="utf-8",
    ).strip()


def checked_url(value):
    parsed = urlsplit(value)
    check(parsed.scheme in {"http", "https"} and parsed.hostname
          and parsed.username is None and parsed.password is None
          and not any(char.isspace() or ord(char) < 32 for char in value),
          f"Invalid web source URL: {value!r}")
    return value


def checked_date(value):
    check(re.fullmatch(r"\d{4}-\d{2}-\d{2}", value), f"Invalid date: {value}")
    return date.fromisoformat(value)


def text_or_none(value):
    return value.strip() or None if value is not None else None


def named_row(code, name, localized, *fields):
    check(code in ISO_CODES, f"Unsupported country code {code}")
    check(isinstance(name, str) and name.strip(), f"Missing country name for {code}")
    return [code, name, *fields, localized] if localized else [code, name, *fields]


def unique_rows(rows, label):
    by_code = {row[0]: row for row in rows}
    check(len(by_code) == len(rows), f"Duplicate {label} code")
    return by_code


def stay_details(rule, policy):
    stay = rule.get("stayWindow")
    default = policy.get("defaultStayWindow")
    days = rule.get("maxStayDays")
    if stay is None and days is not None and default and default["allowanceDays"] == days:
        stay = default
    if stay is not None:
        return stay["text"]
    return f"{days} {'day' if days == 1 else 'days'}" if days is not None else None


def entry_details(rule, policy, code, passport_codes):
    status = rule["requirement"]
    note = text_or_none(rule.get("notes"))
    conditional = bool(note and ELIGIBILITY_WARNING.search(note))
    notes = [note] if note else []
    if rule.get("extendableDays") is not None:
        notes.append(f"Reported extension allowance: {rule['extendableDays']} days.")
    for waiver in policy.get("conditionalWaivers", []):
        applies = waiver["appliesTo"]
        if isinstance(applies, list):
            check(set(applies) <= passport_codes, "Conditional waiver uses unknown passport code")
            applicable = code in applies
        else:
            applicable = status in VISA_NEEDED
        if applicable and waiver["text"].strip():
            notes.append(f"Conditional alternative: {waiver['text'].strip()}")
    until = rule.get("validUntil")
    if until:
        checked_date(until)
        notes.append(f"Upstream lists this rule as valid through {until}.")
    return stay_details(rule, policy), "\n\n".join(notes) or None, conditional, until


def load_upstream(source):
    check(not git(source, "status", "--porcelain", "--untracked-files=all"),
          "Upstream checkout must be clean to establish commit provenance")
    remote = git(source, "remote", "get-url", "origin").removesuffix(".git")
    check(remote == REPOSITORY, f"Unexpected canonical repository: {remote}")
    commit = git(source, "rev-parse", "HEAD")
    site = read_json(source / "site.json")
    dataset = site["dataset"]
    check(site["name"] == "TravelRequirements.info"
          and site["publisher"] == "AXG Sp. z o.o."
          and dataset["id"] == "travelrequirements-entry-requirements"
          and dataset["repository"] == REPOSITORY
          and dataset["license"]["spdx"] == LICENSE
          and dataset["license"]["url"] == LICENSE_URL
          and "Attribution 4.0 International" in (source / "LICENSE").read_text(encoding="utf-8"),
          "Unexpected upstream identity, publisher or license")
    checked_date(dataset["datePublished"])
    schema = read_json(source / "schema.json")
    check(schema["$schema"] == Draft202012Validator.META_SCHEMA["$id"],
          "Unexpected upstream schema draft")
    upstream_statuses = schema["properties"]["visaPolicy"]["properties"][
        "byPassport"]["additionalProperties"]["properties"]["requirement"]["enum"]
    check(set(upstream_statuses) == set(STATUSES), "Upstream requirement categories changed")
    Draft202012Validator.check_schema(schema)
    validator = Draft202012Validator(schema, format_checker=FormatChecker())
    return commit, dataset, validator


def known_schema_exception(commit, filename, error):
    if commit != SCHEMA_EXCEPTION_COMMIT:
        return False
    location = error.json_path
    issue = error.validator
    message = error.message
    if filename == "botswana.json":
        return (issue == "additionalProperties" and "'archiveUrl'" in message
                and re.fullmatch(
                    r"\$\.(?:visaPolicy\.byPassport\.[A-Z]{2}|visaTypes\[\d+\])\.source\.alsoStatedOn\[\d+\]",
                    location,
                ))
    if filename == "cuba.json":
        return issue == "anyOf" and location == "$.countryFacts.payments"
    if filename in {"dominican-republic.json", "ghana.json", "north-macedonia.json"}:
        return (issue == "additionalProperties" and "'type'" in message
                and re.fullmatch(r"\$\.visaTypes\[\d+\]\.source\.alsoStatedOn\[\d+\]", location))
    if filename in {"eswatini.json", "somalia.json"}:
        return issue == "required" and location == "$.meta" and message == "'modules' is a required property"
    if filename == "norway.json":
        return (issue == "format" and location.startswith(
                    ("$.entryRequirements.overstay.", "$.textQuotes['entryRequirements.overstay']"))
                and error.instance.startswith("https://lovdata.no/"))
    return (filename == "united-states.json" and issue == "additionalProperties"
            and location == "$.visaTypes[0]" and "'feeNotes'" in message)


def normalize(source):
    commit, dataset, validator = load_upstream(source)
    overlays = source / "i18n/ar"
    arabic_passports = read_json(overlays / "passports.json")["passports"]
    passports = unique_rows([
        named_row(row["code"], row["name"], arabic_passports.get(row["code"], {}).get("name"))
        for row in read_json(source / "passports.json")["passports"]
    ], "passport")
    passport_codes = set(passports)
    region_rows = read_json(source / "regions.json")["regions"]
    regions = {row["id"]: row["name"] for row in region_rows}
    check(len(regions) == len(region_rows), "Duplicate region identifier")
    destinations = []
    entries = {}
    sources = {}
    texts = {}
    for path in sorted((source / "destinations").glob("*.json")):
        record = read_json(path)
        for error in validator.iter_errors(record):
            check(known_schema_exception(commit, path.name, error),
                  f"{path.name}: {error.json_path} {error.message}")
        code = record["iso2"]
        check(record["id"] == path.stem and code not in entries,
              f"Duplicate or misidentified destination {path.name}")
        overlay = overlays / "destinations" / path.name
        localized = read_json(overlay)["names"].get("common") if overlay.is_file() else None
        destinations.append(named_row(code, record["names"]["common"], localized,
                                      regions[record["region"]]))
        policy = record["visaPolicy"]
        rows = policy["byPassport"]
        check(set(rows) <= passport_codes, f"{code}: invalid passport reference")
        entries[code] = {}
        for passport_code, rule in sorted(rows.items()):
            status = rule["requirement"]
            row_source = rule.get("source")
            citation = row_source or policy["defaultSource"]
            checked_date(citation["lastVerified"])
            source_key = (
                checked_url(citation["url"]), citation["name"], citation["type"],
                citation["lastVerified"], "intergovernmental" if citation["type"] == "igo" else None,
            )
            source_index = sources.setdefault(source_key, len(sources))
            stay, conditions, conditional, until = entry_details(rule, policy, passport_code, passport_codes)
            entries[code][passport_code] = [
                STATUS_INDEX[status],
                texts.setdefault(stay, len(texts)) if stay is not None else None,
                texts.setdefault(conditions, len(texts)) if conditions is not None else None,
                source_index,
                "row" if row_source else "policy", conditional, until,
            ]
    entry_count = sum(map(len, entries.values()))
    verification_dates = [source_key[3] for source_key in sources]
    return {
        "format": 1,
        "metadata": {
            "version": dataset["version"],
            "commit": commit,
            "importedAt": datetime.now(UTC).isoformat(timespec="seconds"),
            "oldestVerified": min(verification_dates),
            "newestVerified": max(verification_dates),
            "passportCount": len(passports),
            "destinationCount": len(destinations),
            "entryCount": entry_count,
            "missingCount": len(passports) * len(destinations) - entry_count,
            "attribution": ATTRIBUTION,
            "license": LICENSE,
            "licenseUrl": LICENSE_URL,
            "sourceUrl": SOURCE,
        },
        "passports": sorted(passports.values()),
        "destinations": sorted(destinations),
        "statuses": STATUSES,
        "sources": [list(source_key) for source_key in sources],
        "texts": list(texts),
        "entries": dict(sorted(entries.items())),
    }


def validate(snapshot):
    metadata = snapshot["metadata"]
    check(snapshot["format"] == 1 and snapshot["statuses"] == STATUSES, "Unknown snapshot format")
    check(metadata["license"] == LICENSE and metadata["licenseUrl"] == LICENSE_URL
          and metadata["attribution"] == ATTRIBUTION and metadata["sourceUrl"] == SOURCE,
          "Snapshot licensing metadata is invalid")
    check(re.fullmatch(r"[0-9a-f]{40}", metadata["commit"])
          and re.fullmatch(r"\d+\.\d+\.\d+(?:[-+][\w.-]+)?", metadata["version"]),
          "Snapshot revision metadata is invalid")
    imported = datetime.fromisoformat(metadata["importedAt"])
    check(imported.utcoffset() == UTC.utcoffset(imported), "Import date must use UTC")
    passports = unique_rows(snapshot["passports"], "passport")
    destinations = unique_rows(snapshot["destinations"], "destination")
    check(set(passports) <= ISO_CODES and set(destinations) <= ISO_CODES, "Invalid country code")
    check(all(len(row) in {2, 3} and all(isinstance(v, str) and v.strip() for v in row)
              for row in passports.values()), "Invalid passport registry")
    check(all(len(row) in {3, 4} and all(isinstance(v, str) and v.strip() for v in row)
              for row in destinations.values()), "Invalid destination registry")
    check(len(passports) == metadata["passportCount"] >= 2
          and len(destinations) == metadata["destinationCount"] > 0, "Invalid country counts")
    verification_dates = []
    sources = snapshot["sources"]
    for url, name, source_type, verified, provenance in sources:
        checked_url(url)
        check(isinstance(name, str) and name.strip() and source_type in {
            "government", "igo", "official-airline-db"}, "Invalid source details")
        check(provenance is None or provenance in {
            "first-party", "third-party-government", "designated-operator", "intergovernmental",
        }, "Invalid source provenance")
        verification_dates.append(checked_date(verified))
    check(verification_dates and len({tuple(row) for row in sources}) == len(sources),
          "Missing or duplicate sources")
    check(min(verification_dates) == checked_date(metadata["oldestVerified"])
          and max(verification_dates) == checked_date(metadata["newestVerified"]) <= imported.date(),
          "Invalid source verification range")
    entries = snapshot["entries"]
    texts = snapshot.get("texts")
    if texts is not None:
        check(all(isinstance(value, str) and value.strip() for value in texts)
              and len(set(texts)) == len(texts), "Invalid detail text registry")

    def valid_text_reference(value):
        if value is None:
            return True
        if texts is None:
            return isinstance(value, str) and value.strip()
        return type(value) is int and 0 <= value < len(texts)

    check(set(entries) == set(destinations), "Destination coverage mismatch")
    actual_count = 0
    for code, rows in entries.items():
        check(set(rows) <= set(passports), f"{code}: unknown passport references")
        for status, stay, conditions, source, level, conditional, until in rows.values():
            check(type(status) is int and 0 <= status < len(STATUSES),
                  "Unrecognized requirement category")
            check(type(source) is int and 0 <= source < len(sources) and level in {"row", "policy"},
                  "Invalid source reference")
            check(valid_text_reference(stay) and valid_text_reference(conditions)
                  and type(conditional) is bool,
                  "Invalid requirement details")
            if until is not None:
                checked_date(until)
            actual_count += 1
    check(actual_count == metadata["entryCount"] and actual_count > 0
          and len(passports) * len(destinations) - actual_count == metadata["missingCount"],
          "Invalid requirement counts")


def report(previous, candidate):
    metadata = candidate["metadata"]
    lines = [
        "# TravelRequirements.info snapshot",
        "",
        f"- Version: {metadata['version']} (`{metadata['commit']}`)",
        f"- Imported: {metadata['importedAt']}",
        f"- Source verification: {metadata['oldestVerified']} through {metadata['newestVerified']}",
        "",
        "| Metric | Previous | Candidate |",
        "| --- | ---: | ---: |",
    ]
    old_metadata = previous["metadata"] if previous else {}
    for key in ("passportCount", "destinationCount", "entryCount", "missingCount"):
        lines.append(f"| {key} | {old_metadata.get(key, '—')} | {metadata[key]} |")

    def distribution(snapshot):
        return Counter(snapshot["statuses"][row[0]]
                       for rows in snapshot["entries"].values() for row in rows.values())

    old_counts = distribution(previous) if previous else {}
    new_counts = distribution(candidate)
    for status in STATUSES:
        lines.append(f"| {status} | {old_counts.get(status, '—')} | {new_counts[status]} |")
    if previous:
        old_pairs = {(dest, code): row[0] for dest, rows in previous["entries"].items()
                     for code, row in rows.items()}
        new_pairs = {(dest, code): row[0] for dest, rows in candidate["entries"].items()
                     for code, row in rows.items()}
        changed = sum(old_pairs[pair] != new_pairs[pair] for pair in old_pairs.keys() & new_pairs.keys())
        lines += ["", f"Category changes: {changed}. Added pairs: {len(new_pairs.keys() - old_pairs.keys())}. "
                  f"Removed pairs: {len(old_pairs.keys() - new_pairs.keys())}."]
        coverage_changed = any(metadata[key] != old_metadata[key] for key in (
            "passportCount", "destinationCount", "missingCount",
        )) or old_pairs.keys() != new_pairs.keys()
        distribution_changed = any(
            abs(new_counts[key] - old_counts[key]) >= max(10, old_counts[key] * 0.1)
            for key in STATUSES
        )
        if coverage_changed or distribution_changed:
            lines += ["", "**Review flag:** Coverage or category distribution shifted. Verify upstream changes before merging."]
    return "\n".join(lines) + "\n"


def write_atomically(path, snapshot):
    path.parent.mkdir(parents=True, exist_ok=True)
    with NamedTemporaryFile(mode="w", encoding="utf-8", newline="\n",
                            dir=path.parent, delete=False) as handle:
        temporary = Path(handle.name)
        json.dump(snapshot, handle, ensure_ascii=False, separators=(",", ":"))
        handle.write("\n")
    try:
        validate(read_json(temporary))
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, help="Clean checkout of the canonical upstream repository")
    parser.add_argument("--output", type=Path, default=OUTPUT)
    parser.add_argument("--report", type=Path, help="Write the comparison with the existing output as Markdown")
    parser.add_argument("--validate-only", action="store_true", help="Validate the existing output")
    args = parser.parse_args()
    if args.validate_only:
        validate(read_json(args.output))
        print(f"Validated {args.output}")
        return
    if args.source is None:
        parser.error("--source is required unless --validate-only is set")
    previous = read_json(args.output) if args.output.is_file() else None
    if previous:
        validate(previous)
    candidate = normalize(args.source)
    validate(candidate)
    if previous and previous["metadata"]["commit"] == candidate["metadata"]["commit"]:
        earlier_import = {**candidate["metadata"], "importedAt": previous["metadata"]["importedAt"]}
        if previous == {**candidate, "metadata": earlier_import}:
            candidate = previous
    summary = report(previous, candidate)
    print(summary)
    if args.report:
        args.report.write_text(summary, encoding="utf-8")
    if previous != candidate:
        write_atomically(args.output, candidate)


if __name__ == "__main__":
    main()
