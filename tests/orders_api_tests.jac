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

test "order lifecycle over http with stock, summary and demo data" {
    client = new_client_as_owner();
    try {
        seed(client);
        call(client, "adjust_stock", {"data": {"sku": "RINA-1L-CTN", "quantity_change": 10, "reason": "opening"}});
        call(client, "create_order", {"data": {"customer_id": "C-001", "items": [{"sku": "RINA-1L-CTN", "quantity": 5}]}});
        r = call(client, "act_on_order", {"data": {"order_id": "ORD-1001", "action": "submit"}});
        assert r["order"]["status"] == "PENDING_APPROVAL";
        s = call(client, "dashboard_summary", {});
        assert s["pending_approval"] == 1 and s["orders_today"] == 1 and s["ai_mode"] == "mock";
        r = call(client, "act_on_order", {"data": {"order_id": "ORD-1001", "action": "approve"}});
        assert r["order"]["status"] == "APPROVED";
        again = call(client, "act_on_order", {"data": {"order_id": "ORD-1001", "action": "approve"}});
        assert not again["ok"] and again["error"]["code"] == "INVALID_ORDER_STATE";
        r = call(client, "act_on_order", {"data": {"order_id": "ORD-1001", "action": "dispatch"}});
        assert r["order"]["status"] == "DISPATCHED";
        products = call(client, "list_catalogue", {"query": {"include_inactive": False}});
        assert products[0]["quantity_on_hand"] == 5 and products[0]["quantity_reserved"] == 0;
        assert call(client, "load_demo_data", {}) == 0;     # catalogue not empty: nothing added
    } finally { client.close(); }
}

test "dashboard and demo data endpoints require login; demo data fills an empty business" {
    client = new_client();
    try {
        assert client.post("/function/dashboard_summary", json={}).status_code == 401;
        assert client.post("/function/load_demo_data", json={}).status_code == 401;
        client.register_user("owner", "password123");
        assert call(client, "load_demo_data", {}) == 39;
        assert len(call(client, "list_catalogue", {"query": {"include_inactive": False}})) == 39;
        assert call(client, "dashboard_summary", {})["low_stock_count"] >= 2;
    } finally { client.close(); }
}
