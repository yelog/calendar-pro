import io
import json
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from datetime import datetime, timezone
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import sync_holidays  # noqa: E402


def make_document(year=2027, **overrides):
    document = {
        "year": year,
        "papers": ["https://www.gov.cn/zhengce/zhengceku/202611/content_7085102.htm"],
        "days": [
            {"name": "元旦", "date": f"{year}-01-01", "isOffDay": True},
            {"name": "春节", "date": f"{year}-01-31", "isOffDay": False},
        ],
    }
    document.update(overrides)
    return document


class ConvertDocumentTests(unittest.TestCase):
    def test_converts_off_days_and_adjustment_workdays(self):
        records = sync_holidays.convert_document(make_document(), 2027)

        self.assertEqual(records[0]["kind"], "statutoryHoliday")
        self.assertEqual(records[0]["holidaySetID"], "statutory-holidays")
        self.assertNotIn("sourceScheduleYear", records[0])
        self.assertEqual(records[1]["kind"], "workingAdjustmentDay")
        self.assertEqual(records[1]["name"], "春节调休上班")
        self.assertTrue(records[1]["isAdjustmentWorkday"])
        self.assertNotIn("sourceScheduleYear", records[1])

    def test_rejects_duplicate_dates(self):
        document = make_document(
            days=[
                {"name": "元旦", "date": "2027-01-01", "isOffDay": True},
                {"name": "元旦", "date": "2027-01-01", "isOffDay": True},
            ]
        )

        with self.assertRaises(sync_holidays.HolidaySyncError):
            sync_holidays.convert_document(document, 2027)

    def test_splits_cross_year_dates_by_actual_year(self):
        document = make_document(
            days=[
                {"name": "元旦", "date": "2026-12-31", "isOffDay": True},
                {"name": "元旦", "date": "2027-01-01", "isOffDay": True},
                {"name": "春节", "date": "2027-01-31", "isOffDay": False},
            ]
        )

        grouped = sync_holidays.group_records_by_year(
            sync_holidays.convert_document(document, 2027)
        )

        self.assertEqual(set(grouped), {2026, 2027})
        self.assertEqual(grouped[2026][0]["date"], "2026-12-31")
        self.assertEqual(grouped[2026][0]["sourceScheduleYear"], 2027)
        self.assertNotIn("sourceScheduleYear", grouped[2027][0])
        self.assertEqual(len(grouped[2027]), 2)

    def test_rejects_source_without_dates_in_its_schedule_year(self):
        document = make_document(
            days=[
                {"name": "元旦", "date": "2026-12-31", "isOffDay": True},
            ]
        )

        with self.assertRaises(sync_holidays.HolidaySyncError):
            sync_holidays.convert_document(document, 2027)

    def test_rejects_sources_without_official_paper(self):
        document = make_document(papers=[])

        with self.assertRaises(sync_holidays.HolidaySyncError):
            sync_holidays.convert_document(document, 2027)

    def test_rejects_lookalike_official_paper_hosts(self):
        document = make_document(
            papers=["https://gov.cn.example.com/not-official"]
        )

        with self.assertRaises(sync_holidays.HolidaySyncError):
            sync_holidays.convert_document(document, 2027)

    def test_merge_replaces_revised_records_and_preserves_other_sources(self):
        existing = [
            {
                "date": "2027-01-01",
                "name": "旧元旦",
                "kind": "statutoryHoliday",
                "holidaySetID": "statutory-holidays",
                "sourceScheduleYear": 2027,
            },
            {
                "date": "2027-01-02",
                "name": "跨年保留",
                "kind": "statutoryHoliday",
                "holidaySetID": "statutory-holidays",
                "sourceScheduleYear": 2028,
            },
        ]
        revised = [
            {
                "date": "2027-01-01",
                "name": "新元旦",
                "kind": "statutoryHoliday",
                "holidaySetID": "statutory-holidays",
                "sourceScheduleYear": 2027,
            }
        ]

        merged = sync_holidays.merge_existing_records(
            existing,
            revised,
            {2027},
            2027,
        )

        self.assertEqual([record["name"] for record in merged], ["新元旦", "跨年保留"])
        self.assertNotIn("sourceScheduleYear", merged[0])
        self.assertEqual(merged[1]["sourceScheduleYear"], 2028)

    def test_merge_removes_stale_records_from_refreshed_source(self):
        existing = [
            {
                "date": "2027-01-01",
                "name": "旧记录",
                "kind": "statutoryHoliday",
                "holidaySetID": "statutory-holidays",
                "sourceScheduleYear": 2027,
            },
            {
                "date": "2027-01-02",
                "name": "保留记录",
                "kind": "statutoryHoliday",
                "holidaySetID": "statutory-holidays",
                "sourceScheduleYear": 2028,
            },
        ]

        merged = sync_holidays.merge_existing_records(existing, [], {2027}, 2027)

        self.assertEqual([record["name"] for record in merged], ["保留记录"])
        self.assertEqual(merged[0]["sourceScheduleYear"], 2028)

    def test_merge_preserves_same_year_records_when_adjacent_source_is_refreshed(self):
        existing = [
            {
                "date": "2027-01-01",
                "name": "同年记录",
                "kind": "statutoryHoliday",
                "holidaySetID": "statutory-holidays",
            }
        ]

        merged = sync_holidays.merge_existing_records(existing, [], {2028}, 2027)

        self.assertEqual([record["name"] for record in merged], ["同年记录"])
        self.assertNotIn("sourceScheduleYear", merged[0])

    def test_merge_rejects_cross_source_date_conflicts(self):
        existing = [
            {
                "date": "2027-12-31",
                "name": "旧元旦",
                "kind": "statutoryHoliday",
                "holidaySetID": "statutory-holidays",
            }
        ]
        new_records = [
            {
                "date": "2027-12-31",
                "name": "新元旦",
                "kind": "statutoryHoliday",
                "holidaySetID": "statutory-holidays",
                "sourceScheduleYear": 2028,
            }
        ]

        with self.assertRaisesRegex(sync_holidays.HolidaySyncError, "provided by both"):
            sync_holidays.merge_existing_records(
                existing,
                new_records,
                {2028},
                2027,
            )

    def test_merge_rejects_conflicts_between_refreshed_sources(self):
        records = [
            {
                "date": "2027-12-31",
                "name": "2027 元旦",
                "kind": "statutoryHoliday",
                "holidaySetID": "statutory-holidays",
            },
            {
                "date": "2027-12-31",
                "name": "2028 元旦",
                "kind": "statutoryHoliday",
                "holidaySetID": "statutory-holidays",
                "sourceScheduleYear": 2028,
            },
        ]

        with self.assertRaisesRegex(sync_holidays.HolidaySyncError, "provided by both"):
            sync_holidays.merge_existing_records(records, records, {2027, 2028}, 2027)

    def test_planned_target_years_skips_adjacent_only_payloads(self):
        planned, skipped = sync_holidays.planned_target_years(
            {
                2027: [{"date": "2027-12-31"}],
                2028: [{"date": "2028-01-01"}],
            },
            existing_payload_years=set(),
            published_source_years={2028},
        )

        self.assertEqual(planned, {2028})
        self.assertEqual(skipped, [2027])

    def test_planned_target_years_keeps_existing_complete_payload(self):
        planned, skipped = sync_holidays.planned_target_years(
            {
                2027: [{"date": "2027-12-31"}],
                2028: [{"date": "2028-01-01"}],
            },
            existing_payload_years={2027},
            published_source_years={2028},
        )

        self.assertEqual(planned, {2027, 2028})
        self.assertEqual(skipped, [])

    def test_next_revision_uses_monotonic_timestamp_version(self):
        previous = datetime(2026, 11, 11, 8, 6, 21, tzinfo=timezone.utc)
        manifest = {"generatedAt": previous.isoformat().replace("+00:00", "Z")}

        version, generated_at = sync_holidays.next_revision(previous, manifest)

        self.assertEqual(version, "2026.11.11.160622")
        self.assertEqual(generated_at, "2026-11-11T08:06:22Z")

    def test_serializes_records_in_calendarpro_shape(self):
        text = sync_holidays.serialize_records(
            [
                {
                    "date": "2027-01-01",
                    "name": "元旦",
                    "kind": "statutoryHoliday",
                    "holidaySetID": "statutory-holidays",
                }
            ]
        )

        self.assertEqual(
            text,
            '[\n  { "date": "2027-01-01", "name": "元旦", "kind": "statutoryHoliday", "holidaySetID": "statutory-holidays" }\n]\n',
        )


