"""P6: the sliding-window limiter."""

import from api.ratelimit { allow, prune, reset, WINDOWS }

test "the limiter allows up to the limit inside the window, then refuses" {
    reset();
    for i in range(3) { assert allow("k", 3, 60, 1000.0 + i); }
    assert not allow("k", 3, 60, 1003.0);
    assert allow("other", 3, 60, 1003.0);
}

test "old hits fall out of the window" {
    reset();
    for i in range(3) { assert allow("k", 3, 60, 1000.0 + i); }
    assert not allow("k", 3, 60, 1030.0);
    assert allow("k", 3, 60, 1061.5);
}

test "pruning forgets quiet keys" {
    reset();
    allow("quiet", 5, 60, 1000.0);
    allow("busy", 5, 60, 1100.0);
    prune(1100.0, 60);
    assert "quiet" not in WINDOWS and "busy" in WINDOWS;
}
