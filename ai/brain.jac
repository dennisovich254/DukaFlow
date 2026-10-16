"""The agent's reasoning step.

`Brain.decide` is a tool-using model call (ReAct): the model may search the catalogue,
check stock, look for alternatives and read the customer's history before it answers.
Every tool is read-only or deterministic, and the model's output is only a *decision*;
code validates it and builds quotations. `rule_decide` is the same decision made by
rules: it powers mock mode and is the fallback when the model is unavailable.
"""

import os;
import re;
import from jaclang.byllm.lib { Model, Image }
import from domain.models { Business }
import from domain.catalogue { find_product, inventory_of }
import from domain.orders { list_orders, order_lines }
import from domain.quotations { alternative_for }
import from ai.resolver { search_products, Candidate, is_clear_winner, tokenize, UNIT_WORDS, STOPWORDS }
import from ai.replies { clarify_unknown, clarify_which, clarify_quantity, welcome, kes }

def make_default_model() -> any {
    return Model(model_name=os.environ.get("LLM_MODEL", "gemini/gemini-3.5-flash-lite"));
}

# Tests replace this with a scripted MockLLM.
glob llm: any = make_default_model();

glob GREETINGS: list[str] = [
    "habari", "mambo", "hello", "hi", "hey", "sasa", "niaje", "vipi", "jambo", "salaam", "good",
    "morning", "evening", "karibu", "asante", "thanks", "poa", "shikamoo", "yako", "yenu", "gani",
    "msee", "mse", "buda", "bro", "boss", "manze", "manzee", "tafadhali", "please", "pls", "naomba", "sir", "madam"
];

# ---------- data the model fills or the tools return ----------

obj DecisionLine {
    has sku: str,
        quantity: int;
}
sem DecisionLine.sku = "SKU exactly as returned by search_catalogue. Never invent one.";
sem DecisionLine.quantity = "Whole number of units the customer asked for. Never guess; ask instead.";

obj AgentDecision {
    has action: str,
        lines: list[DecisionLine] = [],
        reply: str = "";
}
sem AgentDecision.action = "QUOTE when the items and quantities are clear (fill lines), CLARIFY to ask the customer one short question, ANSWER to reply without ordering (greetings, catalogue questions), ESCALATE when you cannot help and the wholesaler should take over.";
sem AgentDecision.lines = "Only for QUOTE: the products from the customer's LATEST message. Do not repeat items already in an open draft or quotation; the system merges them.";
sem AgentDecision.reply = "For CLARIFY or ANSWER: a short message in the language the customer used. Leave empty for QUOTE. Mention a price only if a tool returned it.";

obj ParsedLine {
    has text: str,
        quantity: int = 0,
        uncertain: bool = False,
        note: str = "";
}
sem ParsedLine.text = "The line as written on the list, for example 'rina 1L carton'.";
sem ParsedLine.quantity = "Quantity written next to the item, or 0 if none is legible.";
sem ParsedLine.uncertain = "True if the handwriting is unclear or the item or quantity is ambiguous.";
sem ParsedLine.note = "Why it is uncertain, in a few words.";

obj ParsedList {
    has is_order: bool,
        lines: list[ParsedLine] = [];
}
sem ParsedList.is_order = "True only if the photo shows a list of products someone wants to order.";
sem ParsedList.lines = "One entry per list line, in reading order. Empty if the photo is not an order.";

obj StockCheck {
    has sku: str,
        name: str,
        requested: int,
        available: int,
        shortfall: int,
        price_kes: int;
}

obj PastLine {
    has sku: str,
        name: str,
        quantity: int;
}

obj PastOrder {
    has order_id: str,
        created_at: str,
        status: str,
        total_kes: int,
        lines: list[PastLine];
}

obj RunState {
    has biz: Business,
        customer_id: str,
        trace: list[str] = [],
        prices: list[int] = [];
}

glob RUNS: dict[str, RunState] = {};

# ---------- tools (read-only or deterministic) ----------

def tool_search(state: RunState, query: str, unit_hint: str = "") -> list[Candidate] {
    found = search_products(state.biz, query, unit_hint);
    for c in found { state.prices.append(c.price_kes); }
    state.trace.append(f"search_catalogue({query!r}) -> {[c.sku for c in found]}");
    return found;
}

