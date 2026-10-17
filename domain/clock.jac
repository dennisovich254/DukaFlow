"""Time helpers. The business operates on Africa/Nairobi time.

Kenya is UTC+3 all year (no daylight saving), so a fixed offset is exact. It also works in
slim containers that ship without the system timezone database, where ZoneInfo would fail."""

import from datetime { datetime, timedelta, timezone }

glob NAIROBI: timezone = timezone(timedelta(hours=3), "EAT");

def now_iso() -> str {
    return datetime.now(NAIROBI).isoformat(timespec="seconds");
}

"""Microsecond precision, for events that can happen within one second (messages)."""
def now_iso_precise() -> str {
    return datetime.now(NAIROBI).isoformat(timespec="microseconds");
}

"""ISO timestamp `hours` from now (quotation expiry)."""
def iso_in_hours(hours: int) -> str {
    return (datetime.now(NAIROBI) + timedelta(hours=hours)).isoformat(timespec="seconds");
}
