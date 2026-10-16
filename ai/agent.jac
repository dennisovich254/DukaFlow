"""The customer agent: a walker that runs a plan-act loop for one chat message.

It is entered on the customer's Conversation node and walks back to the Business to
gather context (open draft or quotation, history, catalogue through its tools), asks the
model (or the rules) for a decision, then *acts through deterministic code*: quotations
and totals come from domain.quotations, replies from ai.replies, and an order is only
created when the customer confirms the open quotation. The wholesaler still approves.
"""

import os;
import re;
import time;
import uuid;
import from jaclang.byllm.lib { Image }
import from domain.models {
    Business, Conversation, Message, Quotation, HasConversation, AgentExecution, HasExecution
}
import from domain.errors { DomainError }
import from domain.catalogue { find_product }
import from domain.messaging { get_or_create_conversation, list_messages, record_outbound }
import from domain.quotations {
    RequestedLine, QuotePlan, plan_quote, build_quotation, latest_quotation, quotation_lines,
    confirm_quotation, cancel_open_quotation, is_expired
}
import from domain.clock { now_iso }
import from domain.orders { list_orders }
import from integrations.media { media_path }
import from config.settings { settings_from_env }
import from ai.resolver { search_products }
import from ai.brain {
    Brain, RUNS, RunState, AgentDecision, DecisionLine, ParsedList, ParsedLine, rule_decide
}
import from ai.replies {
    lang_of, welcome, holding, too_long, too_many_lines, not_an_order, nothing_to_confirm, quote_expired,
    cancelled, order_placed, quote_reply, clarify_photo, reply_is_safe, kes, status_reply, is_status_question
}

glob MAX_TEXT: int = 1000;
glob MAX_LINES: int = 30;
# Tests set this to "live" or "mock"; empty means use AI_MODE from the environment.
glob MODE_OVERRIDE: str = "";

glob CONFIRM_WORDS: list[str] = [
    "sawa", "ndio", "ndiyo", "ok", "okay", "yes", "proceed", "confirm", "confirmed", "nakubali",
    "thibitisha", "endelea", "fine", "yep", "sure", "poa", "tuma"
];
glob REJECT_WORDS: list[str] = ["hapana", "no", "cancel", "badilisha", "change", "acha", "siitaki"];

obj AgentOutcome {
    has reply: str,
        outcome: str;
}

def current_mode() -> str {
    if MODE_OVERRIDE { return MODE_OVERRIDE; }
    return settings_from_env([]).ai_mode;
}

def model_available() -> bool {
    if current_mode() != "live" { return False; }
    return MODE_OVERRIDE == "live" or os.environ.get("GEMINI_API_KEY", "") != "";
}

"""CONFIRM, REJECT or OTHER. Only short messages without digits can confirm or reject."""
def intent_of(text: str) -> str {
    words = re.findall(r"[a-z]+", text.lower());
    if not words or len(words) > 5 or re.search(r"\d", text) { return "OTHER"; }
    yes = len([w for w in words if w in CONFIRM_WORDS]);
    no = len([w for w in words if w in REJECT_WORDS]);
    if yes > 0 and no == 0 { return "CONFIRM"; }
    if no > 0 and yes == 0 { return "REJECT"; }
    return "OTHER";
}

def history_text(msgs: list[Message], before_seq: int) -> str {
    rows: list[str] = [];
    for m in [x for x in msgs if x.seq < before_seq][-8:] {
        who = "Customer" if m.sender_type == "customer" else "Assistant";
        body = "[photo]" if m.message_type == "image" and not m.content else m.content;
        rows.append(f"{who}: {body}");
    }
    return "\n".join(rows) if rows else "(no earlier messages)";
}

def quote_summary(q: Quotation | None) -> str {
    if q is None or q.status not in ["OPEN", "DRAFT"] { return "none"; }
    rows = "; ".join([f"{l.quantity} x {l.product_name}" for l in quotation_lines(q)]);
    return f"{q.status} {q.quote_id}: {rows}";
}

def flag(conv: Conversation, reason: str) {
    conv.flagged = True;
    conv.flag_reason = reason;
}

