"""The radar's action planner: what the wholesaler should DO about an alert.

Candidate actions and every figure are computed by code from the catalogue, stock and sales.
Nothing runs until the wholesaler clicks; each click is audited."""

import json;
import re;
import from datetime { datetime }
import from domain.models {
    Business, Product, RegNotice, ComplianceAlert, AlertAction, HasAction
}
import from domain.errors { DomainError }
import from domain.catalogue { inventory_of, get_product }
import from domain.catalogue { update_product }
import from domain.orders { list_orders, order_lines }
import from domain.customers { find_customer }
import from domain.messaging { get_or_create_conversation, list_messages, record_outbound }
import from domain.audit { record_audit_event }
import from domain.clock { now_iso }
import from domain.pricing { format_kes }
import from domain.compliance {
    alert_products, alert_actions, sales_by_sku, days_until, get_alert, find_action, action_alert, SkuSales
}
import from ai.replies { detect_lang, pick }

glob MONTH_SHORT: list[str] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
glob MAX_STOCKUP_DAYS: int = 30;
glob ROUND_TO_KES: int = 10;

def nice_date(iso: str) -> str {
    if len(iso) < 10 { return ""; }
    return str(int(iso[8:10])) + " " + MONTH_SHORT[int(iso[5:7]) - 1] + " " + iso[:4];
}

"""A percentage rate as a number: '16%' -> 16.0, 'nil' -> 0.0. Anything compound or non-numeric -> None."""
def rate_number(rate: str) -> float | None {
    r = rate.lower().strip();
    if r == "nil" { return 0.0; }
    if "ksh" in r or "per kg" in r or " or " in r or "%" not in r { return None; }
    found = re.findall(r"\d+(?:\.\d+)?", r);
    return float(found[0]) if len(found) == 1 else None;
}

