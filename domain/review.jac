"""What the wholesaler needs to review a chat order: the customer's messages, the quotation
notes and the agent's steps; plus a feed of recent agent activity for the dashboard."""

import from domain.models {
    Business, Order, Message, Quotation, AgentExecution, HasConversation, HasExecution, HasQuotation
}
import from domain.messaging { find_conversation, list_messages }
import from domain.customers { find_customer }
import from domain.orders { get_order }

obj ReviewContext {
    has order: Order,
        quote_notes: list[str],
        messages: list[Message],
        executions: list[AgentExecution];
}

obj ActivityItem {
    has customer_id: str,
        customer_name: str,
        execution: AgentExecution;
}

def get_review_context(biz: Business, order_id: str) -> ReviewContext {
    order = get_order(biz, order_id);
    notes: list[str] = [];
    messages: list[Message] = [];
    executions: list[AgentExecution] = [];
    if order.channel == "shop_chat" {
        conv = find_conversation(biz, order.customer_id);
        if conv is not None {
            for q in [conv ->:HasQuotation:->] {
                if q.quote_id == order.quote_id { notes = q.notes; }
            }
            upto = order.source_seq if order.source_seq > 0 else 1000000;
            messages = [m for m in list_messages(conv) if m.seq <= upto][-8:];
            seqs = [m.seq for m in messages];
            executions = sorted(
                [e for e in [conv ->:HasExecution:->] if e.message_seq in seqs],
                key=lambda (e: AgentExecution) { e.message_seq; }
            );
        }
    }
    return ReviewContext(order=order, quote_notes=notes, messages=messages, executions=executions);
}

"""The newest agent runs across all conversations."""
def recent_activity(biz: Business, limit: int = 10) -> list[ActivityItem] {
    items: list[ActivityItem] = [];
    for conv in [biz ->:HasConversation:->] {
        customer = find_customer(biz, conv.customer_id);
        name = customer.name if customer else conv.customer_id;
        for e in [conv ->:HasExecution:->] {
            items.append(ActivityItem(customer_id=conv.customer_id, customer_name=name, execution=e));
        }
    }
    items = sorted(items, key=lambda (i: ActivityItem) { i.execution.created_at; });
    items.reverse();
    return items[:limit];
}
