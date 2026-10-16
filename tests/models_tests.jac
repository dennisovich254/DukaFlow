"""P1.1: domain graph shape (transient graphs, no server)."""

import from domain.models {
    Business, Product, InventoryRecord, Order, OrderLine,
    OwnsProduct, HasInventory, HasOrder, ContainsLine
}

test "product linked to a business is reachable" {
    biz = Business(name="T");
    p = Product(sku="A", name="A", brand="", category="", unit="carton", price_kes=100);
    biz +>:OwnsProduct():+> p;
    assert [x.sku for x in [biz ->:OwnsProduct:->]] == ["A"];
}

test "product to inventory record is traversable and available subtracts reserved" {
    p = Product(sku="A", name="A", brand="", category="", unit="carton", price_kes=100);
    p +>:HasInventory():+> InventoryRecord(quantity_on_hand=10, quantity_reserved=3);
    rec = [p ->:HasInventory:->][0];
    assert rec.available() == 7;
}

test "an order returns both lines" {
    biz = Business(name="T");
    o = Order(order_id="ORD-1001", customer_id="C-001", created_at="t");
    biz +>:HasOrder():+> o;
    o +>:ContainsLine():+> OrderLine(product_sku="A", product_name="A", quantity=1, unit="carton", unit_price_kes=10, line_total_kes=10);
    o +>:ContainsLine():+> OrderLine(product_sku="B", product_name="B", quantity=2, unit="bale", unit_price_kes=5, line_total_kes=10);
    assert sorted([l.product_sku for l in [o ->:ContainsLine:->]]) == ["A", "B"];
}
