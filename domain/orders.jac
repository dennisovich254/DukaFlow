"""Order creation and lookup. Line prices are captured from the catalogue at order
time, and every total comes from domain.pricing."""

import from domain.models {
    Business, Order, OrderLine, Product, HasOrder, PlacedOrder, ContainsLine, ReferencesProduct
}
import from domain.errors { DomainError }
import from domain.catalogue { find_product, normalise_sku }
import from domain.customers { get_customer }
import from domain.pricing { calculate_line_total, validate_quantity }
import from domain.clock { now_iso }
import from domain.order_input { OrderItemInput }
import from domain.inventory { apply_stock_change }
import from domain.audit { record_audit_event }

glob TRANSITIONS: dict[str, list[str]] = {
    "DRAFT": ["QUOTED", "CANCELLED"],
    "QUOTED": ["PENDING_APPROVAL", "EXPIRED", "CANCELLED"],
    "PENDING_APPROVAL": ["APPROVED", "REJECTED"],
    "APPROVED": ["PACKED", "DISPATCHED", "CANCELLED"],
    "PACKED": ["DISPATCHED", "CANCELLED"],
    "DISPATCHED": ["DELIVERED"],
    "DELIVERED": [],
    "REJECTED": [],
    "CANCELLED": [],
    "EXPIRED": []
};

def require_orderable(biz: Business, sku: str) -> Product {
    product = find_product(biz, sku);
    if product is None or not product.active {
        raise DomainError(code="PRODUCT_NOT_FOUND", message=f"No orderable product {sku}");
    }
    return product;
}

"""Validate every line before writing anything, merging repeated SKUs."""
def create_manual_order(biz: Business, customer_id: str, items: list[OrderItemInput]) -> Order {
    customer = get_customer(biz, customer_id);
    if not items {
        raise DomainError(code="VALIDATION_ERROR", message="An order needs at least one item");
    }
    quantities: dict[str, int] = {};
    products: dict[str, Product] = {};
    for item in items {
        sku = normalise_sku(item.sku);
        products[sku] = require_orderable(biz, sku);
        quantities[sku] = quantities.get(sku, 0) + validate_quantity(item.quantity);
    }
    order = Order(
        order_id=f"ORD-{biz.next_order_number}",
        customer_id=customer.customer_id,
        created_at=now_iso()
    );
    total = 0;
    for (sku, quantity) in quantities.items() {
        product = products[sku];
        line_total = calculate_line_total(product.price_kes, quantity);
        line = OrderLine(
            product_sku=sku, product_name=product.name, quantity=quantity, unit=product.unit,
            unit_price_kes=product.price_kes, line_total_kes=line_total
        );
        order +>:ContainsLine():+> line;
        line +>:ReferencesProduct():+> product;
        total += line_total;
    }
    order.total_kes = total;
    biz.next_order_number += 1;
    biz +>:HasOrder():+> order;
    customer +>:PlacedOrder():+> order;
    return order;
}

def order_number(order: Order) -> int {
    return int(order.order_id.split("-")[-1]);
}

def list_orders(biz: Business) -> list[Order] {
    return sorted([biz ->:HasOrder:->], key=lambda (o: Order) { -order_number(o); });
}

def get_order(biz: Business, order_id: str) -> Order {
    for o in [biz ->:HasOrder:->] {
        if o.order_id == order_id { return o; }
    }
    raise DomainError(code="ORDER_NOT_FOUND", message=f"No order {order_id}");
}

"""The single place an order's status changes. Raises INVALID_ORDER_STATE otherwise."""
def transition(order: Order, new_status: str) -> Order {
    if new_status not in TRANSITIONS.get(order.status, []) {
        raise DomainError(
            code="INVALID_ORDER_STATE",
            message=f"{order.order_id}: cannot go from {order.status} to {new_status}"
        );
    }
    order.status = new_status;
    return order;
}

def order_lines(order: Order) -> list[OrderLine] {
    return [order ->:ContainsLine:->];
}

def line_product(line: OrderLine) -> Product {
    return [line ->:ReferencesProduct:->][0];
}

def change_status(biz: Business, order: Order, new_status: str, actor: str, detail: str = "") {
    before = order.status;
    transition(order, new_status);
    record_audit_event(biz, actor, "ORDER_" + new_status, order.order_id, before, new_status, detail);
}

"""Manual orders are wholesaler-entered, so quoting and customer confirmation are implicit."""
def submit_order(biz: Business, order_id: str, actor: str = "wholesaler") -> Order {
    order = get_order(biz, order_id);
    change_status(biz, order, "QUOTED", actor);
    change_status(biz, order, "PENDING_APPROVAL", actor);
    return order;
}