"""Canned reading of the demo photo for mock mode (clearly a demo, no model involved)."""
def canned_list() -> ParsedList {
    return ParsedList(is_order=True, lines=[
        ParsedLine(text="rina 1L carton", quantity=5),
        ParsedLine(text="jogoo 2kg bale", quantity=10),
        ParsedLine(text="omo 1kg carton", quantity=3),
        ParsedLine(text="sukari", quantity=2, uncertain=True, note="which sugar and which size?")
    ]);
}

def read_photo(brain: Brain, msg: Message, live: bool) -> ParsedList {
    if not live { return canned_list(); }
    settings = settings_from_env([]);
    path = media_path(settings.media_storage_dir, msg.media_ref);
    return brain.read_list(Image(path), msg.content);
}

def line_text(l: ParsedLine) -> str {
    qty = f" {l.quantity}" if l.quantity > 0 and str(l.quantity) not in l.text else "";
    return f"{l.text}{qty}";
}

"""Validate the lines a decision proposes: real, active SKUs and whole positive quantities."""
def valid_lines(biz: Business, lines: list[DecisionLine]) -> bool {
    for l in lines {
        p = find_product(biz, l.sku);
        if p is None or not p.active or not isinstance(l.quantity, int) or l.quantity < 1 { return False; }
    }
    return True;
}

def decide(
    state: RunState, run_id: str, text: str, history: str, open_summary: str, live: bool
) -> AgentDecision {
    if live {
        try {
            return Brain(run_id=run_id).decide(text, history, open_summary);
        } except Exception as e {
            state.trace.append(f"model unavailable ({type(e).__name__}); used rules");
        }
    }
    return rule_decide(state, text);
}

def respond(biz: Business, customer_id: str, message_seq: int) -> AgentOutcome {
    started = time.time();
    conv = get_or_create_conversation(biz, customer_id);
    msgs = list_messages(conv);
    mine = [m for m in msgs if m.seq == message_seq];
    if not mine { return AgentOutcome(reply=welcome("en"), outcome="IGNORED"); }
    msg = mine[0];
    state = RunState(biz=biz, customer_id=customer_id);
    run_id = uuid.uuid4().hex;
    RUNS[run_id] = state;
    outcome = AgentOutcome(reply=holding("en"), outcome="ERROR");
    error = "";
    try {
        outcome = handle(state, run_id, conv, msg, msgs);
    } except Exception as e {
        error = f"{type(e).__name__}: {e}";
        flag(conv, "agent error");
        outcome = AgentOutcome(reply=holding(lang_of(msg.content)), outcome="ERROR");
    } finally {
        RUNS.pop(run_id, None);
    }
    ex = AgentExecution(
        message_seq=message_seq, input_type=msg.message_type, outcome=outcome.outcome,
        duration_ms=int((time.time() - started) * 1000), created_at=now_iso(),
        steps=state.trace[:25], error=error
    );
    conv +>:HasExecution():+> ex;
    record_outbound(biz, customer_id, outcome.reply);
    return outcome;
}

