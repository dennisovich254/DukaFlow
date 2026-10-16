"""Customer-facing messages. Quotations, totals and stock figures are rendered from data by
these templates, never written by the model. Replies mirror the customer's language:
English ("en"), Swahili ("sw") or Sheng, the Nairobi street mix ("sh")."""

import re;
import from domain.models { Quotation, QuotationLine, Order }
import from domain.quotations { PlanNote }
import from domain.pricing { format_kes }

# Function words only: product names (sukari, unga, kuku...) appear in English sentences too.
glob EN_WORDS: list[str] = [
    "i", "you", "the", "my", "me", "please", "pls", "hello", "hi", "hey", "how", "what", "where",
    "when", "do", "does", "have", "has", "want", "need", "would", "like", "send", "order", "thanks",
    "thank", "is", "are", "can", "could", "with", "and", "of", "for", "to", "it", "in", "at", "this",
    "that", "your", "much", "many", "price", "cost", "status", "deliver", "delivered", "approved",
    "good", "morning", "evening", "get", "give", "got", "ordered", "same", "last", "time", "usual"
];

glob SW_WORDS: list[str] = [
    "nataka", "niletee", "nipe", "naomba", "tafadhali", "asante", "habari", "hapana", "ndiyo", "ndio",
    "kwa", "ya", "za", "wa", "na", "hii", "hizi", "huu", "yangu", "wangu", "ngapi", "bei", "gani",
    "pia", "tu", "kama", "kawaida", "mimi", "nina", "una", "unaweza", "ningependa", "niko", "uko",
    "iko", "imefika", "imetumwa", "oda", "jambo", "karibu", "pole", "nimepokea", "kuagiza", "agiza"
];

glob SHENG_WORDS: list[str] = [
    "niaje", "msee", "mse", "buda", "bro", "boss", "fiti", "manze", "manzee", "doh", "noma", "mbogi",
    "shwari", "mbao", "ngori", "jaba", "poa", "form", "dem", "sasa"
];

# "sasa" and "poa" alone are common greetings and confirmations; they only count as Sheng
# together with another Sheng or Swahili word.
glob WEAK_SHENG: list[str] = ["sasa", "poa", "form", "dem"];

"""'sh', 'sw' or 'en' for one message, or '' when it carries no language signal ("sawa", "10")."""
def detect_one(text: str) -> str {
    words = re.findall(r"[a-z]+", text.lower());
    en = len([w for w in words if w in EN_WORDS]);
    sw = len([w for w in words if w in SW_WORDS]);
    strong = len([w for w in words if w in SHENG_WORDS and w not in WEAK_SHENG]);
    weak = len([w for w in words if w in WEAK_SHENG]);
    if strong >= 1 { return "sh"; }
    if weak >= 1 and sw >= 1 and en == 0 { return "sh"; }
    if sw > en { return "sw"; }
    if en > sw { return "en"; }
    if sw > 0 and sw == en { return "sw"; }
    return "";
}

"""The customer's language: the newest message that shows one (texts are newest first)."""
def detect_lang(texts: list[str]) -> str {
    for t in texts {
        d = detect_one(t);
        if d { return d; }
    }
    return "en";
}

def lang_of(text: str) -> str {
    return detect_lang([text]);
}

def pick(lang: str, en: str, sw: str, sh: str) -> str {
    if lang == "sh" { return sh; }
    if lang == "sw" { return sw; }
    return en;
}

def kes(amount: int) -> str {
    return format_kes(amount);
}

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

glob STATUS_SH: dict[str, str] = {
    "DRAFT": "inaandaliwa", "QUOTED": "imepewa bei", "PENDING_APPROVAL": "inangoja muuzaji aipitishe",
    "APPROVED": "imepita na inaandaliwa", "PACKED": "imepakiwa, iko ready", "DISPATCHED": "iko njiani, inakuja",
    "DELIVERED": "imefika", "REJECTED": "haijapita", "CANCELLED": "imefutwa", "EXPIRED": "imeexpire"
};

def status_label(lang: str, status: str) -> str {
    table = STATUS_SH if lang == "sh" else (STATUS_SW if lang == "sw" else STATUS_EN);
    return table.get(status, status.lower());
}

def welcome(lang: str) -> str {
    return pick(lang,
        "Welcome to DukaFlow! Tell me the products you need, or send a photo of your list.",
        "Karibu DukaFlow! Tuambie bidhaa unazohitaji.",
        "Niaje! Karibu DukaFlow. Niambie unataka nini, au tuma picha ya list yako.");
}

def holding(lang: str) -> str {
    return pick(lang,
        "Sorry, I'm having trouble right now. The wholesaler has been notified and will reply soon.",
        "Samahani, nina shida kidogo sasa hivi. Muuzaji amejulishwa na atakujibu hivi karibuni.",
        "Pole msee, kuna shida kidogo. Muuzaji ameambiwa, atakujibu sasa hivi.");
}

