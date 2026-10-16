"""Wire contracts shared by server endpoints and client pages.

Kept free of server imports so client pages can import these types without
pulling server modules into the browser bundle. Money is integer whole KSh.
"""

import from domain.order_input { OrderItemInput }

obj ApiError {
    has code: str,
        message: str;
}

"""Product as returned to clients, including current stock levels."""
obj ProductView {
    has sku: str,
        name: str,
        brand: str,
        category: str,
        unit: str,
        price_kes: int,
        aliases: list[str],
        active: bool,
        quantity_on_hand: int,
        quantity_reserved: int,
        quantity_available: int;
}

obj ProductResult {
    has ok: bool,
        product: ProductView | None = None,
        error: ApiError | None = None;
}

"""Money and quantities are typed `any` so a fractional value reaches domain
validation instead of being silently truncated by an `int` parameter."""
obj NewProductInput {
    has sku: str,
        name: str,
        unit: str,
        price_kes: any,
        brand: str = "",
        category: str = "",
        aliases: list[str] | None = None;
}

obj EditProductInput {
    has sku: str,
        name: str | None = None,
        brand: str | None = None,
        category: str | None = None,
        unit: str | None = None,
        price_kes: any = None,
        aliases: list[str] | None = None,
        active: bool | None = None;
}

obj AdjustStockInput {
    has sku: str,
        quantity_change: any,
        reason: str;
}

obj CatalogueQuery {
    has include_inactive: bool = False;
}

obj CustomerView {
    has customer_id: str,
        name: str,
        phone: str;
}

obj CustomerResult {
    has ok: bool,
        customer: CustomerView | None = None,
        error: ApiError | None = None;
}

obj NewCustomerInput {
    has name: str,
        phone: str;
}

obj OrderLineView {
    has product_sku: str,
        product_name: str,
        quantity: int,
        unit: str,
        unit_price_kes: int,
        line_total_kes: int;
}

obj OrderView {
    has order_id: str,
        customer_id: str,
        customer_name: str,
        status: str,
        channel: str,
        created_at: str,
        total_kes: int,
        lines: list[OrderLineView];
}

obj OrderResult {
    has ok: bool,
        order: OrderView | None = None,
        error: ApiError | None = None;
}

obj NewOrderInput {
    has customer_id: str,
        items: list[OrderItemInput];
}

obj OrderLookup {
    has order_id: str;
}
