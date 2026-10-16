"""Language detection (English, Swahili, Sheng) and replies that match it."""

import from ai.replies { detect_one, detect_lang, lang_of, status_reply }
import ai.agent as agent_mod;
import from ai.agent { CustomerAgent, AgentOutcome }
import from domain.models { Business }
import from domain.seed { seed_demo_data }
import from domain.messaging { InboundMessage, record_inbound, get_or_create_conversation }

test "each language is recognised from function words, not product names" {
    assert detect_one("Please send me 5 cartons of Rina 1L") == "en";
    assert detect_one("Hello, how much is sugar?") == "en";
    assert detect_one("where is my order") == "en";
    assert detect_one("Niletee Rina 1L carton 5 na Jogoo 10") == "sw";
    assert detect_one("Habari, nataka sukari") == "sw";
    assert detect_one("status ya oda yangu") == "sw";
    assert detect_one("Niaje msee, niletee Rina 5 carton") == "sh";
    assert detect_one("Sasa buda, nipe unga") == "sh";
    assert detect_one("poa nipe Rina") == "sh";
}

test "bare confirmations and numbers carry no language, so the previous language is kept" {
    for t in ["sawa", "10", "ok", "poa", "proceed", ""] {
        assert detect_one(t) == "";
    }
    assert detect_lang(["sawa", "Please send me Rina"]) == "en";
    assert detect_lang(["sawa", "Niaje msee, nipe Rina"]) == "sh";
    assert detect_lang(["Hello please", "Nipe Rina kwa bei gani"]) == "en";
    assert detect_lang([]) == "en" and lang_of("sawa") == "en";
}

test "status wording exists in all three languages" {
    rows = [("ORD-1001", "DISPATCHED", 14000)];
    assert "on its way" in status_reply("en", rows);
    assert "iko njiani kwako" in status_reply("sw", rows);
    assert "inakuja" in status_reply("sh", rows);
}

def ask(biz: Business, cmid: str, text: str) -> AgentOutcome {
    m = record_inbound(biz, InboundMessage(customer_id="C-001", client_message_id=cmid, content=text));
    conv = get_or_create_conversation(biz, "C-001");
    result = conv spawn CustomerAgent(customer_id="C-001", message_seq=m.seq);
    return result.reports[0];
}

test "the agent replies in the customer's language through quote and confirmation" {
    agent_mod.MODE_OVERRIDE = "mock";
    en = Business(name="My Wholesale");
    seed_demo_data(en);
    q = ask(en, "e1", "Please send me 5 cartons of Rina 1L");
    assert q.outcome == "QUOTED" and "Here is your quote" in q.reply and "Reply 'sawa' to confirm" in q.reply;
    assert "Done! Order" in ask(en, "e2", "sawa").reply;

    sw = Business(name="My Wholesale");
    seed_demo_data(sw);
    q2 = ask(sw, "s1", "Naomba Rina 1L carton 5, tafadhali");
    assert q2.outcome == "QUOTED" and "Hii hapa bei yako" in q2.reply and "Jibu 'sawa' kuthibitisha" in q2.reply;
    assert "Sawa! Oda" in ask(sw, "s2", "sawa").reply;

    sh = Business(name="My Wholesale");
    seed_demo_data(sh);
    q3 = ask(sh, "h1", "Niaje msee, niletee Rina 1L carton 5");
    assert q3.outcome == "QUOTED" and "Sema 'poa' kuconfirm" in q3.reply;
    assert "Fiti! Oda" in ask(sh, "h2", "poa").reply;
}
