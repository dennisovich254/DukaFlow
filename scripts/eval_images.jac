"""P6.6: measure photo orders with the REAL model.

Put photographs in tests/fixtures/images/eval/ and describe each in
tests/fixtures/images/eval/expected.json, for example:

    {"list1.jpg": {"order": true,  "lines": {"RINA-1L-CTN": 5, "JOGOO-2KG-BALE": 10}},
     "messy.jpg": {"order": true,  "lines": {"OMO-1KG-CTN": 3}, "unclear": 1},
     "selfie.jpg": {"order": false}}

`lines` are the lines that are clearly legible (they must be read exactly); `unclear` is the number
of lines that should be flagged rather than guessed. Run with:  jac run --no-serve scripts/eval_images.jac
"""

import os;
import json;
import ai.agent as agent_mod;
import from ai.agent { CustomerAgent }
import from domain.models { Business }
import from domain.seed { seed_demo_data }
import from domain.messaging { InboundMessage, record_inbound, get_or_create_conversation }
import from domain.quotations { latest_quotation, quotation_lines }
import from integrations.media { store_chat_image }
import from config.settings { settings_from_env }

glob EVAL_DIR: str = "tests/fixtures/images/eval";

def mime_of(name: str) -> str {
    low = name.lower();
    if low.endswith(".png") { return "image/png"; }
    if low.endswith(".webp") { return "image/webp"; }
    return "image/jpeg";
}

def run_image(name: str, spec: dict[str, any]) -> tuple[bool, str] {
    biz = Business(name="Karibu Wholesalers");
    seed_demo_data(biz);
    with open(os.path.join(EVAL_DIR, name), "rb") as f { data = f.read(); }
    ref = store_chat_image(data, mime_of(name), name, settings_from_env([]).media_storage_dir, 5242880);
    m = record_inbound(biz, InboundMessage(
        customer_id="C-001", client_message_id="i1", message_type="image", media_ref=ref, media_mime_type=mime_of(name)
    ));
    conv = get_or_create_conversation(biz, "C-001");
    out = (conv spawn CustomerAgent(customer_id="C-001", message_seq=m.seq)).reports[0];
    if not spec.get("order", True) {
        return (out.outcome == "NOT_AN_ORDER", out.outcome);
    }
    unclear = spec.get("unclear", 0);
    want: dict[str, int] = spec.get("lines", {});
    q = latest_quotation(biz, "C-001");
    got: dict[str, int] = {};
    if q is not None { for l in quotation_lines(q) { got[l.product_sku] = l.quantity; } }
    if unclear > 0 {
        return (out.outcome == "CLARIFIED" and got == want, f"{out.outcome} {got}");
    }
    return (out.outcome == "QUOTED" and got == want, f"{out.outcome} {got}");
}

with entry {
    agent_mod.MODE_OVERRIDE = "live";
    path = os.path.join(EVAL_DIR, "expected.json");
    if not os.path.exists(path) {
        print("No expected.json in " + EVAL_DIR + ": add photos and a description first.");
    } else {
        with open(path, "r") as f { cases = json.load(f); }
        passed = 0;
        for (name, spec) in cases.items() {
            try {
                (ok, detail) = run_image(name, spec);
            } except Exception as e {
                (ok, detail) = (False, f"EXCEPTION {type(e).__name__}");
            }
            if ok { passed += 1; }
            print(f"{'PASS' if ok else 'FAIL'} | {name} | {detail}");
        }
        print(f"IMAGE RESULT: {passed}/{len(cases)} = {round(100 * passed / len(cases))}%");
    }
}
