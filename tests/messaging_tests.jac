"""P3.1: conversations and messages."""

import from domain.models { Business, HasConversation }
import from domain.customers { create_customer }
import from domain.messaging {
    InboundMessage, record_inbound, record_outbound, get_or_create_conversation, list_messages,
    conversation_summaries
}
import from domain.errors { DomainError }
import from tests.helpers { code_of }

def setup() -> Business {
    biz = Business(name="T");
    create_customer(biz, name="Mama Wanjiku Shop", phone="0700000001");
    create_customer(biz, name="Kamau General Stores", phone="0700000002");
    return biz;
}

test "a text message lands on that customer's conversation" {
    biz = setup();
    m = record_inbound(biz, InboundMessage(customer_id="C-001", client_message_id="m1", content="Habari"));
    msgs = list_messages(get_or_create_conversation(biz, "C-001"));
    assert len(msgs) == 1;
    assert (msgs[0].content, msgs[0].sender_type, msgs[0].message_type, msgs[0].seq) == ("Habari", "customer", "text", 1);
}

test "the same client message id is stored once" {
    biz = setup();
    a = record_inbound(biz, InboundMessage(customer_id="C-001", client_message_id="m1", content="Habari"));
    b = record_inbound(biz, InboundMessage(customer_id="C-001", client_message_id="m1", content="Habari"));
    assert a.seq == b.seq and len(list_messages(get_or_create_conversation(biz, "C-001"))) == 1;
}

test "two customers have separate conversations and unknown customers are rejected" {
    biz = setup();
    record_inbound(biz, InboundMessage(customer_id="C-001", client_message_id="m1", content="a"));
    record_inbound(biz, InboundMessage(customer_id="C-002", client_message_id="m1", content="b"));
    assert len([biz ->:HasConversation:->]) == 2;
    assert [m.content for m in list_messages(get_or_create_conversation(biz, "C-002"))] == ["b"];
    with testraises(DomainError) as e {
        record_inbound(biz, InboundMessage(customer_id="C-999", client_message_id="m1", content="x"));
    }
    assert code_of(e.value) == "CUSTOMER_NOT_FOUND";
}

test "empty text and imageless image messages are rejected" {
    biz = setup();
    with testraises(DomainError) as e1 {
        record_inbound(biz, InboundMessage(customer_id="C-001", client_message_id="m1", content="   "));
    }
    assert code_of(e1.value) == "VALIDATION_ERROR";
    with testraises(DomainError) as e2 {
        record_inbound(biz, InboundMessage(customer_id="C-001", client_message_id="m2", message_type="image"));
    }
    assert code_of(e2.value) == "VALIDATION_ERROR";
}

test "agent replies order after the message and polling returns only newer ones" {
    biz = setup();
    record_inbound(biz, InboundMessage(customer_id="C-001", client_message_id="m1", content="Habari"));
    record_outbound(biz, "C-001", "Karibu!");
    conv = get_or_create_conversation(biz, "C-001");
    assert [(m.seq, m.sender_type) for m in list_messages(conv)] == [(1, "customer"), (2, "agent")];
    assert [m.seq for m in list_messages(conv, after_seq=1)] == [2];
}

test "summaries list conversations with messages, newest first, with photo previews" {
    biz = setup();
    record_inbound(biz, InboundMessage(customer_id="C-001", client_message_id="a", content="Habari"));
    record_inbound(biz, InboundMessage(customer_id="C-002", client_message_id="b", message_type="image", media_ref="x.jpg", media_mime_type="image/jpeg"));
    get_or_create_conversation(biz, "C-001");
    rows = conversation_summaries(biz);
    assert [r.customer_id for r in rows] == ["C-002", "C-001"];
    assert (rows[0].last_message, rows[0].customer_name, rows[0].message_count) == ("Photo", "Kamau General Stores", 1);
    assert rows[1].last_message == "Habari";
}
