"""P7: the numbers behind the Overview."""

import from domain.models { Business }
import from domain.seed { seed_demo_data }
import from domain.customers { create_customer }
import from domain.catalogue { create_product }
import from domain.inventory { adjust_inventory }
import from domain.orders { create_manual_order, submit_order, approve_order }
import from domain.order_input { OrderItemInput }
import from domain.analytics { get_analytics, day_strings }

def seeded() -> Business {
    biz = Business(name="My Wholesale");
    seed_demo_data(biz);
    return biz;
}

test "day windows are oldest first and include today" {
    assert day_strings("2026-10-17", 3) == ["2026-10-15", "2026-10-16", "2026-10-17"];
    assert day_strings("2026-10-17", 2, 7) == ["2026-10-09", "2026-10-10"];
}

test "seven-day sales, week-over-week and averages match the seeded history" {
    a = get_analytics(seeded(), "2026-10-17");
    assert len(a.days) == 7 and a.days[0].date == "2026-10-11" and a.days[6].date == "2026-10-17";
    by_day = {d.date: (d.revenue_kes, d.orders) for d in a.days};
    assert by_day["2026-10-12"] == (28500, 1) and by_day["2026-10-14"] == (54140, 3);
    assert by_day["2026-10-17"] == (0, 0);
    assert a.revenue_7d == 185280 and a.orders_7d == 13 and a.avg_order_kes == 14252;
    assert a.revenue_prev_7d == 42010;
}

test "status mix, channels, top products and low stock" {
    a = get_analytics(seeded(), "2026-10-17");
    assert [(s.status, s.count) for s in a.status_counts] == [("DELIVERED", 17)];
    assert [(c.channel, c.count) for c in a.channels] == [("manual", 17)];
    assert a.top_products[0].sku == "JOGOO-2KG-BALE" and a.top_products[1].sku == "RINA-1L-CTN";
    assert len(a.top_products) == 5;
    assert [i.available for i in a.low_stock] == [0, 4] and a.low_stock[0].sku == "MILK-LATO-CTN";
}

test "pending approvals are counted and listed oldest first with the customer name" {
    biz = seeded();
    first = create_manual_order(biz, "C-001", [OrderItemInput(sku="RINA-1L-CTN", quantity=2)]);
    second = create_manual_order(biz, "C-002", [OrderItemInput(sku="OMO-1KG-CTN", quantity=1)]);
    submit_order(biz, first.order_id);
    submit_order(biz, second.order_id);
    a = get_analytics(biz, first.created_at[:10]);
    assert a.pending_count == 2 and [p.order_id for p in a.pending] == [first.order_id, second.order_id];
    assert a.pending[0].customer_name == "Mama Wanjiku Shop";
    approve_order(biz, first.order_id);
    b = get_analytics(biz, first.created_at[:10]);
    assert b.pending_count == 1 and b.revenue_7d == 5600;
}

test "an empty business gives empty, safe numbers" {
    biz = Business(name="T");
    a = get_analytics(biz, "2026-10-17");
    assert a.revenue_7d == 0 and a.orders_7d == 0 and a.avg_order_kes == 0;
    assert a.top_products == [] and a.status_counts == [] and a.pending_count == 0 and len(a.days) == 7;
}
