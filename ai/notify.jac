"""Tell the customer, in their chat, when the wholesaler changes the status of their order."""

import from domain.models { Business, Order }
import from domain.messaging { get_or_create_conversation, list_messages, record_outbound }
import from ai.replies { detect_lang, order_update }

glob NOTIFY_STATUSES: list[str] = ["APPROVED", "REJECTED", "PACKED", "DISPATCHED", "DELIVERED", "CANCELLED"];

def notify_order_update(biz: Business, order: Order) {
    if order.channel != "shop_chat" or order.status not in NOTIFY_STATUSES { return; }
    conv = get_or_create_conversation(biz, order.customer_id);
    texts = [m.content for m in list_messages(conv) if m.sender_type == "customer" and m.content];
    texts.reverse();
    record_outbound(biz, order.customer_id, order_update(detect_lang(texts), order.order_id, order.status, order.total_kes));
}
