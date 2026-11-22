# /// script
# requires-python = ">=3.12"
# dependencies = ["caldav==3.7.0", "icalendar==7.3.2"]
# ///
"""Mirror the Moodle iCal export into the read-only "uczelnia" calendar, keyed by UID.

Moodle gives every event a 1 h slot; a "HH:MM - HH:MM" in the title is the real time
and replaces DTSTART/DTEND (Europe/Warsaw). Deadlines (DTSTART == DTEND) are kept.
"""
import hashlib
import logging
import os
import re
import sys
import urllib.request
from datetime import date, datetime, timedelta, timezone
from zoneinfo import ZoneInfo

import caldav
from icalendar import Calendar, Event

TZ = ZoneInfo("Europe/Warsaw")
TIME_RANGE = re.compile(r"(?<!\d)([01]?\d|2[0-3])[:.]([0-5]\d)\s*[-–—]\s*([01]?\d|2[0-3])[:.]([0-5]\d)(?!\d)")
COPIED = ("SUMMARY", "DESCRIPTION", "LOCATION", "CATEGORIES", "CLASS", "URL")
HASH_PROP = "X-VZKN-SOURCE-HASH"

log = logging.getLogger("moodle-sync")


def local_day(value) -> date:
    if isinstance(value, datetime):
        if value.tzinfo is None:
            value = value.replace(tzinfo=timezone.utc)
        return value.astimezone(TZ).date()
    return value


def fix_times(src: Event) -> tuple:
    """Return (dtstart, dtend) after applying the title time range, if any."""
    start = src.decoded("DTSTART")
    end = src.decoded("DTEND") if "DTEND" in src else start
    if start == end:
        return start, end  # deadline / submission: leave as Moodle sends it
    match = TIME_RANGE.search(str(src.get("SUMMARY", "")))
    if not match:
        return start, end
    h1, m1, h2, m2 = map(int, match.groups())
    day = local_day(start)
    new_start = datetime(day.year, day.month, day.day, h1, m1, tzinfo=TZ)
    new_end = datetime(day.year, day.month, day.day, h2, m2, tzinfo=TZ)
    if new_end <= new_start:
        new_end += timedelta(days=1)
    return new_start, new_end


def build(src: Event) -> tuple[str, str, datetime | date]:
    """Build the target VCALENDAR text, its source hash and its start."""
    start, end = fix_times(src)
    ev = Event()
    ev.add("UID", str(src["UID"]))
    ev.add("DTSTAMP", datetime.now(timezone.utc))
    ev.add("DTSTART", start)
    ev.add("DTEND", end)
    for prop in COPIED:
        if prop in src:
            ev[prop] = src[prop]
    digest = hashlib.sha256(
        "|".join([str(src["UID"]), start.isoformat(), end.isoformat()] + [str(src.get(p, "")) for p in COPIED]).encode()
    ).hexdigest()
    ev.add(HASH_PROP, digest)
    cal = Calendar()
    cal.add("PRODID", "-//vzkn//moodle-sync//EN")
    cal.add("VERSION", "2.0")
    cal.add_component(ev)
    cal.add_missing_timezones()
    return cal.to_ical().decode(), digest, start


def is_future(value) -> bool:
    if isinstance(value, datetime):
        return value.astimezone(timezone.utc) >= datetime.now(timezone.utc)
    return value >= datetime.now(TZ).date()


def main() -> int:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    with urllib.request.urlopen(os.environ["MOODLE_ICAL_URL"], timeout=60) as resp:
        feed = Calendar.from_ical(resp.read())
    source = {str(e["UID"]): e for e in feed.walk("VEVENT")}
    log.info("feed: %d events", len(source))

    url = os.environ["DAV_URL"].rstrip("/") + "/dav/cal/" + os.environ["MOODLE_USER"].replace("@", "%40") + "/uczelnia/"
    client = caldav.DAVClient(url=url, username=os.environ["MOODLE_USER"], password=os.environ["MOODLE_PASSWORD"])
    calendar = caldav.Calendar(client=client, url=url)

    existing = {}
    for obj in calendar.events():
        comp = obj.icalendar_component
        existing[str(comp["UID"])] = (obj, str(comp.get(HASH_PROP, "")), comp.decoded("DTSTART"))

    created = updated = deleted = unchanged = 0
    for uid, src in source.items():
        text, digest, _ = build(src)
        if uid not in existing:
            calendar.save_event(text)
            created += 1
            log.info("created %s %s", uid, src.get("SUMMARY"))
        elif existing[uid][1] != digest:
            obj = existing[uid][0]
            obj.data = text
            obj.save()
            updated += 1
            log.info("updated %s %s", uid, src.get("SUMMARY"))
        else:
            unchanged += 1

    # The export only covers a rolling window: drop vanished events only if still upcoming
    # (cancelled), keep past ones as history.
    for uid, (obj, _, start) in existing.items():
        if uid not in source and is_future(start):
            obj.delete()
            deleted += 1
            log.info("deleted %s (no longer in feed)", uid)

    log.info("done: created=%d updated=%d deleted=%d unchanged=%d", created, updated, deleted, unchanged)
    return 0


if __name__ == "__main__":
    sys.exit(main())
