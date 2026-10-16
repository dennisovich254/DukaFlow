"""Quotations: a priced proposal the customer confirms before an order exists.
Prices, stock figures and totals come from here, never from a language model."""

import from domain.models {
    Business, Conversation, Quotation, QuotationLine, Order, HasQuotation, QuoteContains
}
import from domain.errors { DomainError }
import from domain.catalogue { list_products, find_product, inventory_of }
import from domain.pricing { calculate_line_total, validate_quantity, format_kes }
import from domain.messaging { get_or_create_conversation }
import from domain.orders { create_order_from_lines, OrderLineSpec }
import from domain.clock { now_iso, now_iso_precise, iso_in_hours }

glob QUOTE_TTL_HOURS: int = 24;

obj RequestedLine {
    has sku: str,
        quantity: int;
}

"""Why a line differs from what the customer asked for."""
obj PlanNote {
    has kind: str,
        sku: str,
        name: str,
        wanted: int,
        available: int,
        alt_sku: str = "",
        alt_name: str = "",
        alt_qty: int = 0,
        alt_price: int = 0;
}

"""One English sentence for the wholesaler about why a line differs from the request."""
def staff_note(n: PlanNote) -> str {
    if n.kind == "UNAVAILABLE" { return f"{n.name}: wanted {n.wanted}, out of stock."; }
    if n.alt_sku != "" {
        return f"{n.name}: wanted {n.wanted}, only {n.available} available; added {n.alt_qty} × {n.alt_name} ({format_kes(n.alt_price)}) for the rest.";
    }
    return f"{n.name}: wanted {n.wanted}, only {n.available} available.";
}

obj QuotePlan {
    has lines: list[RequestedLine] = [],
        notes: list[PlanNote] = [];
}

"""In-stock substitutes in the same category with enough units: (sku, name, available, price)."""
def alternative_for(biz: Business, sku: str, quantity: int) -> list[tuple[str, str, int, int]] {
    base = find_product(biz, sku);
    if base is None { return []; }
    base_price = base.price_kes;
    options: list[tuple[str, str, int, int]] = [];
    for p in list_products(biz) {
        if p.sku == base.sku or p.category != base.category { continue; }
        avail = inventory_of(p).available();
        if avail >= quantity {
            options.append((p.sku, p.name, avail, p.price_kes));
        }
    }
    return sorted(options, key=lambda (o: tuple[str, str, int, int]) { abs(o[3] - base_price); });
}

"""Turn what the customer asked for into what can be supplied. A shortage never changes
the order silently: the plan records a note, and the customer must confirm the result."""
def plan_quote(biz: Business, requested: list[RequestedLine]) -> QuotePlan {
    plan = QuotePlan();
    totals: dict[str, int] = {};
    for r in requested {
        qty = validate_quantity(r.quantity);
        product = find_product(biz, r.sku);
        if product is None or not product.active {
            raise DomainError(code="PRODUCT_NOT_FOUND", message=f"No orderable product {r.sku}");
        }
        avail = inventory_of(product).available();
        if avail >= qty {
            totals[product.sku] = totals.get(product.sku, 0) + qty;
            continue;
        }
        remaining = qty - max(avail, 0);
        if avail > 0 { totals[product.sku] = totals.get(product.sku, 0) + avail; }
        alts = alternative_for(biz, product.sku, remaining);
        if alts {
            a = alts[0];
            totals[a[0]] = totals.get(a[0], 0) + remaining;
            plan.notes.append(PlanNote(
                kind="SHORT", sku=product.sku, name=product.name, wanted=qty, available=max(avail, 0),
                alt_sku=a[0], alt_name=a[1], alt_qty=remaining, alt_price=a[3]
            ));
        } else {
            plan.notes.append(PlanNote(
                kind="SHORT" if avail > 0 else "UNAVAILABLE", sku=product.sku, name=product.name,
                wanted=qty, available=max(avail, 0)
            ));
        }
    }
    plan.lines = [RequestedLine(sku=sku, quantity=q) for (sku, q) in totals.items()];
    return plan;
}

def is_expired(q: Quotation) -> bool {
    return q.expires_at < now_iso();
}

def quotation_lines(q: Quotation) -> list[QuotationLine] {
    return sorted([q ->:QuoteContains:->], key=lambda (l: QuotationLine) { l.product_name; });
}

"""Create an OPEN quotation from a plan, snapshotting catalogue prices. Stock is not touched."""
def build_quotation(biz: Business, customer_id: str, plan: QuotePlan, status: str = "OPEN") -> Quotation {
    conv = get_or_create_conversation(biz, customer_id);
    if not plan.lines {
        raise DomainError(code="VALIDATION_ERROR", message="A quotation needs at least one line");
    }
    for old in [conv ->:HasQuotation:->] {
        if old.status in ["OPEN", "DRAFT"] { old.status = "CANCELLED"; }
    }
    q = Quotation(
        quote_id=f"Q-{biz.next_quote_number}", customer_id=customer_id, status=status,
        created_at=now_iso_precise(), expires_at=iso_in_hours(QUOTE_TTL_HOURS),
        notes=[staff_note(n) for n in plan.notes]
    );
    total = 0;
    for r in plan.lines {
        product = find_product(biz, r.sku);
        if product is None { raise DomainError(code="PRODUCT_NOT_FOUND", message=f"No product {r.sku}"); }
        line_total = calculate_line_total(product.price_kes, r.quantity);
        q +>:QuoteContains():+> QuotationLine(
            product_sku=product.sku, product_name=product.name, quantity=r.quantity,
            unit=product.unit, unit_price_kes=product.price_kes, line_total_kes=line_total
        );
        total += line_total;
    }
    q.total_kes = total;
    biz.next_quote_number += 1;
    conv +>:HasQuotation():+> q;
    return q;
}

"""The newest quotation for a customer, or None."""
def latest_quotation(biz: Business, customer_id: str) -> Quotation | None {
    conv = get_or_create_conversation(biz, customer_id);
    quotes = sorted([conv ->:HasQuotation:->], key=lambda (q: Quotation) { q.created_at; });
    return quotes[-1] if quotes else None;
}

def cancel_open_quotation(biz: Business, customer_id: str) -> bool {
    q = latest_quotation(biz, customer_id);
    if q is None or q.status != "OPEN" { return False; }
    q.status = "CANCELLED";
    return True;
}

"""Confirm the open quotation: creates exactly one PENDING_APPROVAL order, at the quoted prices."""
def confirm_quotation(biz: Business, customer_id: str) -> Order {
    q = latest_quotation(biz, customer_id);
    if q is None or q.status != "OPEN" {
        raise DomainError(code="NO_OPEN_QUOTE", message="There is no open quotation to confirm");
    }
    if is_expired(q) {
        q.status = "EXPIRED";
        raise DomainError(code="QUOTE_EXPIRED", message=f"Quotation {q.quote_id} has expired");
    }
    specs = [
        OrderLineSpec(sku=l.product_sku, name=l.product_name, quantity=l.quantity, unit=l.unit, unit_price_kes=l.unit_price_kes)
        for l in quotation_lines(q)
    ];
    order = create_order_from_lines(biz, customer_id, specs, "shop_chat", "agent", q.quote_id);
    q.status = "CONFIRMED";
    return order;
}
