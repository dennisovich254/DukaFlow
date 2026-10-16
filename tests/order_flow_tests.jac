"""P2.1-P2.5: state machine, approve/reject, dispatch/cancel, all-or-nothing stock, audit."""

import from domain.models { Business, Order }
import from domain.catalogue { create_product, inventory_of, get_product, update_product }
import from domain.customers { create_customer }
import from domain.inventory { adjust_inventory }
import from domain.orders {
    transition, create_manual_order, submit_order, approve_order, reject_order, dispatch_order,
    cancel_order, deliver_order, pack_order, get_order, apply_order_action
}
import from domain.audit { list_audit_events }
import from domain.order_input { OrderItemInput }
import from domain.errors { DomainError }
import from tests.helpers { code_of }

def setup(stock: int = 10) -> Business {
    biz = Business(name="T");
    create_product(biz, sku="RINA-1L-CTN", name="Rina 1L Carton", brand="Rina", category="Oil", unit="carton", price_kes=2800);
    create_customer(biz, name="Mama Wanjiku Shop", phone="0700000001");
    adjust_inventory(biz, "RINA-1L-CTN", stock, "opening stock");
    return biz;
}

def pending(biz: Business, qty: int) -> str {
    order = create_manual_order(biz, "C-001", [OrderItemInput(sku="RINA-1L-CTN", quantity=qty)]);
    submit_order(biz, order.order_id);
    return order.order_id;
}

def stock(biz: Business) -> tuple[int, int, int] {
    rec = inventory_of(get_product(biz, "RINA-1L-CTN"));
    return (rec.quantity_on_hand, rec.quantity_reserved, rec.available());
}

test "happy path transitions" {
    o = Order(order_id="X", customer_id="C", created_at="t");
    for s in ["QUOTED", "PENDING_APPROVAL", "APPROVED", "PACKED", "DISPATCHED", "DELIVERED"] {
        transition(o, s);
        assert o.status == s;
    }
}

test "branch transitions" {
    a = Order(order_id="A", customer_id="C", created_at="t", status="PENDING_APPROVAL");
    transition(a, "REJECTED");
    b = Order(order_id="B", customer_id="C", created_at="t");
    transition(b, "CANCELLED");
    c = Order(order_id="C", customer_id="C", created_at="t", status="QUOTED");
    transition(c, "EXPIRED");
    d = Order(order_id="D", customer_id="C", created_at="t", status="APPROVED");
    transition(d, "CANCELLED");
    assert [a.status, b.status, c.status, d.status] == ["REJECTED", "CANCELLED", "EXPIRED", "CANCELLED"];
}

test "disallowed transitions raise INVALID_ORDER_STATE and change nothing" {
    o1 = Order(order_id="A", customer_id="C", created_at="t");
    with testraises(DomainError) as e1 { transition(o1, "APPROVED"); }
    assert code_of(e1.value) == "INVALID_ORDER_STATE";
    o2 = Order(order_id="B", customer_id="C", created_at="t", status="DISPATCHED");
    with testraises(DomainError) as e2 { transition(o2, "CANCELLED"); }
    assert code_of(e2.value) == "INVALID_ORDER_STATE" and o2.status == "DISPATCHED";
}

test "approve reserves stock" {
    biz = setup(10);
    oid = pending(biz, 5);
    approve_order(biz, oid);
    assert get_order(biz, oid).status == "APPROVED" and stock(biz) == (10, 5, 5);
}

test "approve with insufficient stock changes nothing" {
    biz = setup(3);
    oid = pending(biz, 5);
    with testraises(DomainError) as e { approve_order(biz, oid); }
    assert code_of(e.value) == "INSUFFICIENT_STOCK";
    assert stock(biz) == (3, 0, 3) and get_order(biz, oid).status == "PENDING_APPROVAL";
}

test "approving twice reserves once" {
    biz = setup(10);
    oid = pending(biz, 5);
    approve_order(biz, oid);
    with testraises(DomainError) as e { approve_order(biz, oid); }
    assert code_of(e.value) == "INVALID_ORDER_STATE" and stock(biz) == (10, 5, 5);
}

