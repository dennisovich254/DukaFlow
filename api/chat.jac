"""Shop chat endpoints.

Customer side (`def:pub`): identified only by an invite token created by the wholesaler.
The business and the customer are derived from the token, never from the request body,
so a token reaches exactly one customer's conversation.

Wholesaler side (`def:protect`): invite management and read-only conversation views.
"""

import base64;
import from jaclang.server.identity.app_tokens { token_create, token_peek, token_revoke }
import from domain.models { Business, Message }
import from domain.errors { DomainError }
import from domain.customers { get_customer }
import from domain.messaging {
    InboundMessage, record_inbound, record_outbound, get_or_create_conversation,
    list_messages, find_message, deterministic_reply, conversation_summaries
}
import from integrations.media { store_chat_image, media_path }
import from config.settings { settings_from_env }
import from api.business { current_business, find_business }
import from api.results { to_api_error }
import from api.contracts {
    MessageView, ChatResult, ChatInput, ConversationQuery, ImageQuery, ImageResult,
    ChatSessionQuery, ChatSessionResult, StaffConversationQuery, StaffImageQuery,
    InviteQuery, InviteResult, RevokeResult, ConversationSummaryView
}

glob INVITE_PURPOSE: str = "chat-invite";
glob INVITE_TTL_SECONDS: int = 2592000;

obj ChatContext {
    has biz: Business,
        customer_id: str,
        customer_name: str;
}

def clean(value: str) -> str {
    return "" if value == "None" else value;
}

def invalid_invite() -> DomainError {
    return DomainError(code="INVALID_INVITE", message="This chat link is not valid. Ask your wholesaler for a new one.");
}

"""Turn an invite token into its business and customer, or raise INVALID_INVITE."""
def resolve_invite(invite: str) -> ChatContext {
    token = clean(invite);
    if not token { raise invalid_invite(); }
    got = token_peek(INVITE_PURPOSE, token);
    if got is None { raise invalid_invite(); }
    payload = got["payload"];
    biz = find_business(payload["owner"]);
    if biz is None { raise invalid_invite(); }
    try {
        customer = get_customer(biz, payload["customer_id"]);
    } except DomainError {
        raise invalid_invite();
    }
    return ChatContext(biz=biz, customer_id=customer.customer_id, customer_name=customer.name);
}

def message_view(m: Message) -> MessageView {
    return MessageView(
        seq=m.seq, sender_type=m.sender_type, message_type=m.message_type, content=m.content,
        created_at=m.created_at, media_ref=m.media_ref, client_message_id=m.client_message_id
    );
}

def decode_photo(encoded: str) -> bytes {
    try {
        return base64.b64decode(encoded, validate=True);
    } except Exception {
        raise DomainError(code="UNSUPPORTED_MEDIA", message="The photo could not be read.");
    }
}

def read_image(biz: Business, customer_id: str, media_ref: str) -> ImageResult {
    conv = get_or_create_conversation(biz, customer_id);
    owned = [m for m in list_messages(conv) if m.media_ref == media_ref and m.media_ref];
    if not owned {
        raise DomainError(code="NOT_FOUND", message="No such photo in this conversation");
    }
    settings = settings_from_env([]);
    with open(media_path(settings.media_storage_dir, media_ref), "rb") as f {
        raw = f.read();
    }
    encoded = base64.b64encode(raw).decode("ascii");
    return ImageResult(ok=True, data_url=f"data:{owned[0].media_mime_type};base64,{encoded}");
}

# ---------- customer side (invite token) ----------

def:pub get_chat_session(query: ChatSessionQuery) -> ChatSessionResult {
    try {
        ctx = resolve_invite(query.invite);
        return ChatSessionResult(ok=True, business_name=ctx.biz.name, customer_name=ctx.customer_name);
    } except DomainError as e {
        return ChatSessionResult(ok=False, error=to_api_error(e));
    }
}