def too_long(lang: str) -> str {
    return pick(lang,
        "That message is too long. Please send your order in a shorter message.",
        "Ujumbe ni mrefu sana. Tafadhali tuma oda kwa ufupi.",
        "Ujumbe ni mrefu sana. Tuma oda fupi poa.");
}

def too_many_lines(lang: str) -> str {
    return pick(lang,
        "That list is too long to handle at once. Please send it in smaller parts.",
        "Orodha ni ndefu sana kwa mara moja. Tafadhali tuma sehemu kwa sehemu.",
        "List ni ndefu sana. Tuma kipande kwa kipande.");
}

def not_an_order(lang: str) -> str {
    return pick(lang,
        "I couldn't see an order in that photo. Please send a clear photo of your list, or type your order.",
        "Sikuona oda kwenye picha hiyo. Tafadhali tuma picha safi ya orodha yako au andika oda yako.",
        "Sijaona oda kwa hiyo picha. Tuma picha safi ya list yako au andika oda.");
}

def nothing_to_confirm(lang: str) -> str {
    return pick(lang,
        "There is nothing to confirm yet. What would you like to order?",
        "Hakuna oda ya kuthibitisha kwa sasa. Ungependa kuagiza nini?",
        "Hakuna oda ya kuconfirm sasa. Unataka nini?");
}

def quote_expired(lang: str) -> str {
    return pick(lang,
        "That quotation has expired. Please tell me what you need again and I'll send a fresh quote.",
        "Bei hiyo imeisha muda. Tafadhali niambie tena unachohitaji nikupe bei mpya.",
        "Bei hiyo imeexpire. Niambie tena unataka nini nikupe mpya.");
}

def cancelled(lang: str) -> str {
    return pick(lang,
        "No problem, I've cancelled that quote. What would you like to change?",
        "Sawa, nimeghairi. Ungependa kubadilisha nini?",
        "Poa, nimeifuta. Unataka kubadilisha nini?");
}

def order_placed(lang: str, order_id: str, total: int) -> str {
    return pick(lang,
        f"Done! Order {order_id} ({kes(total)}) is with the wholesaler for approval. I'll message you when it's approved.",
        f"Sawa! Oda {order_id} ({kes(total)}) imetumwa kwa muuzaji kwa idhini. Nitakujulisha ikikubaliwa.",
        f"Fiti! Oda {order_id} ({kes(total)}) imeenda kwa muuzaji aipitishe. Nitakujulisha ikipita.");
}

def note_text(lang: str, n: PlanNote) -> str {
    if n.kind == "UNAVAILABLE" {
        return pick(lang,
            f"{n.name} is out of stock right now.",
            f"{n.name} haipatikani kwa sasa.",
            f"{n.name} imeisha sasa hivi.");
    }
    if n.alt_sku != "" {
        return pick(lang,
            f"{n.name}: only {n.available} available; I added {n.alt_qty} × {n.alt_name} ({kes(n.alt_price)}) for the rest.",
            f"{n.name}: zilizopo ni {n.available} tu; nimeongeza {n.alt_qty} × {n.alt_name} ({kes(n.alt_price)}) kwa zilizobaki.",
            f"{n.name}: zimebaki {n.available} tu; nimeongeza {n.alt_qty} × {n.alt_name} ({kes(n.alt_price)}) kwa zilizobaki.");
    }
    return pick(lang,
        f"{n.name}: only {n.available} available.",
        f"{n.name}: zilizopo ni {n.available} tu.",
        f"{n.name}: zimebaki {n.available} tu.");
}

"""The quotation message: every line, price and total comes from the quotation data."""
def quote_reply(lang: str, q: Quotation, lines: list[QuotationLine], notes: list[PlanNote]) -> str {
    head = pick(lang, "Here is your quote:", "Hii hapa bei yako:", "Hii hapa bei yako:");
    rows = [f"• {l.quantity} × {l.product_name}: {kes(l.line_total_kes)}" for l in lines];
    total = pick(lang, "Total: ", "Jumla: ", "Jumla: ") + kes(q.total_kes);
    tail = pick(lang,
        "Reply 'sawa' to confirm, or tell me what to change.",
        "Jibu 'sawa' kuthibitisha, au niambie nini cha kubadilisha.",
        "Sema 'poa' kuconfirm, au niambie ubadilishe nini.");
    parts = [head] + rows + [total];
    for n in notes { parts.append(note_text(lang, n)); }
    parts.append(tail);
    return "\n".join(parts);
}

