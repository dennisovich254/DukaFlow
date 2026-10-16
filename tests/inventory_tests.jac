"""P1.4: inventory adjustments."""

import from domain.models { Business, HasMovement }
import from domain.catalogue { create_product, inventory_of, get_product }
import from domain.inventory { adjust_inventory }
import from domain.errors { DomainError }
import from tests.helpers { code_of }

def setup() -> Business {
    biz = Business(name="T");
    create_product(biz, sku="RINA-1L-CTN", name="Rina", brand="", category="", unit="carton", price_kes=2800);
    return biz;
}

test "adjustments add up" {
    biz = setup();
    adjust_inventory(biz, "RINA-1L-CTN", 5, "opening stock");
    rec = adjust_inventory(biz, "RINA-1L-CTN", 10, "delivery");
    assert rec.quantity_on_hand == 15;
    assert len([get_product(biz, "RINA-1L-CTN") ->:HasMovement:->]) == 2;
}

test "negative on hand is refused and stock is unchanged" {
    biz = setup();
    adjust_inventory(biz, "RINA-1L-CTN", 5, "opening");
    with testraises(DomainError) as e { adjust_inventory(biz, "RINA-1L-CTN", -6, "damaged"); }
    assert code_of(e.value) == "INSUFFICIENT_STOCK";
    assert inventory_of(get_product(biz, "RINA-1L-CTN")).quantity_on_hand == 5;
}

test "unknown sku, zero or fractional change and empty reason are rejected" {
    biz = setup();
    with testraises(DomainError) as e1 { adjust_inventory(biz, "NOPE", 1, "x"); }
    assert code_of(e1.value) == "PRODUCT_NOT_FOUND";
    for bad in [0, 1.5, True] {
        with testraises(DomainError) as e2 { adjust_inventory(biz, "RINA-1L-CTN", bad, "x"); }
        assert code_of(e2.value) == "INVALID_QUANTITY";
    }
    with testraises(DomainError) as e3 { adjust_inventory(biz, "RINA-1L-CTN", 3, "  "); }
    assert code_of(e3.value) == "VALIDATION_ERROR";
}
