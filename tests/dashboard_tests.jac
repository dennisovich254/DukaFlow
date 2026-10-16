"""P2.7: dashboard summary counts."""

import from domain.models { Business }
import from domain.catalogue { create_product }
import from domain.customers { create_customer }
import from domain.inventory { adjust_inventory }
import from domain.orders { create_manual_order, submit_order }
import from domain.order_input { OrderItemInput }
import from domain.dashboard { get_dashboard_summary }
import from domain.clock { now_iso }

test "summary counts orders, pending approvals and low stock" {
    biz = Business(name="T");
    for sku in ["A", "B", "C"] {
        create_product(biz, sku=sku, name=sku, brand="", category="", unit="carton", price_kes=100);
    }
    adjust_inventory(biz, "A", 3, "x");
    adjust_inventory(biz, "B", 5, "x");
    adjust_inventory(biz, "C", 50, "x");
    create_customer(biz, name="Shop", phone="0700000001");
    o1 = create_manual_order(biz, "C-001", [OrderItemInput(sku="C", quantity=1)]);
    create_manual_order(biz, "C-001", [OrderItemInput(sku="C", quantity=2)]);
    create_manual_order(biz, "C-001", [OrderItemInput(sku="C", quantity=3)]);
    submit_order(biz, o1.order_id);
    s = get_dashboard_summary(biz, now_iso()[:10]);
    assert (s.orders_today, s.pending_approval, s.low_stock_count) == (3, 1, 2);
    assert [o.order_id for o in s.recent_orders] == ["ORD-1003", "ORD-1002", "ORD-1001"];
    assert get_dashboard_summary(biz, "1999-01-01").orders_today == 0;
}
