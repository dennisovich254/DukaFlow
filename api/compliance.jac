"""Compliance radar endpoints (wholesaler only, scoped to the caller's own business)."""

import json;
import from domain.models { Business, ComplianceAlert, AlertAction }
import from domain.errors { DomainError }
import from domain.clock { now_iso }
import from domain.customers { find_customer }
import from domain.compliance {
    list_alerts, find_alert, find_notice, alert_actions, alert_products, list_notices, get_alert
}
import from ai.agent { current_mode, model_available }
import from ai.radar { refresh_radar, analyse_pasted }
import from ai.actions { apply_prices, send_messages, pause_products, set_action_status, payload_of }
import from api.business { current_business }
import from api.results { to_api_error }
import from api.contracts {
    ActionView, AlertView, AffectedProductView, DraftMessageView, RadarView, RadarRefreshResult,
    AnalyseInput, AnalyseResult, RadarActionInput, RadarActionResult, AlertLookup
}

glob SEVERITY_RANK: dict[str, int] = {"HIGH": 0, "MEDIUM": 1, "LOW": 2, "INFO": 3};

def action_view(biz: Business, a: AlertAction) -> ActionView {
    drafts: list[DraftMessageView] = [];
    if a.kind == "NOTIFY_CUSTOMERS" {
        p = payload_of(a);
        for (cid, text) in p.get("messages", {}).items() {
            c = find_customer(biz, cid);
            drafts.append(DraftMessageView(customer_id=cid, customer_name=c.name if c is not None else cid, text=text));
        }
    }
    return ActionView(
        action_id=a.action_id, kind=a.kind, title=a.title, detail=a.detail, impact_kes=a.impact_kes,
        due_on=a.due_on, status=a.status, messages=drafts
    );
}

def alert_view(biz: Business, alert: ComplianceAlert) -> AlertView | None {
    n = find_notice(biz, alert.notice_id);
    if n is None { return None; }
    return AlertView(
        alert_id=alert.alert_id, title=n.title, source_name=n.source_name, url=n.url, published_on=n.published_on,
        notice_status=n.status, effective_on=n.effective_on, kind=n.kind, evidence=n.evidence,
        rate_before=n.rate_before, rate_after=n.rate_after, applies_to=n.applies_to, origin=n.origin,
        caveat=n.caveat, severity=alert.severity, effect_text=alert.effect_text, confidence=alert.confidence,
        alert_status=alert.status, sales_30d_kes=alert.sales_30d_kes, share_of_sales_pct=alert.share_of_sales_pct,
        products=[AffectedProductView(sku=p.sku, name=p.name, price_kes=p.price_kes, unit=p.unit) for p in alert_products(alert)],
        actions=[action_view(biz, a) for a in alert_actions(alert)]
    );
}

def live_model() -> bool {
    return current_mode() == "live" and model_available();
}

def:protect radar_overview() -> RadarView {
    biz = current_business();
    views: list[AlertView] = [];
    for a in list_alerts(biz) {
        v = alert_view(biz, a);
        if v is not None { views.append(v); }
    }
    views = sorted(views, key=lambda (v: AlertView) { (SEVERITY_RANK.get(v.severity, 9), -v.sales_30d_kes); });
    return RadarView(alerts=views, notice_count=len(list_notices(biz)), mode=current_mode(), today=now_iso()[:10]);
}

"""Read the sources and update the alerts; never duplicates. With the live model on, it also reads the
latest KRA public notices from kra.go.ke."""
def:protect radar_check_now() -> RadarRefreshResult {
    try {
        live = live_model();
        r = refresh_radar(current_business(), now_iso()[:10], live, fetch_live=live);
        return RadarRefreshResult(
            ok=True, new_notices=r.new_notices, new_alerts=r.new_alerts, skipped=len(r.skipped),
            live_read=r.live_read, mode=r.mode
        );
    } except DomainError as e {
        return RadarRefreshResult(ok=False, error=to_api_error(e));
    }
}

def:protect radar_analyse(data: AnalyseInput) -> AnalyseResult {
    try {
        biz = current_business();
        n = analyse_pasted(biz, data.text, data.title, now_iso()[:10], live_model());
        return AnalyseResult(ok=True, alert_id="ALERT-" + n.notice_id);
    } except DomainError as e {
        return AnalyseResult(ok=False, error=to_api_error(e));
    }
}

"""Run one action the wholesaler clicked. Prices, messages and pausing happen only here."""
def:protect radar_act(data: RadarActionInput) -> RadarActionResult {
    try {
        biz = current_business();
        if data.kind == "apply" {
            n = apply_prices(biz, data.action_id);
            return RadarActionResult(ok=True, message=f"Updated {n} prices.");
        } elif data.kind == "send" {
            edits = {m.customer_id: m.text for m in data.messages};
            n = send_messages(biz, data.action_id, edits);
            return RadarActionResult(ok=True, message=f"Sent {n} messages.");
        } elif data.kind == "pause" {
            n = pause_products(biz, data.action_id);
            return RadarActionResult(ok=True, message=f"Paused {n} products.");
        } elif data.kind in ["done", "skip"] {
            set_action_status(biz, data.action_id, "DONE" if data.kind == "done" else "SKIPPED");
            return RadarActionResult(ok=True, message="Saved.");
        }
        raise DomainError("BAD_ACTION", "Unknown action.");
    } except DomainError as e {
        return RadarActionResult(ok=False, error=to_api_error(e));
    }
}

def:protect radar_dismiss(data: AlertLookup) -> RadarActionResult {
    try {
        alert = get_alert(current_business(), data.alert_id);
        alert.status = "DISMISSED";
        return RadarActionResult(ok=True, message="Dismissed.");
    } except DomainError as e {
        return RadarActionResult(ok=False, error=to_api_error(e));
    }
}
