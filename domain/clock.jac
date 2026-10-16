"""Time helpers. The business operates on Africa/Nairobi time."""

import from datetime { datetime }
import from zoneinfo { ZoneInfo }

def now_iso() -> str {
    return datetime.now(ZoneInfo("Africa/Nairobi")).isoformat(timespec="seconds");
}

"""Microsecond precision, for events that can happen within one second (messages)."""
def now_iso_precise() -> str {
    return datetime.now(ZoneInfo("Africa/Nairobi")).isoformat(timespec="microseconds");
}
