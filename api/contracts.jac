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

"""One agent run, for the activity panel and the order review."""
obj ExecutionView {
    has message_seq: int,
        customer_id: str,
        customer_name: str,
        input_type: str,
        outcome: str,
        duration_ms: int,
        created_at: str,
        steps: list[str];
}

"""Everything the wholesaler needs to review an order: what the customer sent, how the agent read it."""
obj ReviewView {
    has order: OrderView,
        quote_id: str,
        quote_notes: list[str],
        messages: list[MessageView],
        executions: list[ExecutionView];
}

obj ReviewResult {
    has ok: bool,
        review: ReviewView | None = None,
        error: ApiError | None = None;
}

obj DayPointView {
    has date: str,
        label: str,
        revenue_kes: int,
        orders: int;
}

obj StatusCountView {
    has status: str,
        count: int;
}

obj TopProductView {
    has sku: str,
        name: str,
        quantity: int,
        revenue_kes: int;
}

obj ChannelCountView {
    has channel: str,
        count: int;
}

obj LowStockView {
    has sku: str,
        name: str,
        available: int;
}

obj PendingView {
    has order_id: str,
        customer_name: str,
        total_kes: int,
        created_at: str;
}

"""Everything the Overview draws: series for the charts plus the headline numbers."""
obj AnalyticsView {
    has days: list[DayPointView],
        revenue_7d: int,
        revenue_prev_7d: int,
        orders_7d: int,
        avg_order_kes: int,
        status_counts: list[StatusCountView],
        top_products: list[TopProductView],
        channels: list[ChannelCountView],
        low_stock: list[LowStockView],
        pending_count: int,
        pending: list[PendingView],
        recent_orders: list[OrderView],
        customer_count: int,
        product_count: int,
        today: str,
        ai_mode: str = "live";
}

"""A draft message to one customer: shown for review and edited before it is sent."""
obj DraftMessageView {
    has customer_id: str,
        customer_name: str,
        text: str;
}

obj AffectedProductView {
    has sku: str,
        name: str,
        price_kes: int,
        unit: str;
}

"""One recommended next step. Nothing runs until the wholesaler clicks."""
obj ActionView {
    has action_id: str,
        kind: str,
        title: str,
        detail: str,
        impact_kes: int,
        due_on: str,
        status: str,
        messages: list[DraftMessageView] = [];
}

"""A notice plus what it means for this business, with its sources and actions."""
obj AlertView {
    has alert_id: str,
        title: str,
        source_name: str,
        url: str,
        published_on: str,
        notice_status: str,
        effective_on: str,
        kind: str,
        evidence: str,
        rate_before: str,
        rate_after: str,
        applies_to: str,
        origin: str,
        caveat: str,
        severity: str,
        effect_text: str,
        confidence: str,
        alert_status: str,
        sales_30d_kes: int,
        share_of_sales_pct: int,
        products: list[AffectedProductView],
        actions: list[ActionView];
}

obj RadarView {
    has alerts: list[AlertView],
        notice_count: int,
        mode: str,
        today: str;
}

obj RadarRefreshResult {
    has ok: bool,
        new_notices: int = 0,
        new_alerts: int = 0,
        skipped: int = 0,
        live_read: int = 0,
        mode: str = "snapshot",
        error: ApiError | None = None;
}

obj AnalyseInput {
    has text: str,
        title: str = "";
}

obj AnalyseResult {
    has ok: bool,
        alert_id: str = "",
        error: ApiError | None = None;
}

"""kind: apply (prices), send (messages), pause, done or skip."""
obj RadarActionInput {
    has action_id: str,
        kind: str,
        messages: list[DraftMessageView] = [];
}

obj RadarActionResult {
    has ok: bool,
        message: str = "",
        error: ApiError | None = None;
}

obj AlertLookup {
    has alert_id: str;
}
