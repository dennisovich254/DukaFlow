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
