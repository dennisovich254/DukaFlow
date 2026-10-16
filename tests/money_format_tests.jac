"""P1.6: shillings are formatted in one place."""

import from lib.money { format_kes }

test "format_kes groups thousands" {
    assert format_kes(14000) == "KSh 14,000";
    assert format_kes(0) == "KSh 0";
    assert format_kes(999) == "KSh 999";
    assert format_kes(1250000) == "KSh 1,250,000";
    assert format_kes(-2800) == "-KSh 2,800";
}