def handle(
    state: RunState, run_id: str, conv: Conversation, msg: Message, msgs: list[Message]
) -> AgentOutcome {
    biz = state.biz;
    cid = state.customer_id;
    recent_customer = " ".join([m.content for m in msgs if m.sender_type == "customer"][-3:]);
    lang = lang_of(msg.content or recent_customer);
    is_image = msg.message_type == "image";
    text = msg.content;
    if len(text) > MAX_TEXT {
        return AgentOutcome(reply=too_long(lang), outcome="REJECTED");
    }
    if not is_image and is_status_question(text) {
        mine = [o for o in list_orders(biz) if o.customer_id == cid][:3];
        state.trace.append(f"order_status -> {[(o.order_id, o.status) for o in mine]}");
        return AgentOutcome(
            reply=status_reply(lang, [(o.order_id, o.status, o.total_kes) for o in mine]),
            outcome="STATUS"
        );
    }
    q = latest_quotation(biz, cid);
    open_q = q if (q is not None and q.status == "OPEN") else None;
    draft_q = q if (q is not None and q.status == "DRAFT") else None;

    if not is_image {
        intent = intent_of(text);
        if intent == "CONFIRM" {
            if open_q is None {
                return AgentOutcome(reply=nothing_to_confirm(lang), outcome="NOTHING_TO_CONFIRM");
            }
            try {
                order = confirm_quotation(biz, cid);
                state.trace.append(f"confirm_quotation -> {order.order_id}");
                return AgentOutcome(reply=order_placed(lang, order.order_id, order.total_kes), outcome="ORDER_PLACED");
            } except DomainError as e {
                if e.code == "QUOTE_EXPIRED" {
                    return AgentOutcome(reply=quote_expired(lang), outcome="QUOTE_EXPIRED");
                }
                return AgentOutcome(reply=nothing_to_confirm(lang), outcome="NOTHING_TO_CONFIRM");
            }
        }
        if intent == "REJECT" and (open_q is not None or draft_q is not None) {
            cancel_open_quotation(biz, cid);
            if draft_q is not None { draft_q.status = "CANCELLED"; }
            return AgentOutcome(reply=cancelled(lang), outcome="CANCELLED");
        }
    }

    live = model_available();
    uncertain: list[ParsedLine] = [];
    transcript = text;
    if is_image {
        parsed = read_photo(Brain(run_id=run_id), msg, live);
        state.trace.append(f"read_list -> {len(parsed.lines)} lines, order={parsed.is_order}");
        if not parsed.is_order or not parsed.lines {
            return AgentOutcome(reply=not_an_order(lang), outcome="NOT_AN_ORDER");
        }
        if len(parsed.lines) > MAX_LINES {
            return AgentOutcome(reply=too_many_lines(lang), outcome="REJECTED");
        }
        uncertain = [l for l in parsed.lines if l.uncertain];
        clear = [l for l in parsed.lines if not l.uncertain];
        transcript = ", ".join([line_text(l) for l in clear]);
        if msg.content { transcript = (transcript + ", " + msg.content) if transcript else msg.content; }
    }

    if not transcript.strip() and uncertain {
        return AgentOutcome(reply=clarify_photo(lang, [], [l.text for l in uncertain]), outcome="CLARIFIED");
    }

    history = history_text(msgs, msg.seq);
    summary = quote_summary(q);
    decision = decide(state, run_id, transcript, history, summary, live);
    if decision.action == "QUOTE" and not valid_lines(biz, decision.lines) {
        state.trace.append("model proposed an invalid line; used rules");
        decision = rule_decide(state, transcript);
    }

    if decision.action == "ESCALATE" {
        flag(conv, "agent escalated");
        return AgentOutcome(reply=holding(lang), outcome="ESCALATED");
    }
    if decision.action != "QUOTE" {
        reply = decision.reply.strip();
        if not reply or not reply_is_safe(reply, state.prices) {
            if reply { state.trace.append("discarded a reply with an unverified price"); }
            reply = welcome(lang);
        }
        return AgentOutcome(reply=reply, outcome="CLARIFIED" if decision.action == "CLARIFY" else "ANSWERED");
    }

    requested: list[RequestedLine] = [];
    if draft_q is not None {
        requested = [RequestedLine(sku=l.product_sku, quantity=l.quantity) for l in quotation_lines(draft_q)];
    }
    for l in decision.lines { requested.append(RequestedLine(sku=l.sku, quantity=l.quantity)); }
    if len(requested) > MAX_LINES {
        return AgentOutcome(reply=too_many_lines(lang), outcome="REJECTED");
    }
    plan = plan_quote(biz, requested);
    if not plan.lines {
        notes = "\n".join([n.name + (" is out of stock right now." if lang == "en" else " haipatikani kwa sasa.") for n in plan.notes]);
        return AgentOutcome(reply=notes or welcome(lang), outcome="UNAVAILABLE");
    }
    if uncertain {
        draft = build_quotation(biz, cid, plan, "DRAFT");
        understood = [f"{l.quantity} × {l.product_name}" for l in quotation_lines(draft)];
        return AgentOutcome(
            reply=clarify_photo(lang, understood, [l.text + (f" ({l.note})" if l.note else "") for l in uncertain]),
            outcome="CLARIFIED"
        );
    }
    quote = build_quotation(biz, cid, plan, "OPEN");
    state.trace.append(f"build_quotation -> {quote.quote_id} {quote.total_kes}");
    return AgentOutcome(reply=quote_reply(lang, quote, quotation_lines(quote), plan.notes), outcome="QUOTED");
}

"""Entered on the customer's Conversation: walk back to the Business, run the agent, report the reply."""
walker CustomerAgent {
    has customer_id: str,
        message_seq: int;

    can run with Conversation entry {
        biz = [here <-:HasConversation:<-][0];
        report respond(biz, self.customer_id, self.message_seq);
    }
}
