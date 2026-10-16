"""Product resolver: turns what a customer wrote ("mafuta ya Rina 1 litre") into ranked
catalogue candidates. Pure and deterministic; the agent's search tool calls this."""

import re;
import from domain.models { Business, Product }
import from domain.catalogue { list_products, inventory_of }

glob STOPWORDS: list[str] = [
    "nipe", "niletee", "naomba", "nataka", "tafadhali", "please", "i", "want", "need", "send",
    "me", "ya", "za", "wa", "kwa", "na", "and", "of", "the", "a", "an", "for", "order", "oda",
    "kama", "kawaida", "pia", "tu", "hii", "hizi", "ile", "yale", "moja"
];

glob UNIT_WORDS: dict[str, str] = {
    "carton": "carton", "cartons": "carton", "ctn": "carton", "kartoni": "carton",
    "bale": "bale", "bales": "bale", "dozen": "dozen", "dozens": "dozen", "dz": "dozen",
    "bag": "bag", "bags": "bag", "gunia": "bag", "crate": "crate", "crates": "crate",
    "piece": "piece", "pieces": "piece", "pcs": "piece", "bottle": "bottle", "bottles": "bottle",
    "packet": "packet", "packets": "packet", "kg": "kg", "litre": "litre", "litres": "litre"
};

obj Candidate {
    has sku: str,
        name: str,
        unit: str,
        price_kes: int,
        available: int,
        category: str,
        score: int = 0;
}

"""Lowercase, join sizes ("1 litre" -> "1l", "2 kg" -> "2kg") and split into words."""
def tokenize(text: str) -> list[str] {
    t = text.lower();
    t = re.sub(r"(\d+)\s*(litres?|liters?|ltrs?|l)\b", r"\1l", t);
    t = re.sub(r"(\d+)\s*(kgs?|kilos?|kilograms?)\b", r"\1kg", t);
    t = re.sub(r"(\d+)\s*(grams?|gms?|g)\b", r"\1g", t);
    t = re.sub(r"(\d+)\s*ml\b", r"\1ml", t);
    return [w for w in re.findall(r"[a-z0-9]+", t)];
}

def product_tokens(p: Product) -> list[str] {
    words: list[str] = tokenize(p.name) + tokenize(p.brand) + tokenize(p.category);
    for a in p.aliases { words = words + tokenize(a); }
    return words;
}

"""Rank active products for a free-text query. Brand and size words weigh more than generic words."""
def search_products(biz: Business, query: str, unit_hint: str = "", limit: int = 5) -> list[Candidate] {
    words = [w for w in tokenize(query) if w not in STOPWORDS and not (w in UNIT_WORDS) and not w.isdigit()];
    unit = UNIT_WORDS.get(unit_hint.strip().lower(), unit_hint.strip().lower());
    if not words { return []; }
    ranked: list[Candidate] = [];
    for p in list_products(biz) {
        ptoks = product_tokens(p);
        brand = tokenize(p.brand);
        score = 0;
        hit = 0;
        for w in words {
            if w in ptoks {
                hit += 1;
                if w in brand { score += 3; }
                elif re.match(r"^\d+[a-z]+$", w) { score += 3; }
                else { score += 2; }
            }
        }
        for a in p.aliases {
            if a and a in query.lower() { score += 4; }
        }
        if hit == 0 { continue; }
        if unit and p.unit == unit { score += 1; }
        if p.sku.lower() in query.lower() { score += 6; }
        rec = inventory_of(p);
        ranked.append(Candidate(
            sku=p.sku, name=p.name, unit=p.unit, price_kes=p.price_kes,
            available=rec.available(), category=p.category, score=score
        ));
    }
    ranked = sorted(ranked, key=lambda (c: Candidate) { (-c.score, c.name); });
    return ranked[:limit];
}

"""True when exactly one candidate clearly wins (a strictly higher score than the runner-up)."""
def is_clear_winner(cands: list[Candidate]) -> bool {
    if not cands { return False; }
    if len(cands) == 1 { return True; }
    return cands[0].score > cands[1].score;
}