def tool_stock(state: RunState, sku: str, quantity: int) -> StockCheck {
    p = find_product(state.biz, sku);
    if p is None or not p.active {
        state.trace.append(f"check_stock({sku}) -> not found");
        return StockCheck(sku=sku, name="", requested=quantity, available=0, shortfall=quantity, price_kes=0);
    }
    avail = max(inventory_of(p).available(), 0);
    state.prices.append(p.price_kes);
    state.trace.append(f"check_stock({p.sku}, {quantity}) -> available {avail}");
    return StockCheck(sku=p.sku, name=p.name, requested=quantity, available=avail,
                      shortfall=max(quantity - avail, 0), price_kes=p.price_kes);
}

def tool_alternatives(state: RunState, sku: str, quantity: int) -> list[Candidate] {
    out: list[Candidate] = [];
    for (asku, aname, avail, price) in alternative_for(state.biz, sku, quantity)[:3] {
        p = find_product(state.biz, asku);
        out.append(Candidate(sku=asku, name=aname, unit=p.unit if p else "", price_kes=price,
                             available=avail, category=p.category if p else ""));
        state.prices.append(price);
    }
    state.trace.append(f"suggest_alternatives({sku}, {quantity}) -> {[c.sku for c in out]}");
    return out;
}

def tool_recent(state: RunState) -> list[PastOrder] {
    mine = [o for o in list_orders(state.biz) if o.customer_id == state.customer_id][:3];
    out = [
        PastOrder(order_id=o.order_id, created_at=o.created_at, status=o.status, total_kes=o.total_kes,
                  lines=[PastLine(sku=l.product_sku, name=l.product_name, quantity=l.quantity) for l in order_lines(o)])
        for o in mine
    ];
    state.trace.append(f"recent_orders() -> {[o.order_id for o in out]}");
    return out;
}

# ---------- the model-facing object ----------

obj Brain {
    has run_id: str;

    def search_catalogue(query: str, unit_hint: str = "") -> list[Candidate] {
        return tool_search(RUNS[self.run_id], query, unit_hint);
    }

    def check_stock(sku: str, quantity: int) -> StockCheck {
        return tool_stock(RUNS[self.run_id], sku, quantity);
    }

    def suggest_alternatives(sku: str, quantity: int) -> list[Candidate] {
        return tool_alternatives(RUNS[self.run_id], sku, quantity);
    }

    def recent_orders() -> list[PastOrder] {
        return tool_recent(RUNS[self.run_id]);
    }

    def decide(message: str, history: str, open_quote: str, language: str) -> AgentDecision by llm(
        tools=[self.search_catalogue, self.check_stock, self.suggest_alternatives, self.recent_orders],
        max_react_iterations=4,
        temperature=0.1
    );

    def read_list(photo: Image, caption: str) -> ParsedList by llm(temperature=0.0);
}

sem Brain.search_catalogue = "Search the wholesaler's catalogue by product name, brand or alias in English, Swahili or Sheng. Returns ranked candidates with SKU, price in whole KSh and units available.";
sem Brain.search_catalogue.query = "What the customer wrote for this product, e.g. 'mafuta ya Rina 1 litre'.";
sem Brain.search_catalogue.unit_hint = "Packaging unit the customer mentioned (carton, bale, dozen, bag, crate), or empty.";
sem Brain.check_stock = "Check how many units of a SKU are available now, and the shortfall against a requested quantity.";
sem Brain.check_stock.sku = "A SKU returned by search_catalogue.";
sem Brain.check_stock.quantity = "The quantity the customer asked for.";
sem Brain.suggest_alternatives = "List in-stock substitutes from the same category that can cover a requested quantity.";
sem Brain.suggest_alternatives.sku = "The SKU that is short.";
sem Brain.suggest_alternatives.quantity = "The quantity still needed.";
sem Brain.recent_orders = "The customer's last orders with their CURRENT STATUS and totals. Use it for 'the usual' / 'same as last time' and for any question about an order's status.";
sem Brain.decide = "You are the order desk assistant of a Kenyan wholesaler, chatting with a retailer who may write English, Swahili or Sheng. Decide what to do with the customer's latest message. Use the tools to find products and check stock; never invent SKUs, prices or stock. RULES: (1) You cannot place orders and must never say an order was placed, added or confirmed. To start an order, return action QUOTE with the products and quantities the customer asked for: the system will then build a priced quotation and ask the customer to confirm. (2) Stock shortages and substitutions are handled by the system when it builds the quotation, so do NOT ask about them: if the products and quantities are clear, return QUOTE with the full requested quantities even when stock is short. (3) For 'the usual' or 'same as last time', call recent_orders and return QUOTE with those lines. For questions about an existing order (status, delivery, what was ordered) call recent_orders and ANSWER from its result; the conversation history shows what was said before, use it to resolve words like 'it' or 'that order'. (4) If an item or quantity is genuinely unclear, or the customer asks which of several products they want, return CLARIFY with one short question; lines marked UNCERTAIN come from a photo and must be asked about, not guessed. (5) Use ANSWER only for greetings, catalogue or price questions, and things you do not stock. (6) Items from earlier orders or quotations in the history are finished business: never include them in a new QUOTE unless the customer asks for 'the usual' or 'same again'. (7) Reply in the customer's language, given in `language`: en = plain English, sw = Swahili, sh = Sheng (casual Nairobi Swahili-English street mix). Match the customer's register; never switch language on your own. Spell product names exactly as the tools return them and mention a price only if a tool returned it.";
sem Brain.decide.message = "The customer's latest message (or a transcript of their photographed list).";
sem Brain.decide.history = "The last few messages of this conversation, oldest first.";
sem Brain.decide.open_quote = "A summary of the open draft or quotation, or 'none'.";
sem Brain.decide.language = "The customer's language: en, sw or sh. Write any reply in it.";
sem Brain.read_list = "Read a photo of a handwritten order list and return each line. Mark unclear lines as uncertain; if the photo is not an order list, set is_order to false.";
sem Brain.read_list.photo = "The photo.";
sem Brain.read_list.caption = "Text the customer sent with the photo, possibly empty.";

