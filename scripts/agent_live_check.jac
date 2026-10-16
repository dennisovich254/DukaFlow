"""P4.9: run the customer agent against the REAL model on a few messages and the sample photo.

Run with:  jac run --no-serve scripts/agent_live_check.jac
Uses the demo catalogue in memory only (nothing is written to the app database).
"""

import os;
import ai.agent as agent_mod;
import from ai.agent { CustomerAgent }
import from domain.models { Business, HasExecution }
import from domain.seed { seed_demo_data }
import from domain.messaging { InboundMessage, record_inbound, get_or_create_conversation }
import from integrations.media { store_chat_image }
import from config.settings { settings_from_env }

def settings_dir() -> str {
    return settings_from_env([]).media_storage_dir;
}

def run(biz: Business, cid: str, text: str, key: str, image: str = "") {
    if image {
        m = record_inbound(biz, InboundMessage(
            customer_id=cid, client_message_id=key, message_type="image",
            content=text, media_ref=image, media_mime_type="image/jpeg"
        ));
    } else {
        m = record_inbound(biz, InboundMessage(customer_id=cid, client_message_id=key, content=text));
    }
    conv = get_or_create_conversation(biz, cid);
    try {
        result = conv spawn CustomerAgent(customer_id=cid, message_seq=m.seq);
        o = result.reports[0];
        ex = [conv ->:HasExecution:->][-1];
        print(f"--- {cid}: {text or '[photo]'}");
        print(f"[{o.outcome}] {o.reply}");
        print("steps:", ex.steps);
    } except Exception as e {
        print(f"--- {cid}: {text} -> EXCEPTION {type(e).__name__}: {e}");
    }
}

with entry {
    agent_mod.MODE_OVERRIDE = "live";
    biz = Business(name="Karibu Wholesalers");
    seed_demo_data(biz);
    run(biz, "C-001", "Niletee Rina 1L carton 10 na Jogoo 2kg bale 5", "t1");
    run(biz, "C-001", "sawa", "t2");
    run(biz, "C-002", "nipe kama kawaida", "t4");
    with open("tests/fixtures/images/sample_list.jpg", "rb") as f { data = f.read(); }
    ref = store_chat_image(data, "image/jpeg", "list.jpg", settings_dir(), 5242880);
    run(biz, "C-001", "", "t6", ref);
}