def:pub send_chat_message(data: ChatInput) -> ChatResult {
    try {
        ctx = resolve_invite(data.invite);
        settings = settings_from_env([]);
        conv = get_or_create_conversation(ctx.biz, ctx.customer_id);
        if find_message(conv, data.client_message_id) is not None {
            return ChatResult(ok=True, messages=[message_view(m) for m in list_messages(conv)]);
        }
        photo = clean(data.photo_base64);
        if photo {
            mime = clean(data.photo_mime_type);
            media_ref = store_chat_image(
                decode_photo(photo), mime, clean(data.photo_name),
                settings.media_storage_dir, settings.max_image_bytes
            );
            inbound = InboundMessage(
                customer_id=ctx.customer_id, client_message_id=data.client_message_id,
                message_type="image", content=clean(data.text), media_ref=media_ref, media_mime_type=mime
            );
        } else {
            inbound = InboundMessage(
                customer_id=ctx.customer_id, client_message_id=data.client_message_id, content=clean(data.text)
            );
        }
        sent = record_inbound(ctx.biz, inbound);
        record_outbound(ctx.biz, ctx.customer_id, deterministic_reply(sent.message_type));
        return ChatResult(ok=True, messages=[message_view(m) for m in list_messages(conv)]);
    } except DomainError as e {
        return ChatResult(ok=False, error=to_api_error(e));
    }
}

def:pub get_conversation(query: ConversationQuery) -> ChatResult {
    try {
        ctx = resolve_invite(query.invite);
        conv = get_or_create_conversation(ctx.biz, ctx.customer_id);
        return ChatResult(ok=True, messages=[message_view(m) for m in list_messages(conv, query.after_seq)]);
    } except DomainError as e {
        return ChatResult(ok=False, error=to_api_error(e));
    }
}

"""Return a stored photo as a data URL, only if it belongs to the token's own conversation."""
def:pub get_chat_image(query: ImageQuery) -> ImageResult {
    try {
        ctx = resolve_invite(query.invite);
        return read_image(ctx.biz, ctx.customer_id, query.media_ref);
    } except DomainError as e {
        return ImageResult(ok=False, error=to_api_error(e));
    }
}

# ---------- wholesaler side (login required) ----------

"""Create a personal chat link token for a customer. The raw token is returned once."""
def:protect create_chat_invite(query: InviteQuery) -> InviteResult {
    try {
        biz = current_business();
        customer = get_customer(biz, query.customer_id);
        token = token_create(
            INVITE_PURPOSE, subject=biz.owner_root_id + ":" + customer.customer_id,
            ttl_seconds=INVITE_TTL_SECONDS,
            payload={"owner": biz.owner_root_id, "customer_id": customer.customer_id}
        );
        return InviteResult(ok=True, token=token);
    } except DomainError as e {
        return InviteResult(ok=False, error=to_api_error(e));
    }
}

def:protect revoke_chat_invites(query: InviteQuery) -> RevokeResult {
    try {
        biz = current_business();
        customer = get_customer(biz, query.customer_id);
        count = token_revoke(INVITE_PURPOSE, biz.owner_root_id + ":" + customer.customer_id);
        return RevokeResult(ok=True, revoked=count);
    } except DomainError as e {
        return RevokeResult(ok=False, error=to_api_error(e));
    }
}

def:protect list_conversations() -> list[ConversationSummaryView] {
    return [
        ConversationSummaryView(
            customer_id=s.customer_id, customer_name=s.customer_name, last_message=s.last_message,
            last_at=s.last_at, message_count=s.message_count
        )
        for s in conversation_summaries(current_business())
    ];
}

def:protect staff_get_conversation(query: StaffConversationQuery) -> ChatResult {
    try {
        biz = current_business();
        customer = get_customer(biz, query.customer_id);
        conv = get_or_create_conversation(biz, customer.customer_id);
        return ChatResult(ok=True, messages=[message_view(m) for m in list_messages(conv, query.after_seq)]);
    } except DomainError as e {
        return ChatResult(ok=False, error=to_api_error(e));
    }
}

def:protect staff_get_chat_image(query: StaffImageQuery) -> ImageResult {
    try {
        biz = current_business();
        customer = get_customer(biz, query.customer_id);
        return read_image(biz, customer.customer_id, query.media_ref);
    } except DomainError as e {
        return ImageResult(ok=False, error=to_api_error(e));
    }
}
