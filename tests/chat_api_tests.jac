"""P3.3: Shop chat over HTTP; customers are identified only by an invite link."""

import base64;
import from tests.api_helpers { new_client, new_client_as_owner, call, PASSWORD }

def seed(client: any) {
    call(client, "add_customer", {"data": {"name": "Mama Wanjiku Shop", "phone": "0700000001"}});
}

def photo_b64() -> str {
    with open("tests/fixtures/images/sample_list.jpg", "rb") as f {
        return base64.b64encode(f.read()).decode("ascii");
    }
}

def invite_for(client: any, customer_id: str) -> str {
    r = call(client, "create_chat_invite", {"query": {"customer_id": customer_id}});
    assert r["ok"], r["error"];
    return r["token"];
}

"""Call a public endpoint as an anonymous customer, then sign the owner back in."""
def as_guest(client: any, name: str, body: dict[str, any]) -> any {
    client.clear_auth();
    try {
        return call(client, name, body);
    } finally {
        client.login("owner", PASSWORD);
    }
}

def say(client: any, token: str, cid: str, text: str) -> any {
    return as_guest(client, "send_chat_message", {"data": {"invite": token, "client_message_id": cid, "text": text}});
}

test "customer with an invite link chats without an account; the wholesaler sees it" {
    client = new_client_as_owner();
    try {
        seed(client);
        token = invite_for(client, "C-001");
        sess = as_guest(client, "get_chat_session", {"query": {"invite": token}});
        assert sess["ok"] and sess["customer_name"] == "Mama Wanjiku Shop" and sess["business_name"] == "My Wholesale";
        r = say(client, token, "m1", "Habari");
        assert r["ok"], r["error"];
        assert [(m["sender_type"], m["message_type"]) for m in r["messages"]] == [("customer", "text"), ("agent", "text")];
        assert r["messages"][1]["content"] == "Karibu DukaFlow! Tuambie bidhaa unazohitaji.";
        rows = call(client, "list_conversations", {});
        assert len(rows) == 1 and rows[0]["customer_name"] == "Mama Wanjiku Shop" and rows[0]["message_count"] == 2;
        thread = call(client, "staff_get_conversation", {"query": {"customer_id": "C-001", "after_seq": 0}});
        assert thread["messages"][0]["content"] == "Habari";
    } finally { client.close(); }
}

test "invalid, missing and revoked invites are refused and store nothing" {
    client = new_client_as_owner();
    try {
        seed(client);
        token = invite_for(client, "C-001");
        for bad in ["nope", "", "None"] {
            r = say(client, bad, "x", "hi");
            assert not r["ok"] and r["error"]["code"] == "INVALID_INVITE";
            s = as_guest(client, "get_chat_session", {"query": {"invite": bad}});
            assert not s["ok"] and s["error"]["code"] == "INVALID_INVITE";
        }
        assert call(client, "list_conversations", {}) == [];
        rev = call(client, "revoke_chat_invites", {"query": {"customer_id": "C-001"}});
        assert rev["ok"] and rev["revoked"] >= 1;
        r = say(client, token, "m1", "hi");
        assert not r["ok"] and r["error"]["code"] == "INVALID_INVITE";
        assert call(client, "list_conversations", {}) == [];
    } finally { client.close(); }
}

test "an invite reaches only its own customer and its own business" {
    client = new_client_as_owner();
    try {
        seed(client);
        call(client, "add_customer", {"data": {"name": "Kamau General Stores", "phone": "0700000002"}});
        tok_a = invite_for(client, "C-001");
        tok_b = invite_for(client, "C-002");
        say(client, tok_a, "m1", "from A");
        a = as_guest(client, "get_conversation", {"query": {"invite": tok_a, "after_seq": 0}});
        b = as_guest(client, "get_conversation", {"query": {"invite": tok_b, "after_seq": 0}});
        assert a["messages"][0]["content"] == "from A" and b["messages"] == [];
        other = new_client();
        try {
            other.register_user("other", PASSWORD);
            assert call(other, "list_conversations", {}) == [] and call(other, "list_customer_records", {}) == [];
            miss = call(other, "create_chat_invite", {"query": {"customer_id": "C-001"}});
            assert not miss["ok"] and miss["error"]["code"] == "CUSTOMER_NOT_FOUND";
            peek = call(other, "staff_get_conversation", {"query": {"customer_id": "C-001", "after_seq": 0}});
            assert not peek["ok"] and peek["error"]["code"] == "CUSTOMER_NOT_FOUND";
        } finally { other.close(); }
    } finally { client.close(); }
}

