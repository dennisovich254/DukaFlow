"""Time helpers. The business operates on Africa/Nairobi time."""

import from datetime { datetime, timedelta }
import from zoneinfo { ZoneInfo }

def now_iso() -> str {
    return datetime.now(ZoneInfo("Africa/Nairobi")).isoformat(timespec="seconds");
}

"""Microsecond precision, for events that can happen within one second (messages)."""
def now_iso_precise() -> str {
    return datetime.now(ZoneInfo("Africa/Nairobi")).isoformat(timespec="microseconds");
}

"""ISO timestamp `hours` from now (quotation expiry)."""
def iso_in_hours(hours: int) -> str {
    return (datetime.now(ZoneInfo("Africa/Nairobi")) + timedelta(hours=hours)).isoformat(timespec="seconds");
}
