from copy import deepcopy
from datetime import UTC, datetime
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import import_travel_requirements as importer


class ImportTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.source = Path(self.directory.name)
        self.commit = "a" * 40
        self.citation = {
            "url": "https://example.gov/visas",
            "name": "Immigration authority",
            "type": "government",
            "lastVerified": "2026-08-29",
        }
        self.record = {
            "id": "japan",
            "iso2": "JP",
            "names": {"common": "Japan"},
            "region": "east-asia",
            "visaPolicy": {
                "defaultSource": self.citation,
                "byPassport": {
                    "TW": {"requirement": "visa-free", "maxStayDays": 90,
                           "notes": "Limited to passport holders with a personal ID number.",
                           "source": self.citation, "validUntil": "2027-01-01"},
                },
            },
        }
        self.write("site.json", {"name": "TravelRequirements.info", "publisher": "AXG Sp. z o.o.",
                   "dataset": {"id": "travelrequirements-entry-requirements",
                               "version": "1.3.0", "datePublished": "2026-08-27",
                               "repository": importer.REPOSITORY,
                               "license": {"spdx": importer.LICENSE, "url": importer.LICENSE_URL}}})
        (self.source / "LICENSE").write_text("Attribution 4.0 International", encoding="utf-8")
        self.write("passports.json", {"passports": [
            {"code": "TW", "name": "Taiwan"}, {"code": "JP", "name": "Japan"},
        ]})
        self.write("regions.json", {"regions": [{"id": "east-asia", "name": "East Asia"}]})
        self.write("i18n/ar/passports.json", {"passports": {"JP": {"name": "اليابان"}}})
        self.write("destinations/japan.json", self.record)
        self.write("schema.json", {
            "$schema": "https://json-schema.org/draft/2020-12/schema",
            "properties": {"visaPolicy": {"properties": {"byPassport": {
                "additionalProperties": {"properties": {
                    "requirement": {"enum": importer.STATUSES},
                    "maxStayDays": {"type": "integer", "minimum": 1},
                }},
            }}}},
        })
        fake_git = patch.object(importer, "git", side_effect=self.git_output)
        fake_git.start()
        self.addCleanup(fake_git.stop)

    def git_output(self, source, action, *args):
        return {"status": "", "remote": importer.REPOSITORY + ".git", "rev-parse": self.commit}[action]

    def write(self, name, value):
        target = self.source / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(value), encoding="utf-8")

    def test_valid_import_preserves_provenance_conditions_and_missing_pairs(self):
        result = importer.normalize(self.source)
        importer.validate(result)
        metadata = result["metadata"]
        self.assertEqual(metadata["missingCount"], 1)
        self.assertEqual(metadata["commit"], self.commit)
        self.assertEqual(metadata["version"], "1.3.0")
        self.assertLessEqual(datetime.fromisoformat(metadata["importedAt"]), datetime.now(UTC))
        self.assertEqual(result["passports"][0], ["JP", "Japan", "اليابان"])
        self.assertNotIn("JP", result["entries"]["JP"])
        status, stay, note, source, level, conditional, until = result["entries"]["JP"]["TW"]
        self.assertEqual(result["statuses"][status], "visa-free")
        self.assertEqual(result["texts"][stay], "90 days")
        self.assertIn("personal ID number", result["texts"][note])
        self.assertEqual(result["sources"][source][:4], list(self.citation.values()))
        self.assertEqual(level, "row")
        self.assertTrue(conditional)
        self.assertEqual(until, "2027-01-01")

    def test_schema_violation_is_rejected(self):
        self.record["visaPolicy"]["byPassport"]["TW"]["maxStayDays"] = -1
        self.write("destinations/japan.json", self.record)
        with self.assertRaisesRegex(ValueError, "maxStayDays"):
            importer.normalize(self.source)

    def test_duplicate_pair_key_is_rejected(self):
        target = self.source / "destinations/japan.json"
        target.write_text('{"visaPolicy":{"byPassport":{"TW":{},"TW":{}}}}', encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "duplicate JSON key"):
            importer.normalize(self.source)

    def test_ordinary_visa_exemption_note_is_separate_from_an_alternative(self):
        row = self.record["visaPolicy"]["byPassport"]["TW"]
        row["notes"] = "Nationals are eligible for the visa exemption for up to 90 days."
        policy = self.record["visaPolicy"]
        policy["conditionalWaivers"] = [{"appliesTo": ["TW"], "text": "Additional route for residents."}]
        _, details, conditional, _ = importer.entry_details(row, policy, "TW", {"TW"})
        self.assertFalse(conditional)
        self.assertIn("Conditional alternative: Additional route for residents.", details)

    def test_failed_refresh_preserves_known_good_snapshot(self):
        asset = self.source / "snapshot.json"
        prior = importer.normalize(self.source)
        importer.write_atomically(asset, prior)
        bad = deepcopy(prior)
        bad["sources"][0][0] = "javascript:alert(1)"
        with self.assertRaisesRegex(ValueError, "Invalid web source URL"):
            importer.write_atomically(asset, bad)
        self.assertEqual(importer.read_json(asset), prior)
        with patch("sys.argv", ["import", "--output", str(asset), "--source", str(self.source)]):
            with patch.object(importer, "git", side_effect=OSError("upstream unavailable")):
                with self.assertRaisesRegex(OSError, "upstream unavailable"):
                    importer.main()
        self.assertEqual(importer.read_json(asset), prior)


if __name__ == "__main__":
    unittest.main()