"""Pass a tax change through to the price: price x (100 + after) / (100 + before), rounded up to KSh 10."""
def pass_through_price(price: int, before: float, after: float) -> int {
    raw = price * (100.0 + after) / (100.0 + before);
    return int(-(-raw // ROUND_TO_KES) * ROUND_TO_KES);
}

def new_action(
    alert: ComplianceAlert, n: int, kind: str, title: str, detail: str,
    payload: dict[str, any], impact: int = 0, due_on: str = ""
) -> AlertAction {
    a = AlertAction(
        action_id=f"{alert.alert_id}-{n}", kind=kind, title=title, detail=detail,
        impact_kes=impact, due_on=due_on, payload_json=json.dumps(payload)
    );
    alert +>:HasAction():+> a;
    return a;
}

def customer_language(biz: Business, customer_id: str) -> str {
    conv = get_or_create_conversation(biz, customer_id);
    texts = [m.content for m in list_messages(conv) if m.sender_type == "customer" and m.content];
    texts.reverse();
    return detect_lang(texts);
}

def price_notice(lang: str, name: str, products: str, date: str) -> str {
    return pick(
        lang,
        f"Hello {name}! Prices for {products} will change from {date} because of a tax change. Order before {date} to get today's prices.",
        f"Habari {name}! Bei za {products} zitabadilika kuanzia {date} kwa sababu ya mabadiliko ya kodi. Agiza kabla ya {date} upate bei za sasa.",
        f"Niaje {name}! Bei za {products} zinabadilika {date} sababu ya kodi mpya. Order kabla ya {date} ushike bei ya sasa."
    );
}

"""Customers who bought any of these SKUs in the last 30 days (orders that were not cancelled or rejected)."""
def recent_buyers(biz: Business, skus: list[str], today: str) -> list[str] {
    ids: list[str] = [];
    for o in list_orders(biz) {
        if o.status in ["CANCELLED", "REJECTED", "EXPIRED", "DRAFT"] { continue; }
        if len([l for l in order_lines(o) if l.product_sku in skus]) > 0 and o.customer_id not in ids {
            ids.append(o.customer_id);
        }
    }
    return ids;
}

"""Plan the next steps for an alert (once). Returns the actions created."""
def plan_actions(biz: Business, alert: ComplianceAlert, notice: RegNotice, today: str) -> list[AlertAction] {
    if len(alert_actions(alert)) > 0 or alert.severity == "INFO" { return alert_actions(alert); }
    products = alert_products(alert);
    sales = sales_by_sku(biz, today);
    d_raw = days_until(today, notice.effective_on);
    d = d_raw if d_raw is not None else -1;
    upcoming = d >= 0;
    before_raw = rate_number(notice.rate_before);
    after_raw = rate_number(notice.rate_after);
    before = before_raw if before_raw is not None else 0.0;
    after = after_raw if after_raw is not None else 0.0;
    numeric = before_raw is not None and after_raw is not None and before != after and notice.applies_to == "ALL";
    when = nice_date(notice.effective_on);
    n = 0;
    if notice.status in ["PROPOSED", "UNKNOWN"] {
        n += 1;
        new_action(alert, n, "WATCH", "Keep an eye on this proposal",
            "It is not law yet. The radar re-checks it each time you press Check now, and the alert gets more serious if it becomes law.", {});
    } elif notice.kind in ["TAX_RATE", "LEVY"] and numeric {
        new_prices: dict[str, int] = {};
        lines: list[str] = [];
        gain = 0;
        for p in products {
            np = pass_through_price(p.price_kes, before, after);
            new_prices[p.sku] = np;
            lines.append(f"{p.name}: {format_kes(p.price_kes)} to {format_kes(np)}");
            gain += sales.get(p.sku, SkuSales()).units * (np - p.price_kes);
        }
        n += 1;
        new_action(alert, n, "REPRICE",
            (f"Raise {len(products)} prices from {when}" if upcoming else f"Update {len(products)} prices"),
            "Passes the tax change through to your selling price. It does not include your costs or margin. " + "; ".join(lines) + ".",
            {"prices": new_prices}, impact=gain, due_on=notice.effective_on if upcoming else "");
        if after > before and upcoming {
            units: dict[str, int] = {};
            saving = 0;
            parts: list[str] = [];
            for p in products {
                sold = sales.get(p.sku, SkuSales()).units;
                if sold == 0 { continue; }
                days = min(d, MAX_STOCKUP_DAYS);
                qty = int(-(-sold * days // 30));
                units[p.sku] = qty;
                saving += qty * (new_prices[p.sku] - p.price_kes);
                parts.append(f"{p.name}: about {qty} {p.unit}s");
            }
            if len(units) > 0 {
                n += 1;
                new_action(alert, n, "STOCK_UP", f"Stock up before {when}",
                    "Buying now at today's cost. Estimated from your last 30 days of sales, capped at 30 days of cover. " + "; ".join(parts) + ".",
                    {"units": units}, impact=saving, due_on=notice.effective_on);
            }
            buyers = recent_buyers(biz, [p.sku for p in products], today);
            if len(buyers) > 0 {
                msgs: dict[str, str] = {};
                names: dict[str, str] = {};
                for cid in buyers {
                    c = find_customer(biz, cid);
                    cname = c.name if c is not None else cid;
                    names[cid] = cname;
                    msgs[cid] = price_notice(customer_language(biz, cid), cname, names_text_short(products), when);
                }
                n += 1;
                new_action(alert, n, "NOTIFY_CUSTOMERS", f"Tell {len(buyers)} customers before {when}",
                    "These customers bought these products in the last 30 days. Review and edit each message before it is sent to their chat.",
                    {"messages": msgs, "names": names}, due_on=notice.effective_on);
            }
        }
    } elif notice.kind in ["TAX_RATE", "LEVY"] {
        n += 1;
        new_action(alert, n, "REVIEW_PRICES", f"Check supplier prices for {len(products)} products",
            "The notice gives no rate you can pass straight through (or it only covers imports). Ask your suppliers whether prices changed, then update the catalogue: " + ", ".join([p.name for p in products[:6]]) + ".", {});
    } elif notice.kind == "STANDARD" {
        stock = [f"{p.name}: {inventory_of(p).available()} on hand" for p in products[:8]];
        n += 1;
        new_action(alert, n, "CHECK_STOCK", "Check your stock against the standard", "; ".join(stock) + ".", {});
        if notice.status == "IN_FORCE" {
            n += 1;
            new_action(alert, n, "PAUSE_PRODUCT", f"Pause {len(products)} products until checked",
                "Paused products are no longer quoted by the order agent. You can switch them back on in Products and stock.",
                {"skus": [p.sku for p in products]});
        }
    } else {
        n += 1;
        new_action(alert, n, "REMINDER", "Make sure you comply",
            notice.summary, {}, due_on=notice.effective_on if upcoming else "");
    }
    return alert_actions(alert);
}

def names_text_short(products: list[Product]) -> str {
    return ", ".join([p.name for p in products[:3]]) + (" and more" if len(products) > 3 else "");
}

# ---------- running an action (only ever from an endpoint) ----------

def payload_of(action: AlertAction) -> dict[str, any] {
    return json.loads(action.payload_json);
}

"""Move an alert to HANDLED once every action is done or skipped."""
def refresh_alert_status(alert: ComplianceAlert) {
    acts = alert_actions(alert);
    if len(acts) > 0 and len([a for a in acts if a.status == "SUGGESTED"]) == 0 and alert.status == "NEW" {
        alert.status = "HANDLED";
    }
}

def finish(biz: Business, action: AlertAction, status: str, actor: str) {
    action.status = status;
    action.done_at = now_iso();
    record_audit_event(biz, actor, "RADAR_ACTION_" + status, action.action_id, "SUGGESTED", status, action.title);
    alert = action_alert(biz, action);
    if alert is not None { refresh_alert_status(alert); }
}

def require_action(biz: Business, action_id: str) -> AlertAction {
    a = find_action(biz, action_id);
    if a is None { raise DomainError("ACTION_NOT_FOUND", "That action does not exist."); }
    if a.status != "SUGGESTED" { raise DomainError("ACTION_ALREADY_DONE", "That action is already done or skipped."); }
    return a;
}

"""Apply the suggested prices to the catalogue (audited price changes). Returns the number changed."""
def apply_prices(biz: Business, action_id: str, actor: str = "wholesaler") -> int {
    a = require_action(biz, action_id);
    if a.kind != "REPRICE" { raise DomainError("WRONG_ACTION", "This action does not change prices."); }
    prices = payload_of(a).get("prices", {});
    for (sku, price) in prices.items() {
        get_product(biz, sku);
        update_product(biz, sku, price_kes=int(price), actor=actor);
    }
    finish(biz, a, "DONE", actor);
    return len(prices);
}

"""Post the (possibly edited) messages into each customer's chat. Returns how many were sent."""
def send_messages(biz: Business, action_id: str, edits: dict[str, str], actor: str = "wholesaler") -> int {
    a = require_action(biz, action_id);
    if a.kind != "NOTIFY_CUSTOMERS" { raise DomainError("WRONG_ACTION", "This action does not send messages."); }
    msgs = payload_of(a).get("messages", {});
    sent = 0;
    for cid in msgs.keys() {
        if cid not in edits { continue; }
        text = edits[cid].strip();
        if len(text) == 0 { continue; }
        if len(text) > 600 { raise DomainError("MESSAGE_TOO_LONG", "Keep each message under 600 characters."); }
        if find_customer(biz, cid) is None { continue; }
        record_outbound(biz, cid, text);
        sent += 1;
    }
    if sent == 0 { raise DomainError("NOTHING_TO_SEND", "Select at least one customer with a message."); }
    finish(biz, a, "DONE", actor);
    return sent;
}

"""Switch the affected products off so the order agent stops quoting them."""
def pause_products(biz: Business, action_id: str, actor: str = "wholesaler") -> int {
    a = require_action(biz, action_id);
    if a.kind != "PAUSE_PRODUCT" { raise DomainError("WRONG_ACTION", "This action does not pause products."); }
    skus = payload_of(a).get("skus", []);
    for sku in skus { update_product(biz, sku, active=False, actor=actor); }
    finish(biz, a, "DONE", actor);
    return len(skus);
}

"""Mark an advice-only action (check stock, reminder, watch...) Done or Skipped."""
def set_action_status(biz: Business, action_id: str, status: str, actor: str = "wholesaler") -> AlertAction {
    if status not in ["DONE", "SKIPPED"] { raise DomainError("BAD_STATUS", "Status must be DONE or SKIPPED."); }
    a = require_action(biz, action_id);
    if status == "DONE" and a.kind in ["REPRICE", "NOTIFY_CUSTOMERS", "PAUSE_PRODUCT"] {
        raise DomainError("USE_THE_BUTTON", "Use the action's own button so the change is made.");
    }
    finish(biz, a, status, actor);
    return a;
}
