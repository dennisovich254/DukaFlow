"""Core DukaFlow domain graph: nodes and typed edges.

All money fields are integer whole Kenyan shillings (`_kes` suffix).
The graph lives on root.shared and every type is open at the framework level
(see SharedNode); the endpoints enforce who may touch what.
"""

"""Framework-level access policy. Jac isolates each user's graph by default; the
business graph lives on root.shared so both the signed-in wholesaler and the
anonymous customer chat (invite link) can reach it. Opening the types to WRITE
is a deliberate trade-off: every endpoint enforces access (docs/security.md)."""
node SharedNode {
    def __jac_access__ -> AccessLevel {
        return AccessLevel.WRITE;
    }
}

edge SharedEdge: any --> any {
    def __jac_access__ -> AccessLevel {
        return AccessLevel.WRITE;
    }
}

"""Anchor node for one wholesale business; found by its owner's root id."""
node Business(SharedNode) {
    has name: str,
        phone: str = "",
        next_customer_number: int = 1,
        next_order_number: int = 1001,
        next_quote_number: int = 1001,
        owner_root_id: str = "";
}

"""Something the business sells, in one packaging unit (e.g. a carton)."""
node Product(SharedNode) {
    has sku: str,
        name: str,
        brand: str,
        category: str,
        unit: str,
        price_kes: int,
        aliases: list[str] = [],
        active: bool = True;
}

"""Stock levels for one product, kept separate because they change far more often."""
node InventoryRecord(SharedNode) {
    has quantity_on_hand: int = 0,
        quantity_reserved: int = 0;

    def available -> int {
        return self.quantity_on_hand - self.quantity_reserved;
    }
}

"""An immutable record of one stock change."""
node InventoryMovement(SharedNode) {
    has movement_type: str,
        quantity: int,
        reason: str,
        created_at: str,
        reference: str = "";
}

"""A retailer who buys from the business."""
node Customer(SharedNode) {
    has customer_id: str,
        name: str,
        phone: str = "",
        active: bool = True;
}

"""A customer order. Status changes go through domain.orders only."""
node Order(SharedNode) {
    has order_id: str,
        customer_id: str,
        created_at: str,
        status: str = "DRAFT",
        channel: str = "manual",
        total_kes: int = 0,
        quote_id: str = "",
        source_seq: int = 0;
}

"""One product line on an order, with the price captured at order time."""
node OrderLine(SharedNode) {
    has product_sku: str,
        product_name: str,
        quantity: int,
        unit: str,
        unit_price_kes: int,
        line_total_kes: int;
}

edge HasBusiness(SharedEdge): Root --> Business {}
edge OwnsProduct(SharedEdge): Business --> Product {}
edge HasInventory(SharedEdge): Product --> InventoryRecord {}
edge HasMovement(SharedEdge): Product --> InventoryMovement {}
edge ServesCustomer(SharedEdge): Business --> Customer {}
edge HasOrder(SharedEdge): Business --> Order {}
edge PlacedOrder(SharedEdge): Customer --> Order {}
edge ContainsLine(SharedEdge): Order --> OrderLine {}
edge ReferencesProduct(SharedEdge): OrderLine --> Product {}

"""An immutable record of who did what, with before/after values."""
node AuditEvent(SharedNode) {
    has actor: str,
        operation: str,
        entity: str,
        before: str,
        after: str,
        created_at: str,
        detail: str = "";
}

edge HasAudit(SharedEdge): Business --> AuditEvent {}

"""One chat thread per customer, whatever the channel."""
node Conversation(SharedNode) {
    has customer_id: str,
        created_at: str,
        next_seq: int = 1,
        flagged: bool = False,
        flag_reason: str = "";
}

"""A single chat message, inbound from the retailer or outbound from the agent."""
node Message(SharedNode) {
    has seq: int,
        client_message_id: str,
        sender_type: str,
        channel: str,
        message_type: str,
        content: str,
        created_at: str,
        media_ref: str = "",
        media_mime_type: str = "";
}

edge HasConversation(SharedEdge): Business --> Conversation {}
edge ContainsMessage(SharedEdge): Conversation --> Message {}

"""A priced proposal the customer can confirm. Prices are a snapshot taken when it is made."""
node Quotation(SharedNode) {
    has quote_id: str,
        customer_id: str,
        created_at: str,
        expires_at: str,
        status: str = "OPEN",
        total_kes: int = 0,
        notes: list[str] = [];
}

node QuotationLine(SharedNode) {
    has product_sku: str,
        product_name: str,
        quantity: int,
        unit: str,
        unit_price_kes: int,
        line_total_kes: int;
}

"""One processed customer message: what the agent did, for the dashboard trace."""
node AgentExecution(SharedNode) {
    has message_seq: int,
        input_type: str,
        outcome: str,
        duration_ms: int,
        created_at: str,
        steps: list[str] = [],
        error: str = "";
}

edge HasQuotation(SharedEdge): Conversation --> Quotation {}
edge QuoteContains(SharedEdge): Quotation --> QuotationLine {}
edge HasExecution(SharedEdge): Conversation --> AgentExecution {}

"""A tax, levy or standards notice the radar has read: shared facts, one per source item."""
node RegNotice(SharedNode) {
    has notice_id: str,
        title: str,
        source_name: str,
        url: str,
        published_on: str,
        status: str,
        effective_on: str,
        kind: str,
        summary: str,
        evidence: str,
        rate_before: str = "UNKNOWN",
        rate_after: str = "UNKNOWN",
        applies_to: str = "ALL",
        categories: list[str] = [],
        keywords: list[str] = [],
        confidence: str = "MEDIUM",
        origin: str = "SNAPSHOT",
        caveat: str = "",
        fetched_at: str = "";
}

"""What a notice means for this business, computed from its own catalogue and sales."""
node ComplianceAlert(SharedNode) {
    has alert_id: str,
        notice_id: str,
        severity: str,
        effect_text: str,
        confidence: str,
        affected_skus: list[str] = [],
        sales_30d_kes: int = 0,
        share_of_sales_pct: int = 0,
        status: str = "NEW",
        created_at: str = "";
}

"""One recommended next step for an alert. Nothing runs until the wholesaler clicks."""
node AlertAction(SharedNode) {
    has action_id: str,
        kind: str,
        title: str,
        detail: str,
        impact_kes: int = 0,
        due_on: str = "",
        payload_json: str = "{}",
        status: str = "SUGGESTED",
        done_at: str = "";
}

edge HasNotice(SharedEdge): Business --> RegNotice {}
edge HasAlert(SharedEdge): Business --> ComplianceAlert {}
edge AlertFor(SharedEdge): ComplianceAlert --> Product {}
edge HasAction(SharedEdge): ComplianceAlert --> AlertAction {}
