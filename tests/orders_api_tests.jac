"""P1.7: customer and order endpoints over HTTP."""

import from tests.api_helpers { new_client, new_client_as_owner, call }

def seed(client: any) {
    call(client, "add_product", {"data": {"sku": "RINA-1L-CTN", "name": "Rina 1L Carton", "brand": "Rina", "category": "Oil", "unit": "carton", "price_kes": 2800}});
    call(client, "add_customer", {"data": {"name": "Mama Wanjiku Shop", "phone": "0700000001"}});
}

test "owner creates a customer and a manual order" {
    client = new_client_as_owner();
    try {
        seed(client);
        customers = call(client, "list_customer_records", {});
        assert [c["customer_id"] for c in customers] == ["C-001"] and customers[0]["phone"] == "+254700000001";
        r = call(client, "create_order", {"data": {"customer_id": "C-001", "items": [{"sku": "RINA-1L-CTN", "quantity": 5}]}});
        assert r["ok"], r["error"];
        assert (r["order"]["order_id"], r["order"]["total_kes"], r["order"]["customer_name"]) == ("ORD-1001", 14000, "Mama Wanjiku Shop");
        assert r["order"]["lines"][0]["unit_price_kes"] == 2800;
        assert [o["order_id"] for o in call(client, "list_order_records", {})] == ["ORD-1001"];
        fetched = call(client, "get_order_record", {"query": {"order_id": "ORD-1001"}});
        assert fetched["order"]["status"] == "DRAFT";
    } finally { client.close(); }
}

test "fractional quantity is rejected over http" {
    client = new_client_as_owner();
    try {
        seed(client);
        r = call(client, "create_order", {"data": {"customer_id": "C-001", "items": [{"sku": "RINA-1L-CTN", "quantity": 2.5}]}});
        assert not r["ok"] and r["error"]["code"] == "INVALID_QUANTITY";
        assert call(client, "list_order_records", {}) == [];
    } finally { client.close(); }
}

test "order endpoints require login and are isolated per wholesaler" {
    client = new_client();
    try {
        assert client.post("/function/list_order_records", json={}).status_code == 401;
        assert client.post("/function/create_order", json={"data": {"customer_id": "C-001", "items": []}}).status_code == 401;
        assert client.post("/function/list_customer_records", json={}).status_code == 401;
        client.register_user("owner", "password123");
        seed(client);
        other = new_client();
        try {
            other.register_user("other", "password123");
            assert call(other, "list_customer_records", {}) == [] and call(other, "list_order_records", {}) == [];
        } finally { other.close(); }
    } finally { client.close(); }
}