# ---------- the rule-based decision (mock mode and fallback) ----------

def split_chunks(text: str) -> list[str] {
    parts = re.split(r"\s*(?:,|;|\+|&|\n|\band\b|\bna\b)\s*", text.lower());
    return [p.strip() for p in parts if p.strip()];
}

def first_quantity(chunk: str) -> int {
    nums = [int(t) for t in tokenize(chunk) if t.isdigit()];
    return nums[0] if nums else 0;
}

def unit_of(chunk: str) -> str {
    for t in tokenize(chunk) {
        if t in UNIT_WORDS { return UNIT_WORDS[t]; }
    }
    return "";
}

def is_greeting_chunk(chunk: str) -> bool {
    words = re.findall(r"[a-z]+", chunk);
    return len(words) > 0 and all([(w in GREETINGS or w in STOPWORDS) for w in words]);
}

def clean_name(chunk: str) -> str {
    return " ".join([w for w in re.findall(r"[a-z0-9]+", chunk) if not w.isdigit() and w not in UNIT_WORDS]).strip() or chunk;
}

"""Decide by rules: resolve each chunk of the message against the catalogue."""
def rule_decide(state: RunState, text: str, lang: str = "en") -> AgentDecision {
    from_text = text.lower();
    if re.search(r"kawaida|the usual|same as (last|before)|kama jana", from_text) {
        past = tool_recent(state);
        if not past or not past[0].lines {
            return AgentDecision(action="CLARIFY", reply=(
                "Sioni oda yako ya awali. Niambie unachohitaji." if lang in ["sw", "sh"] else "I don't see a previous order. Tell me what you need."
            ));
        }
        return AgentDecision(action="QUOTE", lines=[DecisionLine(sku=l.sku, quantity=l.quantity) for l in past[0].lines]);
    }
    lines: list[DecisionLine] = [];
    unknown: list[str] = [];
    for ch in split_chunks(text) {
        if is_greeting_chunk(ch) { continue; }
        qty = first_quantity(ch);
        cands = tool_search(state, ch, unit_of(ch));
        if not cands {
            unknown.append(clean_name(ch));
            continue;
        }
        if not is_clear_winner(cands) {
            close = [c for c in cands if c.score >= cands[0].score - 1][:3];
            opts = [f"{c.name} ({kes(c.price_kes)})" for c in close];
            return AgentDecision(action="CLARIFY", reply=clarify_which(lang, clean_name(ch), opts));
        }
        if qty < 1 {
            return AgentDecision(action="CLARIFY", reply=clarify_quantity(lang, cands[0].name));
        }
        lines.append(DecisionLine(sku=cands[0].sku, quantity=qty));
    }
    if unknown {
        return AgentDecision(action="CLARIFY", reply=clarify_unknown(lang, unknown));
    }
    if not lines {
        return AgentDecision(action="ANSWER", reply=welcome(lang));
    }
    return AgentDecision(action="QUOTE", lines=lines);
}