class SyncIntegrationTests(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary_directory.name)
        self.feed_dir = self.root / "feed" / "holidays"
        self.bundle_dir = self.root / "CalendarPro" / "Resources" / "Holidays" / "mainland-cn"
        self.manifest_path = self.feed_dir / "manifest.json"
        self.now = datetime(2026, 11, 11, 8, 0, 0, tzinfo=timezone.utc)

    def tearDown(self):
        self.temporary_directory.cleanup()

    def write_records(self, year, records):
        self.feed_dir.mkdir(parents=True, exist_ok=True)
        self.bundle_dir.mkdir(parents=True, exist_ok=True)
        text = sync_holidays.serialize_records(records)
        (self.feed_dir / f"mainland-cn-{year}.json").write_text(text, encoding="utf-8")
        (self.bundle_dir / f"mainland-cn-{year}.json").write_text(text, encoding="utf-8")

    def read_records(self, year):
        return json.loads(
            (self.feed_dir / f"mainland-cn-{year}.json").read_text(encoding="utf-8")
        )

    def sync(self, years, documents, *, dry_run=False):
        def fetcher(url):
            for year, document in documents.items():
                if url.endswith(f"/{year}.json"):
                    return document
            return None

        return sync_holidays.sync(
            years,
            dry_run=dry_run,
            feed_dir=self.feed_dir,
            bundle_dir=self.bundle_dir,
            manifest_path=self.manifest_path,
            fetcher=fetcher,
            now=self.now,
        )

    def test_sync_does_not_publish_adjacent_source_as_partial_year(self):
        document = make_document(
            year=2028,
            days=[
                {"name": "元旦", "date": "2027-12-31", "isOffDay": True},
                {"name": "元旦", "date": "2028-01-01", "isOffDay": True},
            ],
        )

        with redirect_stdout(io.StringIO()):
            exit_code = self.sync([2028], {2028: document})

        self.assertEqual(exit_code, 0)
        self.assertFalse((self.feed_dir / "mainland-cn-2027.json").exists())
        self.assertFalse((self.bundle_dir / "mainland-cn-2027.json").exists())
        self.assertEqual(len(self.read_records(2028)), 1)

        manifest = json.loads(self.manifest_path.read_text(encoding="utf-8"))
        self.assertEqual(
            manifest["payloads"],
            [{"regionID": "mainland-cn", "year": 2028, "path": "mainland-cn-2028.json"}],
        )
        self.assertRegex(manifest["version"], r"^2026\.11\.11\.\d{6}$")

    def test_sync_merges_adjacent_records_into_existing_complete_year(self):
        self.write_records(
            2027,
            [
                {
                    "date": "2027-01-01",
                    "name": "元旦",
                    "kind": "statutoryHoliday",
                    "holidaySetID": "statutory-holidays",
                }
            ],
        )
        document = make_document(
            year=2028,
            days=[
                {"name": "元旦", "date": "2027-12-31", "isOffDay": True},
                {"name": "元旦", "date": "2028-01-01", "isOffDay": True},
            ],
        )

        with redirect_stdout(io.StringIO()):
            self.sync([2028], {2028: document})

        records_2027 = self.read_records(2027)
        self.assertEqual(
            [record["date"] for record in records_2027],
            ["2027-01-01", "2027-12-31"],
        )
        self.assertNotIn("sourceScheduleYear", records_2027[0])
        self.assertEqual(records_2027[1]["sourceScheduleYear"], 2028)

    def test_sync_fails_without_writing_on_cross_source_conflict(self):
        existing = [
            {
                "date": "2027-12-31",
                "name": "旧元旦",
                "kind": "statutoryHoliday",
                "holidaySetID": "statutory-holidays",
            }
        ]
        self.write_records(2027, existing)
        original_2027 = (self.feed_dir / "mainland-cn-2027.json").read_text(encoding="utf-8")
        document = make_document(
            year=2028,
            days=[
                {"name": "新元旦", "date": "2027-12-31", "isOffDay": True},
                {"name": "元旦", "date": "2028-01-01", "isOffDay": True},
            ],
        )

        with self.assertRaises(sync_holidays.HolidaySyncError):
            with redirect_stdout(io.StringIO()):
                self.sync([2028], {2028: document})

        self.assertEqual(
            (self.feed_dir / "mainland-cn-2027.json").read_text(encoding="utf-8"),
            original_2027,
        )
        self.assertFalse((self.feed_dir / "mainland-cn-2028.json").exists())
        self.assertFalse(self.manifest_path.exists())

    def test_second_sync_is_idempotent(self):
        document = make_document(year=2027)

        with redirect_stdout(io.StringIO()):
            self.sync([2027], {2027: document})
        payload_before = (self.feed_dir / "mainland-cn-2027.json").read_text(encoding="utf-8")
        manifest_before = self.manifest_path.read_text(encoding="utf-8")

        output = io.StringIO()
        with redirect_stdout(output):
            self.sync([2027], {2027: document})

        self.assertIn("already up to date", output.getvalue())
        self.assertEqual(
            (self.feed_dir / "mainland-cn-2027.json").read_text(encoding="utf-8"),
            payload_before,
        )
        self.assertEqual(self.manifest_path.read_text(encoding="utf-8"), manifest_before)

    def test_dry_run_reports_manifest_when_payload_content_changes(self):
        self.write_records(
            2027,
            [
                {
                    "date": "2027-01-01",
                    "name": "旧元旦",
                    "kind": "statutoryHoliday",
                    "holidaySetID": "statutory-holidays",
                }
            ],
        )
        document = make_document(
            year=2027,
            days=[
                {"name": "新元旦", "date": "2027-01-01", "isOffDay": True},
            ],
        )

        output = io.StringIO()
        with redirect_stdout(output):
            self.sync([2027], {2027: document}, dry_run=True)

        self.assertIn("would update", output.getvalue())
        self.assertIn("manifest.json", output.getvalue())
        self.assertEqual(self.read_records(2027)[0]["name"], "旧元旦")


if __name__ == "__main__":
    unittest.main()
