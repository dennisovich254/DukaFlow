"""P5: order review context and agent activity."""

import ai.agent as agent_mod;
import from ai.agent { CustomerAgent, AgentOutcome }
import from domain.models { Business }
import from domain.seed { seed_demo_data }
import from domain.messaging { InboundMessage, record_inbound, get_or_create_conversation }
import from domain.orders { list_orders, create_manual_order }
import from domain.order_input { OrderItemInput }
import from domain.review { get_review_context, recent_activity }
import from tests.api_helpers { new_client_as_owner, call, PASSWORD }

def ask(biz: Business, customer_id: str, cmid: str, text: str) -> AgentOutcome {
    m = record_inbound(biz, InboundMessage(customer_id=customer_id, client_message_id=cmid, content=text));
    conv = get_or_create_conversation(biz, customer_id);
    result = conv spawn CustomerAgent(customer_id=customer_id, message_seq=m.seq);
    return result.reports[0];
}

def chat_order(biz: Business) -> any {
    return [o for o in list_orders(biz) if o.channel == "shop_chat"][0];
}

test "a chat order can be reviewed: messages, quote notes and the agent's steps" {
    agent_mod.MODE_OVERRIDE = "mock";
    biz = Business(name="My Wholesale");
    seed_demo_data(biz);
    ask(biz, "C-001", "r1", "Niletee Rina 1L carton 10 na Jogoo 2kg bale 5");
    ask(biz, "C-001", "r2", "sawa");
    order = chat_order(biz);
    assert order.quote_id == "Q-1001" and order.source_seq > 0;
    ctx = get_review_context(biz, order.order_id);
    assert any([m.content == "Niletee Rina 1L carton 10 na Jogoo 2kg bale 5" for m in ctx.messages]);
    assert any(["only 8 available" in n for n in ctx.quote_notes]);
    assert len(ctx.executions) >= 1 and any([len(e.steps) > 0 for e in ctx.executions]);
}

test "a hand-entered order has nothing to review from chat" {
    biz = Business(name="My Wholesale");
    seed_demo_data(biz);
    order = create_manual_order(biz, "C-001", [OrderItemInput(sku="RINA-1L-CTN", quantity=1)]);
    ctx = get_review_context(biz, order.order_id);
    assert ctx.messages == [] and ctx.quote_notes == [] and ctx.executions == [];
}

test "recent activity lists the newest agent runs first with the customer name" {
    agent_mod.MODE_OVERRIDE = "mock";
    biz = Business(name="My Wholesale");
    seed_demo_data(biz);
    ask(biz, "C-001", "a1", "Habari");
    ask(biz, "C-002", "a2", "Nipe cartons 3 za Omo 1kg");
    items = recent_activity(biz, 10);
    assert len(items) == 2;
    assert items[0].customer_name == "Kamau General Stores" and items[0].execution.outcome == "QUOTED";
    assert items[1].execution.outcome == "ANSWERED";
    assert len(recent_activity(biz, 1)) == 1;
}

def say(client: any, token: str, cid: str, text: str) {
    client.clear_auth();
    try {
        call(client, "send_chat_message", {"data": {"invite": token, "client_message_id": cid, "text": text}});
    } finally {
        client.login("owner", PASSWORD);
    }
}

test "review and activity endpoints for the wholesaler" {
    client = new_client_as_owner();
    try {
        call(client, "load_demo_data", {});
        token = call(client, "create_chat_invite", {"query": {"customer_id": "C-001"}})["token"];
        say(client, token, "h1", "Niletee Rina 1L carton 10 na Jogoo 2kg bale 5");
        say(client, token, "h2", "sawa");
        order_id = [o for o in call(client, "list_order_records", {}) if o["channel"] == "shop_chat"][0]["order_id"];
        r = call(client, "order_review", {"query": {"order_id": order_id}});
        assert r["ok"], r["error"];
        rev = r["review"];
        assert rev["quote_id"] == "Q-1001" and rev["order"]["total_kes"] == 35550;
        assert len(rev["messages"]) >= 2 and any(["only 8 available" in n for n in rev["quote_notes"]]);
        assert len(rev["executions"]) >= 1 and rev["executions"][0]["customer_name"] == "Mama Wanjiku Shop";
        feed = call(client, "recent_agent_activity", {});
        assert len(feed) >= 2 and feed[0]["outcome"] == "ORDER_PLACED";
        missing = call(client, "order_review", {"query": {"order_id": "ORD-9999"}});
        assert not missing["ok"] and missing["error"]["code"] == "ORDER_NOT_FOUND";
    } finally { client.close(); }
}
