"""P1.2: whole-shilling pricing."""

import from domain.pricing { calculate_line_total, calculate_order_total, validate_price_kes, validate_quantity }
import from domain.errors { DomainError }
import from tests.helpers { code_of }

test "line total is price times quantity" {
    assert calculate_line_total(150, 5) == 750;
}

test "order total sums lines" {
    assert calculate_order_total([(2800, 5), (1450, 10)]) == 28500;
}

test "bad quantities are rejected" {
    for bad in [0, -3, True, 2.5, "5"] {
        with testraises(DomainError) as e { validate_quantity(bad); }
        assert code_of(e.value) == "INVALID_QUANTITY";
    }
    assert validate_quantity(4) == 4;
    assert validate_quantity(4.0) == 4;
}

test "bad prices are rejected and whole prices accepted" {
    for bad in [-1, 0, 2800.5, True, "2800"] {
        with testraises(DomainError) as e { validate_price_kes(bad); }
        assert code_of(e.value) == "VALIDATION_ERROR";
    }
    assert validate_price_kes(2800) == 2800;
}

test "large values are exact" {
    assert calculate_line_total(250000, 1000) == 250000000;
}
