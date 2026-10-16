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

obj OrderActionInput {
    has order_id: str,
        action: str,
        reason: str = "";
}

obj DashboardSummaryView {
    has orders_today: int,
        pending_approval: int,
        low_stock_count: int,
        recent_orders: list[OrderView],
        ai_mode: str = "live";
}

"""One chat message as shown in either chat UI."""
obj MessageView {
    has seq: int,
        sender_type: str,
        message_type: str,
        content: str,
        created_at: str,
        media_ref: str = "",
        client_message_id: str = "";
}

obj ChatResult {
    has ok: bool,
        messages: list[MessageView] = [],
        error: ApiError | None = None;
}

"""Public (customer) chat input: identified only by the invite token."""
obj ChatInput {
    has invite: str,
        client_message_id: str,
        text: str = "",
        photo_base64: str = "",
        photo_mime_type: str = "",
        photo_name: str = "";
}

obj ConversationQuery {
    has invite: str,
        after_seq: int = 0;
}

obj ImageQuery {
    has invite: str,
        media_ref: str;
}

obj ImageResult {
    has ok: bool,
        data_url: str = "",
        error: ApiError | None = None;
}

obj ChatSessionQuery {
    has invite: str;
}

obj ChatSessionResult {
    has ok: bool,
        business_name: str = "",
        customer_name: str = "",
        error: ApiError | None = None;
}

"""Wholesaler-side reads of a conversation (login required, keyed by customer id)."""
obj StaffConversationQuery {
    has customer_id: str,
        after_seq: int = 0;
}

obj StaffImageQuery {
    has customer_id: str,
        media_ref: str;
}

obj InviteQuery {
    has customer_id: str;
}

obj InviteResult {
    has ok: bool,
        token: str = "",
        error: ApiError | None = None;
}

obj RevokeResult {
    has ok: bool,
        revoked: int = 0,
        error: ApiError | None = None;
}

obj ConversationSummaryView {
    has customer_id: str,
        customer_name: str,
        last_message: str,
        last_at: str,
        message_count: int;
}
