"""P4.2: product resolver."""

import from domain.models { Business }
import from domain.seed { seed_demo_data }
import from ai.resolver { search_products, is_clear_winner, tokenize }

def seeded() -> Business {
    biz = Business(name="My Wholesale");
    seed_demo_data(biz);
    return biz;
}

test "tokenizer joins sizes" {
    assert tokenize("Rina 1 litre") == ["rina", "1l"];
    assert tokenize("Jogoo 2 kg bale") == ["jogoo", "2kg", "bale"];
}

test "natural phrasings resolve to the right sku" {
    biz = seeded();
    for q in ["Rina 1L", "rina 1 litre", "mafuta ya Rina 1l"] {
        c = search_products(biz, q, "carton");
        assert c[0].sku == "RINA-1L-CTN" and is_clear_winner(c);
    }
    assert search_products(biz, "unga jogoo", "bale")[0].sku == "JOGOO-2KG-BALE";
    assert search_products(biz, "royco cubes")[0].sku == "ROYCO-CUBE-CTN";
}

test "generic words are ambiguous and unstocked words find nothing" {
    biz = seeded();
    sugar = search_products(biz, "sukari 2kg", "bale");
    assert len(sugar) >= 2 and not is_clear_winner(sugar[:2]) or sugar[0].sku in ["KABRAS-2KG-BALE", "MUMIAS-2KG-BALE"];
    assert search_products(biz, "samaki") == [] and search_products(biz, "kuku") == [];
}

test "candidates carry price and live availability" {
    biz = seeded();
    c = search_products(biz, "rina 1l")[0];
    assert (c.price_kes, c.available) == (2800, 8);
}
