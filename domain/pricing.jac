"""Money and quantity rules. Money is integer whole shillings; all totals come from here."""

import from domain.errors { DomainError }

"""Accept a whole number (a JSON number like 2800 may arrive as int or as 2800.0)."""
def as_whole_number(value: any) -> int | None {
    if isinstance(value, bool) { return None; }
    if isinstance(value, int) { return value as int; }
    if isinstance(value, float) and (value as float).is_integer() { return int(value as float); }
    return None;
}

def validate_price_kes(value: any) -> int {
    whole = as_whole_number(value);
    if whole is None {
        raise DomainError(code="VALIDATION_ERROR", message=f"Price must be a whole number of shillings, got {value!r}");
    }
    if (whole as int) < 1 {
        raise DomainError(code="VALIDATION_ERROR", message="Price must be at least KSh 1");
    }
    return whole as int;
}

def validate_quantity(value: any) -> int {
    whole = as_whole_number(value);
    if whole is None or (whole as int) < 1 {
        raise DomainError(code="INVALID_QUANTITY", message=f"Quantity must be a whole number of at least 1, got {value!r}");
    }
    return whole as int;
}

def calculate_line_total(unit_price_kes: int, quantity: int) -> int {
    return validate_price_kes(unit_price_kes) * validate_quantity(quantity);
}

"""Total of (unit_price_kes, quantity) pairs."""
def calculate_order_total(lines: list[tuple[int, int]]) -> int {
    total = 0;
    for (price, qty) in lines {
        total += calculate_line_total(price, qty);
    }
    return total;
}

"""Whole shillings as text, e.g. KSh 14,000."""
def format_kes(amount: int) -> str {
    digits = str(abs(amount));
    groups: list[str] = [];
    while len(digits) > 3 {
        groups = [digits[len(digits) - 3:]] + groups;
        digits = digits[:len(digits) - 3];
    }
    groups = [digits] + groups;
    return ("-" if amount < 0 else "") + "KSh " + ",".join(groups);
}
