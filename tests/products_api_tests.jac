"""P1.3 / P1.5: product endpoints over HTTP, with authentication and isolation."""

import from tests.api_helpers { new_client, new_client_as_owner, call }

def add(client: any, sku: str, price: any) -> any {
    return call(client, "add_product", {"data": {
        "sku": sku, "name": "Rina 1L Carton", "brand": "Rina", "category": "Oil",
        "unit": "carton", "price_kes": price
    }});
}

test "owner adds a product, adjusts stock and lists it" {
    client = new_client_as_owner();
    try {
        r = add(client, "rina-1l-ctn", 2800);
        assert r["ok"], r["error"];
        assert r["product"]["sku"] == "RINA-1L-CTN" and r["product"]["quantity_available"] == 0;
        s = call(client, "adjust_stock", {"data": {"sku": "RINA-1L-CTN", "quantity_change": 20, "reason": "opening stock"}});
        assert s["product"]["quantity_available"] == 20;
        bad = call(client, "adjust_stock", {"data": {"sku": "RINA-1L-CTN", "quantity_change": -25, "reason": "oops"}});
        assert not bad["ok"] and bad["error"]["code"] == "INSUFFICIENT_STOCK";
        listed = call(client, "list_catalogue", {"query": {"include_inactive": False}});
        assert [p["sku"] for p in listed] == ["RINA-1L-CTN"] and listed[0]["quantity_on_hand"] == 20;
    } finally { client.close(); }
}

test "fractional price is rejected over http instead of being truncated" {
    client = new_client_as_owner();
    try {
        r = add(client, "X", 2800.5);
        assert not r["ok"] and r["error"]["code"] == "VALIDATION_ERROR";
        assert call(client, "list_catalogue", {"query": {"include_inactive": True}}) == [];
    } finally { client.close(); }
}

test "duplicate sku and edit price" {
    client = new_client_as_owner();
    try {
        add(client, "A", 100);
        dup = add(client, "a", 100);
        assert not dup["ok"] and dup["error"]["code"] == "DUPLICATE_SKU";
        e = call(client, "edit_product", {"data": {"sku": "A", "price_kes": 150}});
        assert e["ok"] and e["product"]["price_kes"] == 150;
    } finally { client.close(); }
}

test "unauthenticated calls are rejected" {
    client = new_client();
    try {
        assert client.post("/function/list_catalogue", json={"query": {"include_inactive": False}}).status_code == 401;
        assert client.post("/function/add_product", json={"data": {"sku": "A", "name": "A", "unit": "carton", "price_kes": 1}}).status_code == 401;
    } finally { client.close(); }
}

test "a second wholesaler sees an empty catalogue" {
    client = new_client_as_owner();
    try {
        add(client, "A", 100);
        other = new_client();
        try {
            other.register_user("other", "password123");
            assert call(other, "list_catalogue", {"query": {"include_inactive": True}}) == [];
        } finally { other.close(); }
    } finally { client.close(); }
}
