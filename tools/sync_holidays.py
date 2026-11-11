#!/usr/bin/env python3

"""Sync mainland China statutory holidays into CalendarPro's holiday feed."""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import tempfile
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urlparse
from urllib.request import Request, urlopen


REPO_ROOT = Path(__file__).resolve().parents[1]
FEED_DIR = REPO_ROOT / "feed" / "holidays"
BUNDLE_DIR = REPO_ROOT / "CalendarPro" / "Resources" / "Holidays" / "mainland-cn"
MANIFEST_PATH = FEED_DIR / "manifest.json"

SOURCE_TEMPLATE = "https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/{year}.json"
CHINA_TIME_ZONE = timezone(timedelta(hours=8))
PAYLOAD_FILE_PATTERN = re.compile(r"^(?P<region>.+)-(?P<year>\d{4})\.json$")
MAINLAND_PAYLOAD_PATTERN = re.compile(r"^mainland-cn-(?P<year>\d{4})\.json$")
SOURCE_SCHEDULE_YEAR_KEY = "sourceScheduleYear"


class HolidaySyncError(RuntimeError):
    pass


def parse_args() -> argparse.Namespace:
    today = datetime.now(CHINA_TIME_ZONE).date()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--years",
        nargs="+",
        type=int,
        default=[today.year, today.year + 1],
        help="Years to synchronize (default: current and next year in China time).",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Validate and report changes without writing files.",
    )
    return parser.parse_args()


def fetch_json(url: str) -> object | None:
    request = Request(
        url,
        headers={
            "Accept": "application/json",
            "User-Agent": "CalendarProHolidaySync/1.0",
        },
    )
    try:
        with urlopen(request, timeout=30) as response:
            return json.load(response)
    except HTTPError as error:
        if error.code == 404:
            return None
        raise HolidaySyncError(f"HTTP {error.code} while fetching {url}") from error
    except (URLError, json.JSONDecodeError, UnicodeDecodeError) as error:
        raise HolidaySyncError(f"Unable to fetch {url}: {error}") from error


def is_official_paper(url: str) -> bool:
    try:
        parsed = urlparse(url)
    except ValueError:
        return False

    hostname = (parsed.hostname or "").lower()
    return (
        parsed.scheme in {"http", "https"}
        and (hostname == "gov.cn" or hostname.endswith(".gov.cn"))
    )


def convert_document(document: object, year: int) -> list[dict[str, object]]:
    if not isinstance(document, dict):
        raise HolidaySyncError(f"{year}: expected a JSON object")
    if document.get("year") != year:
        raise HolidaySyncError(f"{year}: source year does not match")

    papers = document.get("papers")
    if (
        not isinstance(papers, list)
        or not papers
        or not all(isinstance(paper, str) and is_official_paper(paper) for paper in papers)
    ):
        raise HolidaySyncError(f"{year}: source must cite an official gov.cn notice")

    days = document.get("days")
    if not isinstance(days, list) or not days:
        raise HolidaySyncError(f"{year}: source contains no holiday days")

    records: list[dict[str, object]] = []
    for raw_day in days:
        if not isinstance(raw_day, dict):
            raise HolidaySyncError(f"{year}: invalid day record")

        name = raw_day.get("name")
        raw_date = raw_day.get("date")
        is_off_day = raw_day.get("isOffDay")
        if not isinstance(name, str) or not name.strip():
            raise HolidaySyncError(f"{year}: holiday name is empty")
        if not isinstance(raw_date, str):
            raise HolidaySyncError(f"{year}: holiday date is missing")
        if not isinstance(is_off_day, bool):
            raise HolidaySyncError(f"{year}-{raw_date}: isOffDay must be a boolean")

        try:
            parsed_date = date.fromisoformat(raw_date)
        except ValueError as error:
            raise HolidaySyncError(f"{year}: invalid date {raw_date}") from error

        if is_off_day:
            record: dict[str, object] = {
                "date": raw_date,
                "name": name,
                "kind": "statutoryHoliday",
                "holidaySetID": "statutory-holidays",
            }
        else:
            record = {
                "date": raw_date,
                "name": f"{name}调休上班",
                "kind": "workingAdjustmentDay",
                "holidaySetID": "adjustment-workdays",
                "isAdjustmentWorkday": True,
            }

        if parsed_date.year != year:
            record[SOURCE_SCHEDULE_YEAR_KEY] = year
        records.append(record)

    if not any(record["kind"] == "statutoryHoliday" for record in records):
        raise HolidaySyncError(f"{year}: source contains no off days")
    if not any(record_date(record).year == year for record in records):
        raise HolidaySyncError(f"{year}: source contains no dates in its schedule year")

    validate_records(records)
    return sort_records(records)


