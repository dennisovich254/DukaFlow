"""Money display. Amounts are integer whole shillings; this only formats them.

Written without Python format specs so it compiles identically for the browser.
"""

def format_kes(amount: int) -> str {
    sign = "-" if amount < 0 else "";
    digits = str(abs(amount));
    groups: list[str] = [];
    while len(digits) > 3 {
        groups = [digits[len(digits) - 3:]] + groups;
        digits = digits[:len(digits) - 3];
    }
    groups = [digits] + groups;
    return sign + "KSh " + ",".join(groups);
}