test "photos work anonymously and are only served from the token's own conversation" {
    client = new_client_as_owner();
    try {
        call(client, "load_demo_data", {});
        token = invite_for(client, "C-001");
        r = as_guest(client, "send_chat_message", {"data": {
            "invite": token, "client_message_id": "p1", "text": "",
            "photo_base64": photo_b64(), "photo_mime_type": "image/jpeg", "photo_name": "list.jpg"
        }});
        assert r["ok"], r["error"];
        first = r["messages"][0];
        assert first["message_type"] == "image" and first["media_ref"].endswith(".jpg");
        assert "sukari" in r["messages"][1]["content"];
        img = as_guest(client, "get_chat_image", {"query": {"invite": token, "media_ref": first["media_ref"]}});
        assert img["ok"] and img["data_url"].startswith("data:image/jpeg;base64,");
        nope = as_guest(client, "get_chat_image", {"query": {"invite": token, "media_ref": "other.jpg"}});
        assert not nope["ok"] and nope["error"]["code"] == "NOT_FOUND";
        assert call(client, "staff_get_chat_image", {"query": {"customer_id": "C-001", "media_ref": first["media_ref"]}})["ok"];
    } finally { client.close(); }
}

test "duplicates add nothing, polling returns newer messages, bad uploads are rejected" {
    client = new_client_as_owner();
    try {
        seed(client);
        token = invite_for(client, "C-001");
        say(client, token, "m1", "Habari");
        again = say(client, token, "m1", "Habari");
        assert len(again["messages"]) == 2;
        polled = as_guest(client, "get_conversation", {"query": {"invite": token, "after_seq": 1}});
        assert [m["seq"] for m in polled["messages"]] == [2];
        pdf = as_guest(client, "send_chat_message", {"data": {
            "invite": token, "client_message_id": "x1",
            "photo_base64": base64.b64encode(b"%PDF-1.4").decode("ascii"), "photo_mime_type": "application/pdf"
        }});
        assert not pdf["ok"] and pdf["error"]["code"] == "UNSUPPORTED_MEDIA";
        empty = say(client, token, "x2", "  ");
        assert not empty["ok"] and empty["error"]["code"] == "VALIDATION_ERROR";
    } finally { client.close(); }
}

test "wholesaler chat endpoints require login" {
    client = new_client();
    try {
        for name in ["list_conversations"] {
            assert client.post(f"/function/{name}", json={}).status_code == 401;
        }
        for name in ["create_chat_invite", "revoke_chat_invites"] {
            assert client.post(f"/function/{name}", json={"query": {"customer_id": "C-001"}}).status_code == 401;
        }
        assert client.post("/function/staff_get_conversation", json={"query": {"customer_id": "C-001"}}).status_code == 401;
        assert client.post("/function/staff_get_chat_image", json={"query": {"customer_id": "C-001", "media_ref": "a.jpg"}}).status_code == 401;
    } finally { client.close(); }
}

test "the agent quotes in the chat, the customer confirms, and the wholesaler sees a pending order" {
    client = new_client_as_owner();
    try {
        call(client, "load_demo_data", {});
        token = invite_for(client, "C-001");
        q = say(client, token, "q1", "Nipe cartons 5 za Rina 1L");
        reply = q["messages"][-1]["content"];
        assert q["ok"] and "KSh 14,000" in reply and "5 × Rina" in reply;
        before = [o for o in call(client, "list_order_records", {}) if o["channel"] == "shop_chat"];
        assert before == [];
        ok = say(client, token, "q2", "Sawa, proceed");
        assert "ORD-" in ok["messages"][-1]["content"];
        orders = [o for o in call(client, "list_order_records", {}) if o["channel"] == "shop_chat"];
        assert len(orders) == 1 and orders[0]["status"] == "PENDING_APPROVAL" and orders[0]["total_kes"] == 14000;
        say(client, token, "q3", "proceed");
        assert len([o for o in call(client, "list_order_records", {}) if o["channel"] == "shop_chat"]) == 1;
    } finally { client.close(); }
}