test "reject leaves inventory unchanged" {
    biz = setup(10);
    oid = pending(biz, 5);
    reject_order(biz, oid, "out of credit");
    assert get_order(biz, oid).status == "REJECTED" and stock(biz) == (10, 0, 10);
}

test "dispatch deducts on hand and reserved; twice deducts once" {
    biz = setup(10);
    oid = pending(biz, 5);
    approve_order(biz, oid);
    dispatch_order(biz, oid);
    assert stock(biz) == (5, 0, 5) and get_order(biz, oid).status == "DISPATCHED";
    with testraises(DomainError) as e { dispatch_order(biz, oid); }
    assert code_of(e.value) == "INVALID_ORDER_STATE" and stock(biz) == (5, 0, 5);
    deliver_order(biz, oid);
    assert get_order(biz, oid).status == "DELIVERED";
}

test "cancel releases a reservation but not after dispatch" {
    biz = setup(10);
    a = pending(biz, 5);
    approve_order(biz, a);
    cancel_order(biz, a);
    assert stock(biz) == (10, 0, 10) and get_order(biz, a).status == "CANCELLED";
    b = pending(biz, 5);
    approve_order(biz, b);
    dispatch_order(biz, b);
    with testraises(DomainError) as e { cancel_order(biz, b); }
    assert code_of(e.value) == "INVALID_ORDER_STATE" and stock(biz) == (5, 0, 5);
}

test "two orders racing for the same stock: exactly one wins" {
    biz = setup(5);
    a = pending(biz, 5);
    b = pending(biz, 5);
    approve_order(biz, a);
    with testraises(DomainError) as e { approve_order(biz, b); }
    assert code_of(e.value) == "INSUFFICIENT_STOCK" and stock(biz) == (5, 5, 0);
    assert get_order(biz, b).status == "PENDING_APPROVAL";
}

test "multi-line approval is all or nothing" {
    biz = setup(10);
    create_product(biz, sku="JOGOO-2KG-BALE", name="Jogoo", brand="", category="Flour", unit="bale", price_kes=1450);
    adjust_inventory(biz, "JOGOO-2KG-BALE", 1, "opening");
    order = create_manual_order(biz, "C-001", [
        OrderItemInput(sku="RINA-1L-CTN", quantity=5), OrderItemInput(sku="JOGOO-2KG-BALE", quantity=2)
    ]);
    submit_order(biz, order.order_id);
    with testraises(DomainError) as e { approve_order(biz, order.order_id); }
    assert code_of(e.value) == "INSUFFICIENT_STOCK" and stock(biz) == (10, 0, 10);
    assert inventory_of(get_product(biz, "JOGOO-2KG-BALE")).quantity_reserved == 0;
}

test "approval audit event has actor and before/after; stock and price changes are audited" {
    biz = setup(10);
    oid = pending(biz, 5);
    approve_order(biz, oid, "amon");
    events = [e for e in list_audit_events(biz) if e.operation == "ORDER_APPROVED"];
    assert len(events) == 1;
    assert (events[0].actor, events[0].entity, events[0].before, events[0].after) == ("amon", oid, "PENDING_APPROVAL", "APPROVED");
    update_product(biz, "RINA-1L-CTN", price_kes=3000);
    update_product(biz, "RINA-1L-CTN", name="Rina 1L Carton");
    ops = [(e.operation, e.before, e.after) for e in list_audit_events(biz)];
    assert ("STOCK_ADJUSTED", "0", "10") in ops and ("PRICE_CHANGED", "2800", "3000") in ops;
    assert len([o for o in ops if o[0] == "PRICE_CHANGED"]) == 1;
}

test "apply_order_action dispatches and rejects unknown actions" {
    biz = setup(10);
    order = create_manual_order(biz, "C-001", [OrderItemInput(sku="RINA-1L-CTN", quantity=2)]);
    apply_order_action(biz, order.order_id, "submit");
    apply_order_action(biz, order.order_id, "approve");
    assert get_order(biz, order.order_id).status == "APPROVED";
    with testraises(DomainError) as e { apply_order_action(biz, order.order_id, "explode"); }
    assert code_of(e.value) == "VALIDATION_ERROR";
}