def clarify_unknown(lang: str, names: list[str]) -> str {
    joined = ", ".join(names);
    return pick(lang,
        f"I couldn't find this in our catalogue: {joined}. Could you tell me another name, or ask what we stock?",
        f"Sijapata bidhaa hii kwenye orodha yetu: {joined}. Unaweza kuniambia jina lingine au uniulize tulicho nacho?",
        f"Sijapata hii kwa list yetu: {joined}. Niambie jina lingine, au uliza tulicho nacho.");
}

def clarify_which(lang: str, wanted: str, options: list[str]) -> str {
    joined = "; ".join(options);
    return pick(lang,
        f"Which one do you mean by '{wanted}'? {joined}",
        f"Unamaanisha ipi kwa '{wanted}'? {joined}",
        f"Unamaanisha ipi kwa '{wanted}'? {joined}");
}

def clarify_quantity(lang: str, wanted: str) -> str {
    return pick(lang,
        f"How many of {wanted} would you like?",
        f"Unahitaji ngapi ya {wanted}?",
        f"Unataka ngapi ya {wanted}?");
}

def clarify_photo(lang: str, understood: list[str], unclear: list[str]) -> str {
    seen = "; ".join(understood);
    odd = "; ".join(unclear);
    en = (f"I read: {seen}. " if understood else "") + f"I couldn't read this clearly: {odd}. Please tell me which product and how many.";
    sw = (f"Nimesoma: {seen}. " if understood else "") + f"Sikuweza kusoma wazi: {odd}. Tafadhali niambie ni bidhaa gani na ngapi.";
    sh = (f"Nimesoma: {seen}. " if understood else "") + f"Sijaelewa hii: {odd}. Niambie ni bidhaa gani na ngapi.";
    return pick(lang, en, sw, sh);
}

"""A model-written reply may only mention prices that came from the tools in this run."""
def reply_is_safe(text: str, allowed_prices: list[int]) -> bool {
    for m in re.findall(r"KSh\s*([0-9][0-9,]*)", text) {
        value = int(m.replace(",", ""));
        if value not in allowed_prices { return False; }
    }
    return True;
}

"""Answer 'where is my order?' from the orders themselves: (order_id, status, total_kes) newest first."""
def status_reply(lang: str, orders: list[tuple[str, str, int]]) -> str {
    if not orders {
        return pick(lang,
            "You have no orders yet. What would you like to order?",
            "Bado hujafanya oda yoyote. Ungependa kuagiza nini?",
            "Bado hujaweka oda yoyote. Unataka nini?");
    }
    head = pick(lang, "Your latest orders:", "Hali ya oda zako:", "Hali ya oda zako:");
    rows = [f"• {oid} ({kes(total)}): {status_label(lang, status)}" for (oid, status, total) in orders];
    return "\n".join([head] + rows);
}

"""The message sent to the customer when the wholesaler changes the order's status."""
def order_update(lang: str, order_id: str, status: str, total: int) -> str {
    label = status_label(lang, status);
    if status == "APPROVED" {
        return pick(lang,
            f"Good news! Order {order_id} ({kes(total)}) has been approved and is being prepared.",
            f"Habari njema! Oda {order_id} ({kes(total)}) imekubaliwa na inaandaliwa.",
            f"Habari njema! Oda {order_id} ({kes(total)}) imepita na inaandaliwa.");
    }
    if status == "DISPATCHED" {
        return pick(lang,
            f"Order {order_id} has been dispatched and is on its way to you.",
            f"Oda {order_id} imetumwa na iko njiani kwako.",
            f"Oda {order_id} imetumwa, iko njiani inakuja.");
    }
    if status == "DELIVERED" {
        return pick(lang,
            f"Order {order_id} has been delivered. Thank you for your business!",
            f"Oda {order_id} imefika. Asante kwa kununua nasi!",
            f"Oda {order_id} imefika. Asante msee!");
    }
    if status == "REJECTED" {
        return pick(lang,
            f"Sorry, order {order_id} could not be approved. The wholesaler will be in touch.",
            f"Samahani, oda {order_id} haikukubaliwa. Muuzaji atawasiliana nawe.",
            f"Pole, oda {order_id} haijapita. Muuzaji atakuita.");
    }
    return pick(lang, f"Order {order_id} is now {label}.", f"Oda {order_id}: {label}.", f"Oda {order_id}: {label}.");
}

def is_status_question(text: str) -> bool {
    low = text.lower();
    if re.search(r"\d", low) or len(low.split()) > 12 { return False; }
    return bool(re.search(
        r"status|where is my|where's my|hali ya|oda yangu|order yangu|imefika|iko wapi|my order|my orders|has it (been )?(approved|dispatched|delivered)|imetumwa\?|imekubaliwa\?|imefika\?",
        low
    ));
}
