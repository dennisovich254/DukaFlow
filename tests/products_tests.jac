"""P1.3: catalogue rules (domain level)."""

import from domain.models { Business }
import from domain.catalogue { create_product, list_products, update_product, find_product, inventory_of }
import from domain.errors { DomainError }
import from tests.helpers { code_of }

def setup() -> Business {
    biz = Business(name="T");
    create_product(biz, sku="rina-1l-ctn", name="Rina 1L Carton", brand="Rina", category="Oil",
                   unit="carton", price_kes=2800, aliases=["Rina", " rina oil "]);
    return biz;
}

test "create then list gives an int price and normalised fields" {
    biz = setup();
    ps = list_products(biz);
    assert [p.sku for p in ps] == ["RINA-1L-CTN"];
    assert ps[0].price_kes == 2800 and isinstance(ps[0].price_kes, int);
    assert ps[0].aliases == ["rina", "rina oil"];
    assert inventory_of(ps[0]).quantity_on_hand == 0;
}

test "duplicate sku is rejected case-insensitively" {
    biz = setup();
    with testraises(DomainError) as e {
        create_product(biz, sku="RINA-1L-CTN", name="Again", brand="", category="", unit="carton", price_kes=1);
    }
    assert code_of(e.value) == "DUPLICATE_SKU";
}

test "invalid input is rejected" {
    biz = setup();
    cases: list[tuple[str, str, any]] = [
        ("", "carton", 100),
        ("X", "pallet", 100),
        ("X", "carton", -5),
        ("X", "carton", 99.5)
    ];
    for (name, unit, price) in cases {
        with testraises(DomainError) as e {
            create_product(biz, sku="NEW", name=name, brand="", category="", unit=unit, price_kes=price);
        }
        assert code_of(e.value) == "VALIDATION_ERROR";
    }
    assert find_product(biz, "NEW") is None;
}

test "update price is visible and a bad update changes nothing" {
    biz = setup();
    update_product(biz, "RINA-1L-CTN", price_kes=2950);
    assert list_products(biz)[0].price_kes == 2950;
    with testraises(DomainError) as e { update_product(biz, "RINA-1L-CTN", name="Changed", price_kes=2950.5); }
    assert list_products(biz)[0].name == "Rina 1L Carton";
    with testraises(DomainError) as e2 { update_product(biz, "NOPE", price_kes=1); }
    assert code_of(e2.value) == "PRODUCT_NOT_FOUND";
}

test "inactive products are excluded unless requested" {
    biz = setup();
    update_product(biz, "RINA-1L-CTN", active=False);
    assert list_products(biz) == [];
    assert len(list_products(biz, include_inactive=True)) == 1;
}