def record_date(record: dict[str, object]) -> date:
    value = record.get("date")
    if not isinstance(value, str):
        raise HolidaySyncError("holiday date is missing")
    try:
        return date.fromisoformat(value)
    except ValueError as error:
        raise HolidaySyncError(f"invalid date {value}") from error


def source_schedule_year(record: dict[str, object], target_year: int) -> int:
    value = record.get(SOURCE_SCHEDULE_YEAR_KEY, target_year)
    if isinstance(value, bool) or not isinstance(value, int):
        raise HolidaySyncError(f"{target_year}: sourceScheduleYear must be an integer")
    return value


def validate_record(record: object, target_year: int | None = None) -> dict[str, object]:
    if not isinstance(record, dict):
        raise HolidaySyncError("invalid holiday record")

    normalized = dict(record)
    raw_date = normalized.get("date")
    name = normalized.get("name")
    kind = normalized.get("kind")
    holiday_set_id = normalized.get("holidaySetID")
    is_adjustment = normalized.get("isAdjustmentWorkday", False)

    if not isinstance(raw_date, str):
        raise HolidaySyncError("holiday date is missing")
    parsed_date = record_date(normalized)
    if target_year is not None and parsed_date.year != target_year:
        raise HolidaySyncError(
            f"{target_year}: record {raw_date} belongs to {parsed_date.year}"
        )
    if not isinstance(name, str) or not name.strip():
        raise HolidaySyncError(f"{raw_date}: holiday name is empty")
    if kind not in {"statutoryHoliday", "workingAdjustmentDay"}:
        raise HolidaySyncError(f"{raw_date}: unsupported holiday kind {kind}")
    if not isinstance(holiday_set_id, str) or not holiday_set_id:
        raise HolidaySyncError(f"{raw_date}: holidaySetID is empty")
    if not isinstance(is_adjustment, bool):
        raise HolidaySyncError(f"{raw_date}: isAdjustmentWorkday must be a boolean")

    if kind == "workingAdjustmentDay":
        if holiday_set_id != "adjustment-workdays" or not is_adjustment:
            raise HolidaySyncError(f"{raw_date}: invalid adjustment-workday semantics")
    elif holiday_set_id != "statutory-holidays" or is_adjustment:
        raise HolidaySyncError(f"{raw_date}: invalid statutory-holiday semantics")

    source_schedule_year(normalized, parsed_date.year)
    return normalized


def validate_records(records: list[dict[str, object]], target_year: int | None = None) -> None:
    seen_dates: set[str] = set()
    seen_identities: set[tuple[str, str, str]] = set()

    for raw_record in records:
        record = validate_record(raw_record, target_year)
        raw_date = str(record["date"])
        if raw_date in seen_dates:
            raise HolidaySyncError(f"duplicate holiday date {raw_date}")
        seen_dates.add(raw_date)

        identity = (
            raw_date,
            str(record["kind"]),
            str(record["holidaySetID"]),
        )
        if identity in seen_identities:
            raise HolidaySyncError(f"duplicate holiday record {raw_date}")
        seen_identities.add(identity)


def normalize_source_metadata(
    record: dict[str, object],
    target_year: int,
) -> dict[str, object]:
    normalized = validate_record(record, target_year)
    source_year = source_schedule_year(normalized, target_year)
    if source_year == target_year:
        normalized.pop(SOURCE_SCHEDULE_YEAR_KEY, None)
    else:
        normalized[SOURCE_SCHEDULE_YEAR_KEY] = source_year
    return normalized


def sort_records(records: list[dict[str, object]]) -> list[dict[str, object]]:
    return sorted(
        records,
        key=lambda record: (
            str(record.get("date", "")),
            str(record.get("kind", "")),
        ),
    )


def group_records_by_year(
    records: list[dict[str, object]],
) -> dict[int, list[dict[str, object]]]:
    grouped: dict[int, list[dict[str, object]]] = {}
    for record in records:
        parsed_date = record_date(record)
        grouped.setdefault(parsed_date.year, []).append(record)

    for year, year_records in grouped.items():
        validate_records(year_records, year)
        grouped[year] = sort_records(year_records)
    return grouped


def serialize_records(records: list[dict[str, object]]) -> str:
    rows = []
    for record in records:
        body = json.dumps(record, ensure_ascii=False, separators=(", ", ": "))[1:-1]
        rows.append(f"  {{ {body} }}")
    return "[\n" + ",\n".join(rows) + "\n]\n"


