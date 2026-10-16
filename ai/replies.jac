"""Customer-facing messages. Quotations, totals and stock figures are rendered from data by
these templates, never written by the model. Replies mirror the customer's language."""

import re;
import from domain.models { Quotation, QuotationLine, Order }
import from domain.quotations { PlanNote }

glob STATUS_EN: dict[str, str] = {
    "DRAFT": "being prepared", "QUOTED": "quoted", "PENDING_APPROVAL": "waiting for the wholesaler's approval",
    "APPROVED": "approved and being prepared", "PACKED": "packed and ready", "DISPATCHED": "on its way to you",
    "DELIVERED": "delivered", "REJECTED": "not approved", "CANCELLED": "cancelled", "EXPIRED": "expired"
};

glob STATUS_SW: dict[str, str] = {
    "DRAFT": "inaandaliwa", "QUOTED": "imetolewa bei", "PENDING_APPROVAL": "inasubiri idhini ya muuzaji",
    "APPROVED": "imekubaliwa na inaandaliwa", "PACKED": "imefungwa na iko tayari", "DISPATCHED": "iko njiani kwako",
    "DELIVERED": "imefika", "REJECTED": "haikukubaliwa", "CANCELLED": "imeghairiwa", "EXPIRED": "imeisha muda"
};

glob SWAHILI_WORDS: list[str] = [
    "nipe", "niletee", "naomba", "nataka", "tafadhali", "sawa", "ndio", "ndiyo", "hapana", "asante",
    "habari", "kama", "kawaida", "za", "ya", "kwa", "na", "mimi", "pia", "hii", "kuku", "samaki",
    "mafuta", "unga", "sukari", "chumvi", "sabuni", "mchele", "maharagwe", "bei", "oda", "mambo"
];

def kes(amount: int) -> str {
    digits = str(abs(amount));
    groups: list[str] = [];
    while len(digits) > 3 {
        groups = [digits[len(digits) - 3:]] + groups;
        digits = digits[:len(digits) - 3];
    }
    groups = [digits] + groups;
    return "KSh " + ",".join(groups);
}

"""'sw' if the text looks Swahili/Sheng, else 'en'."""
def lang_of(text: str) -> str {
    words = re.findall(r"[a-z]+", text.lower());
    hits = len([w for w in words if w in SWAHILI_WORDS]);
    return "sw" if hits >= 1 else "en";
}

def welcome(lang: str) -> str {
    if lang == "sw" { return "Karibu DukaFlow! Tuambie bidhaa unazohitaji."; }
    return "Welcome to DukaFlow! Tell me the products you need, or send a photo of your list.";
}

def holding(lang: str) -> str {
    if lang == "sw" { return "Samahani, nina shida kidogo sasa hivi. Muuzaji amejulishwa na atakujibu hivi karibuni."; }
    return "Sorry, I'm having trouble right now. The wholesaler has been notified and will reply soon.";
}

def too_long(lang: str) -> str {
    if lang == "sw" { return "Ujumbe ni mrefu sana. Tafadhali tuma oda kwa ufupi."; }
    return "That message is too long. Please send your order in a shorter message.";
}

def too_many_lines(lang: str) -> str {
    if lang == "sw" { return "Orodha ni ndefu sana kwa mara moja. Tafadhali tuma sehemu kwa sehemu."; }
    return "That list is too long to handle at once. Please send it in smaller parts.";
}

def not_an_order(lang: str) -> str {
    if lang == "sw" { return "Sikuona oda kwenye picha hiyo. Tafadhali tuma picha safi ya orodha yako au andika oda yako."; }
    return "I couldn't see an order in that photo. Please send a clear photo of your list, or type your order.";
}

def nothing_to_confirm(lang: str) -> str {
    if lang == "sw" { return "Hakuna oda ya kuthibitisha kwa sasa. Ungependa kuagiza nini?"; }
    return "There is nothing to confirm yet. What would you like to order?";
}

def quote_expired(lang: str) -> str {
    if lang == "sw" { return "Bei hiyo imeisha muda. Tafadhali niambie tena unachohitaji nikupe bei mpya."; }
    return "That quotation has expired. Please tell me what you need again and I'll send a fresh quote.";
}

def cancelled(lang: str) -> str {
    if lang == "sw" { return "Sawa, nimeghairi. Ungependa kubadilisha nini?"; }
    return "No problem, I've cancelled that quote. What would you like to change?";
}

def order_placed(lang: str, order_id: str, total: int) -> str {
    if lang == "sw" {
        return f"Sawa! Oda {order_id} ({kes(total)}) imetumwa kwa muuzaji kwa idhini. Nitakujulisha ikikubaliwa.";
    }
    return f"Done! Order {order_id} ({kes(total)}) is with the wholesaler for approval. I'll message you when it's approved.";
}

def note_text(lang: str, n: PlanNote) -> str {
    if n.kind == "UNAVAILABLE" {
        if lang == "sw" { return f"{n.name} haipatikani kwa sasa."; }
        return f"{n.name} is out of stock right now.";
    }
    if n.alt_sku != "" {
        if lang == "sw" {
            return f"{n.name}: zilizopo ni {n.available} tu; nimeongeza {n.alt_qty} × {n.alt_name} ({kes(n.alt_price)}) kwa zilizobaki.";
        }
        return f"{n.name}: only {n.available} available; I added {n.alt_qty} × {n.alt_name} ({kes(n.alt_price)}) for the rest.";
    }
    if lang == "sw" { return f"{n.name}: zilizopo ni {n.available} tu."; }
    return f"{n.name}: only {n.available} available.";
}