"""Move stock for every line of an order through the single inventory writer.
Each line is rechecked immediately before it is written; if any line fails, lines
already applied are reversed, so an order reserves fully or not at all."""
def move_order_stock(order: Order, on_hand_sign: int, reserved_sign: int, movement_type: str) {
    done: list[OrderLine] = [];
    try {
        for line in order_lines(order) {
            apply_stock_change(
                line_product(line), on_hand_sign * line.quantity, reserved_sign * line.quantity,
                movement_type, order.order_id, order.order_id
            );
            done.append(line);
        }
    } except DomainError as e {
        for l in done {
            apply_stock_change(
                line_product(l), -on_hand_sign * l.quantity, -reserved_sign * l.quantity,
                "ROLLBACK", order.order_id, order.order_id
            );
        }
        raise e;
    }
}

def require_status(order: Order, allowed: list[str], verb: str) {
    if order.status not in allowed {
        raise DomainError(code="INVALID_ORDER_STATE", message=f"{order.order_id}: cannot {verb} from {order.status}");
    }
}

def approve_order(biz: Business, order_id: str, actor: str = "wholesaler") -> Order {
    order = get_order(biz, order_id);
    require_status(order, ["PENDING_APPROVAL"], "approve");
    move_order_stock(order, 0, 1, "RESERVE");
    change_status(biz, order, "APPROVED", actor);
    return order;
}

def reject_order(biz: Business, order_id: str, reason: str, actor: str = "wholesaler") -> Order {
    order = get_order(biz, order_id);
    change_status(biz, order, "REJECTED", actor, reason.strip());
    return order;
}

def pack_order(biz: Business, order_id: str, actor: str = "wholesaler") -> Order {
    order = get_order(biz, order_id);
    change_status(biz, order, "PACKED", actor);
    return order;
}

"""Dispatch turns the reservation into a stock deduction."""
def dispatch_order(biz: Business, order_id: str, actor: str = "wholesaler") -> Order {
    order = get_order(biz, order_id);
    require_status(order, ["APPROVED", "PACKED"], "dispatch");
    move_order_stock(order, -1, -1, "DISPATCH");
    change_status(biz, order, "DISPATCHED", actor);
    return order;
}

def deliver_order(biz: Business, order_id: str, actor: str = "wholesaler") -> Order {
    order = get_order(biz, order_id);
    change_status(biz, order, "DELIVERED", actor);
    return order;
}

"""Cancelling an order that holds a reservation releases it."""
def cancel_order(biz: Business, order_id: str, actor: str = "wholesaler") -> Order {
    order = get_order(biz, order_id);
    require_status(order, ["DRAFT", "QUOTED", "APPROVED", "PACKED"], "cancel");
    if order.status in ["APPROVED", "PACKED"] {
        move_order_stock(order, 0, -1, "RELEASE");
    }
    change_status(biz, order, "CANCELLED", actor);
    return order;
}

"""Dispatch table for the dashboard buttons."""
def apply_order_action(
    biz: Business, order_id: str, action: str, reason: str = "", actor: str = "wholesaler"
) -> Order {
    if action == "submit" { return submit_order(biz, order_id, actor); }
    if action == "approve" { return approve_order(biz, order_id, actor); }
    if action == "reject" { return reject_order(biz, order_id, reason, actor); }
    if action == "pack" { return pack_order(biz, order_id, actor); }
    if action == "dispatch" { return dispatch_order(biz, order_id, actor); }
    if action == "deliver" { return deliver_order(biz, order_id, actor); }
    if action == "cancel" { return cancel_order(biz, order_id, actor); }
    raise DomainError(code="VALIDATION_ERROR", message=f"Unknown order action {action}");
}

obj OrderLineSpec {
    has sku: str,
        name: str,
        quantity: int,
        unit: str,
        unit_price_kes: int;
}

"""Create an order from explicit lines (a confirmed quotation), keeping the quoted prices.
Chat orders enter the approval queue as PENDING_APPROVAL."""
def create_order_from_lines(
    biz: Business, customer_id: str, specs: list[OrderLineSpec], channel: str, actor: str
) -> Order {
    customer = get_customer(biz, customer_id);
    if not specs {
        raise DomainError(code="VALIDATION_ERROR", message="An order needs at least one item");
    }
    order = Order(
        order_id=f"ORD-{biz.next_order_number}", customer_id=customer.customer_id,
        created_at=now_iso(), channel=channel
    );
    total = 0;
    for spec in specs {
        line_total = calculate_line_total(spec.unit_price_kes, spec.quantity);
        line = OrderLine(
            product_sku=spec.sku, product_name=spec.name, quantity=spec.quantity, unit=spec.unit,
            unit_price_kes=spec.unit_price_kes, line_total_kes=line_total
        );
        order +>:ContainsLine():+> line;
        product = find_product(biz, spec.sku);
        if product is not None { line +>:ReferencesProduct():+> product; }
        total += line_total;
    }
    order.total_kes = total;
    biz.next_order_number += 1;
    biz +>:HasOrder():+> order;
    customer +>:PlacedOrder():+> order;
    return submit_order(biz, order.order_id, actor);
}