def manifest_payloads(feed_dir: Path, planned_paths: set[Path]) -> list[dict[str, object]]:
    paths = {path for path in feed_dir.glob("*.json") if path.name != "manifest.json"}
    paths.update(path for path in planned_paths if path.parent == feed_dir)

    payloads = []
    for path in sorted(paths):
        match = PAYLOAD_FILE_PATTERN.match(path.name)
        if match is None:
            continue
        payloads.append(
            {
                "regionID": match.group("region"),
                "year": int(match.group("year")),
                "path": path.name,
            }
        )
    return sorted(payloads, key=lambda payload: (str(payload["regionID"]), int(payload["year"])))


def serialize_manifest(version: str, generated_at: str, payloads: list[dict[str, object]]) -> str:
    rows = []
    for payload in payloads:
        body = json.dumps(payload, ensure_ascii=False, separators=(", ", ": "))[1:-1]
        rows.append(f"    {{ {body} }}")

    return "\n".join(
        [
            "{",
            f'  "version": {json.dumps(version)},',
            f'  "generatedAt": {json.dumps(generated_at)},',
            '  "payloads": [',
            ",\n".join(rows),
            "  ]",
            "}",
            "",
        ]
    )


def read_json(path: Path) -> object | None:
    if not path.exists():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise HolidaySyncError(f"Unable to read {path}: {error}") from error


def read_existing_records(path: Path, year: int) -> list[dict[str, object]]:
    document = read_json(path)
    if document is None:
        return []
    if not isinstance(document, list):
        raise HolidaySyncError(f"{path}: expected a JSON array")

    records = [validate_record(record, year) for record in document]
    validate_records(records, year)
    return sort_records(records)


def merge_existing_records(
    existing_records: list[dict[str, object]],
    new_records: list[dict[str, object]],
    refreshed_source_years: set[int],
    target_year: int,
) -> list[dict[str, object]]:
    retained: list[dict[str, object]] = []
    for raw_record in existing_records:
        record = normalize_source_metadata(raw_record, target_year)
        source_year = source_schedule_year(record, target_year)
        if source_year not in refreshed_source_years:
            retained.append(record)

    retained_by_date = {str(record["date"]): record for record in retained}
    normalized_new_records = [
        normalize_source_metadata(record, target_year) for record in new_records
    ]
    new_records_by_date: dict[str, dict[str, object]] = {}
    for record in normalized_new_records:
        record_date_value = str(record["date"])
        if record_date_value in new_records_by_date:
            previous_record = new_records_by_date[record_date_value]
            raise HolidaySyncError(
                f"{target_year}: {record_date_value} is provided by both "
                f"schedule year {source_schedule_year(previous_record, target_year)} and "
                f"schedule year {source_schedule_year(record, target_year)}"
            )
        new_records_by_date[record_date_value] = record
        if record_date_value not in retained_by_date:
            continue
        retained_record = retained_by_date[record_date_value]
        raise HolidaySyncError(
            f"{target_year}: {record_date_value} is provided by both "
            f"schedule year {source_schedule_year(retained_record, target_year)} and "
            f"schedule year {source_schedule_year(record, target_year)}"
        )

    merged = retained + normalized_new_records
    validate_records(merged, target_year)
    return sort_records(merged)


def planned_target_years(
    records_by_target_year: dict[int, list[dict[str, object]]],
    existing_payload_years: set[int],
    published_source_years: set[int],
) -> tuple[set[int], list[int]]:
    planned: set[int] = set()
    skipped: list[int] = []

    for target_year in sorted(records_by_target_year):
        if (
            target_year in published_source_years
            or target_year in existing_payload_years
        ):
            planned.add(target_year)
        else:
            skipped.append(target_year)

    return planned, skipped


def existing_mainland_payloads(
    feed_dir: Path,
) -> dict[int, tuple[Path, list[dict[str, object]]]]:
    payloads: dict[int, tuple[Path, list[dict[str, object]]]] = {}
    for path in sorted(feed_dir.glob("mainland-cn-*.json")):
        match = MAINLAND_PAYLOAD_PATTERN.match(path.name)
        if match is None:
            continue
        year = int(match.group("year"))
        payloads[year] = (path, read_existing_records(path, year))
    return payloads


def next_revision(
    now: datetime,
    existing_manifest: object | None,
) -> tuple[str, str]:
    candidate = now.astimezone(timezone.utc).replace(microsecond=0)

    if isinstance(existing_manifest, dict):
        raw_generated_at = existing_manifest.get("generatedAt")
        if isinstance(raw_generated_at, str):
            try:
                previous = datetime.fromisoformat(
                    raw_generated_at.replace("Z", "+00:00")
                )
            except ValueError as error:
                raise HolidaySyncError(
                    f"Invalid existing manifest generatedAt: {raw_generated_at}"
                ) from error
            if previous.tzinfo is None:
                previous = previous.replace(tzinfo=timezone.utc)
            previous = previous.astimezone(timezone.utc).replace(microsecond=0)
            if candidate <= previous:
                candidate = previous + timedelta(seconds=1)

    version = candidate.astimezone(CHINA_TIME_ZONE).strftime("%Y.%m.%d.%H%M%S")
    generated_at = candidate.isoformat().replace("+00:00", "Z")
    return version, generated_at