"""The quotation message: every line, price and total comes from the quotation data."""
def quote_reply(lang: str, q: Quotation, lines: list[QuotationLine], notes: list[PlanNote]) -> str {
    head = "Hii hapa bei yako:" if lang == "sw" else "Here is your quote:";
    rows = [f"• {l.quantity} × {l.product_name}: {kes(l.line_total_kes)}" for l in lines];
    total = ("Jumla: " if lang == "sw" else "Total: ") + kes(q.total_kes);
    tail = "Jibu 'sawa' kuthibitisha, au niambie nini cha kubadilisha." if lang == "sw" else "Reply 'sawa' to confirm, or tell me what to change.";
    parts = [head] + rows + [total];
    for n in notes { parts.append(note_text(lang, n)); }
    parts.append(tail);
    return "\n".join(parts);
}

def clarify_unknown(lang: str, names: list[str]) -> str {
    joined = ", ".join(names);
    if lang == "sw" { return f"Sijapata bidhaa hii kwenye orodha yetu: {joined}. Unaweza kuniambia jina lingine au uniulize tulicho nacho?"; }
    return f"I couldn't find this in our catalogue: {joined}. Could you tell me another name, or ask what we stock?";
}

def clarify_which(lang: str, wanted: str, options: list[str]) -> str {
    joined = "; ".join(options);
    if lang == "sw" { return f"Unamaanisha ipi kwa '{wanted}'? {joined}"; }
    return f"Which one do you mean by '{wanted}'? {joined}";
}

def clarify_quantity(lang: str, wanted: str) -> str {
    if lang == "sw" { return f"Unahitaji ngapi ya {wanted}?"; }
    return f"How many of {wanted} would you like?";
}

def clarify_photo(lang: str, understood: list[str], unclear: list[str]) -> str {
    seen = "; ".join(understood);
    odd = "; ".join(unclear);
    if lang == "sw" {
        mine = f"Nimesoma: {seen}. " if understood else "";
        return f"{mine}Sikuweza kusoma wazi: {odd}. Tafadhali niambie ni bidhaa gani na ngapi.";
    }
    mine = f"I read: {seen}. " if understood else "";
    return f"{mine}I couldn't read this clearly: {odd}. Please tell me which product and how many.";
}

"""A model-written reply may only mention prices that came from the tools in this run."""
def reply_is_safe(text: str, allowed_prices: list[int]) -> bool {
    for m in re.findall(r"KSh\s*([0-9][0-9,]*)", text) {
        value = int(m.replace(",", ""));
        if value not in allowed_prices { return False; }
    }
    return True;
}

def status_label(lang: str, status: str) -> str {
    table = STATUS_SW if lang == "sw" else STATUS_EN;
    return table.get(status, status.lower());
}

"""Answer 'where is my order?' from the orders themselves: (order_id, status, total_kes) newest first."""
def status_reply(lang: str, orders: list[tuple[str, str, int]]) -> str {
    if not orders {
        if lang == "sw" { return "Bado hujafanya oda yoyote. Ungependa kuagiza nini?"; }
        return "You have no orders yet. What would you like to order?";
    }
    head = "Hali ya oda zako:" if lang == "sw" else "Your latest orders:";
    rows = [f"• {oid} ({kes(total)}): {status_label(lang, status)}" for (oid, status, total) in orders];
    return "\n".join([head] + rows);
}

"""The message sent to the customer when the wholesaler changes the order's status."""
def order_update(lang: str, order_id: str, status: str, total: int) -> str {
    label = status_label(lang, status);
    if status == "APPROVED" {
        if lang == "sw" { return f"Habari njema! Oda {order_id} ({kes(total)}) imekubaliwa na inaandaliwa."; }
        return f"Good news! Order {order_id} ({kes(total)}) has been approved and is being prepared.";
    }
    if status == "DISPATCHED" {
        if lang == "sw" { return f"Oda {order_id} imetumwa na iko njiani kwako."; }
        return f"Order {order_id} has been dispatched and is on its way to you.";
    }
    if status == "DELIVERED" {
        if lang == "sw" { return f"Oda {order_id} imefika. Asante kwa kununua nasi!"; }
        return f"Order {order_id} has been delivered. Thank you for your business!";
    }
    if status == "REJECTED" {
        if lang == "sw" { return f"Samahani, oda {order_id} haikukubaliwa. Muuzaji atawasiliana nawe."; }
        return f"Sorry, order {order_id} could not be approved. The wholesaler will be in touch.";
    }
    if lang == "sw" { return f"Oda {order_id}: {label}."; }
    return f"Order {order_id} is now {label}.";
}

def is_status_question(text: str) -> bool {
    low = text.lower();
    if re.search(r"\d", low) or len(low.split()) > 12 { return False; }
    return bool(re.search(
        r"status|where is my|where's my|hali ya|oda yangu|order yangu|imefika|iko wapi|my order|my orders|has it (been )?(approved|dispatched|delivered)|imetumwa\?|imekubaliwa\?",
        low
    ));
}
