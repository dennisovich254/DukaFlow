"""Compliance radar data and rules: notices, alerts, matching to products, money figures, severity.

Everything here is deterministic code. The model never decides which products are affected,
what share of sales is at stake, or how severe an alert is."""

import from datetime { datetime }
import from domain.models {
    Business, Product, RegNotice, ComplianceAlert, AlertAction, HasNotice, HasAlert, AlertFor, HasAction
}
import from domain.errors { DomainError }
import from domain.catalogue { list_products }
import from domain.orders { list_orders, order_lines }
import from domain.analytics { SALES_STATUSES, day_strings }
import from domain.pricing { format_kes }

glob SEVERITIES: list[str] = ["HIGH", "MEDIUM", "LOW", "INFO"];
glob SHARE_HIGH_PCT: int = 10;

obj SkuSales {
    has revenue_kes: int = 0,
        units: int = 0;
}

def list_notices(biz: Business) -> list[RegNotice] {
    return sorted([biz ->:HasNotice:->], key=lambda (n: RegNotice) { n.notice_id; });
}

def find_notice(biz: Business, notice_id: str) -> RegNotice | None {
    for n in [biz ->:HasNotice:->] {
        if n.notice_id == notice_id { return n; }
    }
    return None;
}

def list_alerts(biz: Business) -> list[ComplianceAlert] {
    return [biz ->:HasAlert:->];
}

def find_alert(biz: Business, alert_id: str) -> ComplianceAlert | None {
    for a in [biz ->:HasAlert:->] {
        if a.alert_id == alert_id { return a; }
    }
    return None;
}

def get_alert(biz: Business, alert_id: str) -> ComplianceAlert {
    a = find_alert(biz, alert_id);
    if a is None { raise DomainError("ALERT_NOT_FOUND", "That alert does not exist."); }
    return a;
}

def alert_actions(alert: ComplianceAlert) -> list[AlertAction] {
    return sorted([alert ->:HasAction:->], key=lambda (x: AlertAction) { x.action_id; });
}

def find_action(biz: Business, action_id: str) -> AlertAction | None {
    for a in list_alerts(biz) {
        for x in [a ->:HasAction:->] {
            if x.action_id == action_id { return x; }
        }
    }
    return None;
}

def action_alert(biz: Business, action: AlertAction) -> ComplianceAlert | None {
    for a in list_alerts(biz) {
        for x in [a ->:HasAction:->] {
            if x.action_id == action.action_id { return a; }
        }
    }
    return None;
}

def alert_products(alert: ComplianceAlert) -> list[Product] {
    return [alert ->:AlertFor:->];
}

"""Revenue and units per SKU over the last `days` days (approved to delivered orders)."""
def sales_by_sku(biz: Business, today: str, days: int = 30) -> dict[str, SkuSales] {
    window = day_strings(today, days);
    out: dict[str, SkuSales] = {};
    for o in list_orders(biz) {
        if o.created_at[:10] not in window or o.status not in SALES_STATUSES { continue; }
        for l in order_lines(o) {
            cur = out.get(l.product_sku, SkuSales());
            cur.revenue_kes += l.line_total_kes;
            cur.units += int(l.quantity);
            out[l.product_sku] = cur;
        }
    }
    return out;
}

"""Active products a notice touches: by category, by keyword in the name or brand, or all (ALL)."""
def matching_products(biz: Business, notice: RegNotice) -> list[Product] {
    cats = [c.lower() for c in notice.categories];
    words = [k.lower() for k in notice.keywords];
    hits: list[Product] = [];
    for p in list_products(biz) {
        if "all" in cats or p.category.lower() in cats {
            hits.append(p);
            continue;
        }
        text = (p.name + " " + p.brand).lower();
        if len([w for w in words if w in text]) > 0 { hits.append(p); }
    }
    return hits;
}

def days_until(today: str, iso: str) -> int | None {
    try {
        return (datetime.strptime(iso, "%Y-%m-%d") - datetime.strptime(today, "%Y-%m-%d")).days;
    } except ValueError {
        return None;
    }
}

"""HIGH or MEDIUM only for rules that are law (enacted or in force); proposals are LOW; no effect is INFO."""
def severity_for(notice: RegNotice, matched: int, share_pct: int) -> str {
    if matched == 0 { return "INFO"; }
    if notice.status not in ["IN_FORCE", "ENACTED"] { return "LOW"; }
    sev = "HIGH" if share_pct >= SHARE_HIGH_PCT else "MEDIUM";
    if notice.applies_to == "IMPORTED" and sev == "HIGH" { return "MEDIUM"; }
    return sev;
}

def names_text(products: list[Product]) -> str {
    names = [p.name for p in products[:3]];
    return ", ".join(names) + (f" and {len(products) - 3} more" if len(products) > 3 else "");
}

"""Plain-language effect, filled from computed facts only (no model-written numbers)."""
def effect_text(notice: RegNotice, matched: list[Product], sales_kes: int, share_pct: int) -> str {
    if len(matched) == 0 {
        return "No product in your catalogue is affected.";
    }
    n = len(matched);
    text = f"{notice.summary} It touches {n} of your products ({names_text(matched)}). They made {format_kes(sales_kes)} of your sales in the last 30 days ({share_pct}%).";
    if notice.applies_to == "IMPORTED" {
        text += " The rule is about imported goods, so check whether this stock is imported.";
    }
    if notice.status in ["PROPOSED", "UNKNOWN"] {
        text += " It is not law yet.";
    }
    return text;
}

"""Create or update the alert for a notice (one per notice) and link its products. Returns (alert, is_new)."""
def upsert_alert(biz: Business, notice: RegNotice, today: str, now: str) -> tuple[ComplianceAlert, bool] {
    matched = matching_products(biz, notice);
    sales = sales_by_sku(biz, today);
    total = sum([s.revenue_kes for s in sales.values()]);
    hit = sum([sales.get(p.sku, SkuSales()).revenue_kes for p in matched]);
    share = int(hit * 100 / total) if total > 0 else 0;
    sev = severity_for(notice, len(matched), share);
    existing = find_alert(biz, "ALERT-" + notice.notice_id);
    if existing is not None {
        existing.severity = sev;
        existing.sales_30d_kes = hit;
        existing.share_of_sales_pct = share;
        existing.effect_text = effect_text(notice, matched, hit, share);
        return (existing, False);
    }
    alert = ComplianceAlert(
        alert_id="ALERT-" + notice.notice_id, notice_id=notice.notice_id, severity=sev,
        effect_text=effect_text(notice, matched, hit, share), confidence=notice.confidence,
        affected_skus=[p.sku for p in matched], sales_30d_kes=hit, share_of_sales_pct=share,
        status="NEW" if sev != "INFO" else "NO_IMPACT", created_at=now
    );
    biz +>:HasAlert():+> alert;
    for p in matched { alert +>:AlertFor():+> p; }
    return (alert, True);
}