def write_text_atomically(path: Path, text: str) -> bool:
    if path.exists() and path.read_text(encoding="utf-8") == text:
        return False

    path.parent.mkdir(parents=True, exist_ok=True)
    file_descriptor, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(file_descriptor, "w", encoding="utf-8", newline="\n") as temporary_file:
            temporary_file.write(text)
        os.replace(temporary_name, path)
    except Exception:
        try:
            os.unlink(temporary_name)
        except FileNotFoundError:
            pass
        raise
    return True


def sync(
    years: list[int],
    *,
    dry_run: bool,
    feed_dir: Path = FEED_DIR,
    bundle_dir: Path = BUNDLE_DIR,
    manifest_path: Path = MANIFEST_PATH,
    fetcher=fetch_json,
    now: datetime | None = None,
) -> int:
    existing_payloads = existing_mainland_payloads(feed_dir)
    documents: dict[int, dict[int, list[dict[str, object]]]] = {}
    fetched_years: list[int] = []

    for year in sorted(set(years)):
        source_url = SOURCE_TEMPLATE.format(year=year)
        document = fetcher(source_url)
        if document is None:
            print(f"{year}: official data is not published yet; skipped")
            continue

        records = convert_document(document, year)
        documents[year] = group_records_by_year(records)
        fetched_years.append(year)
        print(f"{year}: validated {len(records)} holiday records")

    records_by_target_year: dict[int, list[dict[str, object]]] = {}
    for grouped_records in documents.values():
        for target_year, records in grouped_records.items():
            records_by_target_year.setdefault(target_year, []).extend(records)

    refreshed_source_years = set(documents)
    planned_years, skipped_years = planned_target_years(
        records_by_target_year,
        set(existing_payloads),
        refreshed_source_years,
    )
    for target_year in skipped_years:
        print(
            f"{target_year}: skipped cross-year records because the "
            f"{target_year} schedule is not published yet"
        )

    affected_years = set(planned_years)
    for target_year, (_, existing_records) in existing_payloads.items():
        if any(
            source_schedule_year(record, target_year) in refreshed_source_years
            for record in existing_records
        ):
            affected_years.add(target_year)

    planned_files: dict[Path, str] = {}
    for target_year in sorted(affected_years):
        existing_records = existing_payloads.get(target_year, (None, []))[1]
        merged_records = merge_existing_records(
            existing_records,
            records_by_target_year.get(target_year, []),
            refreshed_source_years,
            target_year,
        )
        if not merged_records:
            raise HolidaySyncError(
                f"{target_year}: synchronization would remove all holiday records"
            )

        payload_text = serialize_records(merged_records)
        planned_files[feed_dir / f"mainland-cn-{target_year}.json"] = payload_text
        planned_files[bundle_dir / f"mainland-cn-{target_year}.json"] = payload_text
        print(f"{target_year}: merged {len(merged_records)} holiday records")

    payloads = manifest_payloads(
        feed_dir,
        {path for path in planned_files if path.parent == feed_dir},
    )
    existing_manifest = read_json(manifest_path)
    existing_manifest_payloads = (
        existing_manifest.get("payloads") if isinstance(existing_manifest, dict) else None
    )

    changed_payload_files = {
        path: text
        for path, text in planned_files.items()
        if not path.exists() or path.read_text(encoding="utf-8") != text
    }
    payloads_changed = existing_manifest_payloads != payloads

    if not changed_payload_files and not payloads_changed:
        print("Holiday feed is already up to date")
        return 0

    version, generated_at = next_revision(
        now or datetime.now(CHINA_TIME_ZONE),
        existing_manifest,
    )
    manifest_text = serialize_manifest(version, generated_at, payloads)

    if dry_run:
        for path in sorted(changed_payload_files):
            print(f"would update {display_path(path)}")
        print(f"would update {display_path(manifest_path)}")
        return 0

    for path, text in sorted(changed_payload_files.items()):
        write_text_atomically(path, text)
        print(f"updated {display_path(path)}")

    if write_text_atomically(manifest_path, manifest_text):
        print("updated feed/holidays/manifest.json")

    synced_years = ", ".join(map(str, fetched_years)) or "none"
    print(f"Synced feed version {version} for years: {synced_years}")
    return 0


def display_path(path: Path) -> str:
    try:
        return str(path.relative_to(REPO_ROOT))
    except ValueError:
        return str(path)


def main() -> int:
    arguments = parse_args()
    try:
        return sync(arguments.years, dry_run=arguments.dry_run)
    except HolidaySyncError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
