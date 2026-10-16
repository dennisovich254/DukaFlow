"""Tell the customer, in their chat, when the wholesaler changes the status of their order."""

import from domain.models { Business, Order }
import from domain.messaging { get_or_create_conversation, list_messages, record_outbound }
import from ai.replies { lang_of, order_update }

glob NOTIFY_STATUSES: list[str] = ["APPROVED", "REJECTED", "PACKED", "DISPATCHED", "DELIVERED", "CANCELLED"];

def notify_order_update(biz: Business, order: Order) {
    if order.channel != "shop_chat" or order.status not in NOTIFY_STATUSES { return; }
    conv = get_or_create_conversation(biz, order.customer_id);
    words = " ".join([m.content for m in list_messages(conv) if m.sender_type == "customer"][-3:]);
    record_outbound(biz, order.customer_id, order_update(lang_of(words), order.order_id, order.status, order.total_kes));
}
