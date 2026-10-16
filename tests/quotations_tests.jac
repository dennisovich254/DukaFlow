"""P4.4: quotations, shortage planning, confirmation."""

import from domain.models { Business, Order }
import from domain.seed { seed_demo_data }
import from domain.catalogue { update_product, inventory_of, get_product }
import from domain.orders { get_order, list_orders }
import from domain.quotations {
    RequestedLine, plan_quote, build_quotation, confirm_quotation, latest_quotation, quotation_lines,
    cancel_open_quotation
}
import from domain.errors { DomainError }
import from tests.helpers { code_of }

def seeded() -> Business {
    biz = Business(name="My Wholesale");
    seed_demo_data(biz);
    return biz;
}

def n_orders(biz: Business) -> int {
    return len([o for o in list_orders(biz) if o.channel == "shop_chat"]);
}

test "a shortage is planned with an alternative and a note, without changing stock" {
    biz = seeded();
    plan = plan_quote(biz, [RequestedLine(sku="RINA-1L-CTN", quantity=10), RequestedLine(sku="JOGOO-2KG-BALE", quantity=5)]);
    got = {l.sku: l.quantity for l in plan.lines};
    assert got["RINA-1L-CTN"] == 8 and got["JOGOO-2KG-BALE"] == 5;
    alt = [n for n in plan.notes if n.kind == "SHORT"][0];
    assert (alt.wanted, alt.available, alt.alt_qty) == (10, 8, 2) and alt.alt_sku != "";
    assert sum([l.quantity for l in plan.lines]) == 15;
    rec = inventory_of(get_product(biz, "RINA-1L-CTN"));
    assert (rec.quantity_on_hand, rec.quantity_reserved) == (8, 0);
}

test "an item with no stock and no alternative is reported unavailable" {
    biz = seeded();
    plan = plan_quote(biz, [RequestedLine(sku="MILK-LATO-CTN", quantity=3)]);
    assert plan.lines == [] and plan.notes[0].kind == "UNAVAILABLE";
}

test "quote total matches pricing and a later price change does not alter it" {
    biz = seeded();
    q = build_quotation(biz, "C-001", plan_quote(biz, [RequestedLine(sku="RINA-1L-CTN", quantity=5), RequestedLine(sku="JOGOO-2KG-BALE", quantity=10)]));
    assert q.total_kes == 28500 and q.status == "OPEN" and q.quote_id == "Q-1001";
    update_product(biz, "RINA-1L-CTN", price_kes=3000);
    assert q.total_kes == 28500 and [l.unit_price_kes for l in quotation_lines(q) if l.product_sku == "RINA-1L-CTN"] == [2800];
    assert inventory_of(get_product(biz, "RINA-1L-CTN")).quantity_reserved == 0;
}

test "confirming creates exactly one pending order at the quoted prices" {
    biz = seeded();
    build_quotation(biz, "C-001", plan_quote(biz, [RequestedLine(sku="RINA-1L-CTN", quantity=5)]));
    update_product(biz, "RINA-1L-CTN", price_kes=3000);
    order = confirm_quotation(biz, "C-001");
    assert (order.status, order.channel, order.total_kes) == ("PENDING_APPROVAL", "shop_chat", 14000);
    with testraises(DomainError) as e { confirm_quotation(biz, "C-001"); }
    assert code_of(e.value) == "NO_OPEN_QUOTE" and n_orders(biz) == 1;
}

test "an expired quote cannot be confirmed" {
    biz = seeded();
    q = build_quotation(biz, "C-001", plan_quote(biz, [RequestedLine(sku="RINA-1L-CTN", quantity=1)]));
    q.expires_at = "2000-01-01T00:00:00+03:00";
    with testraises(DomainError) as e { confirm_quotation(biz, "C-001"); }
    assert code_of(e.value) == "QUOTE_EXPIRED" and q.status == "EXPIRED" and n_orders(biz) == 0;
}

test "a new quote cancels the previous open one and cancel works" {
    biz = seeded();
    a = build_quotation(biz, "C-001", plan_quote(biz, [RequestedLine(sku="RINA-1L-CTN", quantity=1)]));
    b = build_quotation(biz, "C-001", plan_quote(biz, [RequestedLine(sku="JOGOO-2KG-BALE", quantity=1)]));
    latest = latest_quotation(biz, "C-001");
    assert latest is not None and latest.quote_id == b.quote_id;
    assert a.status == "CANCELLED" and b.status == "OPEN";
    assert cancel_open_quotation(biz, "C-001") and b.status == "CANCELLED";
    assert not cancel_open_quotation(biz, "C-001");
}
