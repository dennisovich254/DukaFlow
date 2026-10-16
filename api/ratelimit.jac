"""A small in-memory sliding-window rate limiter for the public chat endpoints.

Limits are per invite token (one customer) and apply to a single server process; a
multi-process deployment would need a shared store. The client's IP address is not
available to Jac endpoints, so the token is the identity we can limit.
"""

import time;

glob WINDOWS: dict[str, list[float]] = {};

glob MESSAGES_PER_MINUTE: int = 20;
glob PHOTOS_PER_MINUTE: int = 6;
glob POLLS_PER_MINUTE: int = 90;
glob IMAGE_READS_PER_MINUTE: int = 60;
glob INVALID_PER_MINUTE: int = 40;

"""True and records the hit if `key` is under `limit` hits in the last `window` seconds."""
def allow(key: str, limit: int, window: int = 60, now: float = 0.0) -> bool {
    t = now if now > 0.0 else time.time();
    hits = [h for h in WINDOWS.get(key, []) if h > t - window];
    if len(hits) >= limit {
        WINDOWS[key] = hits;
        return False;
    }
    hits.append(t);
    WINDOWS[key] = hits;
    return True;
}

"""Forget windows that have gone quiet, so the table cannot grow without bound."""
def prune(now: float = 0.0, window: int = 60) {
    t = now if now > 0.0 else time.time();
    for key in list(WINDOWS.keys()) {
        if not [h for h in WINDOWS[key] if h > t - window] { WINDOWS.pop(key, None); }
    }
}

def reset() {
    WINDOWS.clear();
}
