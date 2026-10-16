"""Authenticated order endpoints."""

import from domain.models { Order, ContainsLine }
import from domain.errors { DomainError }
import from domain.orders { create_manual_order, list_orders, get_order, apply_order_action }
import from domain.customers { find_customer }
import from ai.notify { notify_order_update }
import from api.business { current_business }
import from api.results { to_api_error }
import from api.contracts { OrderLineView, OrderView, OrderResult, NewOrderInput, OrderLookup, OrderActionInput }

def order_view(biz: any, o: Order) -> OrderView {
    customer = find_customer(biz, o.customer_id);
    return OrderView(
        order_id=o.order_id,
        customer_id=o.customer_id,
        customer_name=customer.name if customer else o.customer_id,
        status=o.status,
        channel=o.channel,
        created_at=o.created_at,
        total_kes=o.total_kes,
        lines=[
            OrderLineView(
                product_sku=l.product_sku, product_name=l.product_name, quantity=l.quantity,
                unit=l.unit, unit_price_kes=l.unit_price_kes, line_total_kes=l.line_total_kes
            )
            for l in sorted([o ->:ContainsLine:->], key=lambda (x: any) { x.product_name; })
        ]
    );
}

def:protect list_order_records() -> list[OrderView] {
    biz = current_business();
    return [order_view(biz, o) for o in list_orders(biz)];
}

def:protect get_order_record(query: OrderLookup) -> OrderResult {
    try {
        biz = current_business();
        return OrderResult(ok=True, order=order_view(biz, get_order(biz, query.order_id)));
    } except DomainError as e {
        return OrderResult(ok=False, error=to_api_error(e));
    }
}

def:protect create_order(data: NewOrderInput) -> OrderResult {
    try {
        biz = current_business();
        order = create_manual_order(biz, data.customer_id, data.items);
        return OrderResult(ok=True, order=order_view(biz, order));
    } except DomainError as e {
        return OrderResult(ok=False, error=to_api_error(e));
    }
}

def:protect act_on_order(data: OrderActionInput) -> OrderResult {
    try {
        biz = current_business();
        order = apply_order_action(biz, data.order_id, data.action, data.reason);
        notify_order_update(biz, order);
        return OrderResult(ok=True, order=order_view(biz, order));
    } except DomainError as e {
        return OrderResult(ok=False, error=to_api_error(e));
    }
}
