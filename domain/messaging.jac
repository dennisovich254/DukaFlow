"""Channel-agnostic messaging. Every inbound message, from any channel, becomes an
InboundMessage before it is processed."""

import from domain.models { Business, Conversation, Message, HasConversation, ContainsMessage }
import from domain.errors { DomainError }
import from domain.customers { get_customer, find_customer }
import from domain.clock { now_iso, now_iso_precise }

glob MESSAGE_TYPES: list[str] = ["text", "image"];
glob TEXT_REPLY: str = "Karibu DukaFlow! Tuambie bidhaa unazohitaji.";
glob PHOTO_REPLY: str = "Tumepokea picha yako. Tunaishughulikia.";

obj InboundMessage {
    has customer_id: str,
        client_message_id: str,
        channel: str = "shop_chat",
        message_type: str = "text",
        content: str = "",
        media_ref: str = "",
        media_mime_type: str = "";
}

obj ConversationSummary {
    has customer_id: str,
        customer_name: str,
        last_message: str,
        last_at: str,
        message_count: int;
}

def find_conversation(biz: Business, customer_id: str) -> Conversation | None {
    for c in [biz ->:HasConversation:->] {
        if c.customer_id == customer_id { return c; }
    }
    return None;
}

"""Find or create the customer's conversation. The customer must exist."""
def get_or_create_conversation(biz: Business, customer_id: str) -> Conversation {
    customer = get_customer(biz, customer_id);
    existing = find_conversation(biz, customer.customer_id);
    if existing is not None { return existing; }
    conv = Conversation(customer_id=customer.customer_id, created_at=now_iso());
    biz +>:HasConversation():+> conv;
    return conv;
}

def list_messages(conv: Conversation, after_seq: int = 0) -> list[Message] {
    msgs = [m for m in [conv ->:ContainsMessage:->] if m.seq > after_seq];
    return sorted(msgs, key=lambda (m: Message) { m.seq; });
}

def find_message(conv: Conversation, client_message_id: str) -> Message | None {
    if not client_message_id { return None; }
    for m in [conv ->:ContainsMessage:->] {
        if m.client_message_id == client_message_id { return m; }
    }
    return None;
}

def append_message(
    conv: Conversation, client_message_id: str, sender_type: str, channel: str,
    message_type: str, content: str, media_ref: str = "", media_mime_type: str = ""
) -> Message {
    msg = Message(
        seq=conv.next_seq, client_message_id=client_message_id, sender_type=sender_type,
        channel=channel, message_type=message_type, content=content,
        media_ref=media_ref, media_mime_type=media_mime_type, created_at=now_iso_precise()
    );
    conv.next_seq += 1;
    conv +>:ContainsMessage():+> msg;
    return msg;
}

"""Store an inbound message once. A repeated client_message_id returns the message
already stored instead of adding a duplicate."""
def record_inbound(biz: Business, inbound: InboundMessage) -> Message {
    conv = get_or_create_conversation(biz, inbound.customer_id);
    if inbound.message_type not in MESSAGE_TYPES {
        raise DomainError(code="VALIDATION_ERROR", message=f"Unknown message type {inbound.message_type}");
    }
    if inbound.message_type == "text" and not inbound.content.strip() {
        raise DomainError(code="VALIDATION_ERROR", message="Message text cannot be empty");
    }
    if inbound.message_type == "image" and not inbound.media_ref {
        raise DomainError(code="VALIDATION_ERROR", message="An image message needs a stored image");
    }
    existing = find_message(conv, inbound.client_message_id);
    if existing is not None { return existing; }
    return append_message(
        conv, inbound.client_message_id, "customer", inbound.channel,
        inbound.message_type, inbound.content.strip(), inbound.media_ref, inbound.media_mime_type
    );
}

"""Store a reply from the agent (or staff)."""
def record_outbound(
    biz: Business, customer_id: str, content: str, sender_type: str = "agent", channel: str = "shop_chat"
) -> Message {
    conv = get_or_create_conversation(biz, customer_id);
    return append_message(conv, "", sender_type, channel, "text", content);
}

"""Placeholder replies until the AI agent arrives in P4."""
def deterministic_reply(message_type: str) -> str {
    return PHOTO_REPLY if message_type == "image" else TEXT_REPLY;
}

"""One row per conversation that has messages, newest activity first."""
def conversation_summaries(biz: Business) -> list[ConversationSummary] {
    rows: list[ConversationSummary] = [];
    for conv in [biz ->:HasConversation:->] {
        msgs = list_messages(conv);
        if not msgs { continue; }
        last = msgs[-1];
        customer = find_customer(biz, conv.customer_id);
        preview = last.content if last.message_type == "text" else ("Photo: " + last.content if last.content else "Photo");
        rows.append(ConversationSummary(
            customer_id=conv.customer_id,
            customer_name=customer.name if customer else conv.customer_id,
            last_message=preview, last_at=last.created_at, message_count=len(msgs)
        ));
    }
    return sorted(rows, key=lambda (r: ConversationSummary) { r.last_at; }, reverse=True);
}
