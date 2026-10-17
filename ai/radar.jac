"""The compliance radar: read notices, check them, and let the scout walker match them to the business.

`refresh_radar` is the whole pipeline: read each new notice (model or rules) -> check its facts ->
store it -> `ComplianceScout` walks the business's notices and, for each, matches products,
computes the money at stake and plans actions. Re-running never duplicates anything."""

import from domain.models { Business, RegNotice, HasNotice }
import from domain.errors { DomainError }
import from domain.catalogue { list_products }
import from domain.clock { now_iso }
import from domain.compliance { list_notices, find_notice, upsert_alert, list_alerts }
import from integrations.regwatch { SourceDoc, load_snapshot, pasted_doc, fetch_kra_notices }
import from integrations.regsnapshot { SNAPSHOT }
import from ai.regulation { read_notice, pick_evidence, Checked }
import from ai.actions { plan_actions }

glob BASE_CATEGORIES: list[str] = ["Packaging", "Water"];

obj RefreshResult {
    has new_notices: int = 0,
        new_alerts: int = 0,
        live_read: int = 0,
        skipped: list[str] = [],
        mode: str = "snapshot";
}

def product_categories(biz: Business) -> list[str] {
    cats: list[str] = [];
    for p in list_products(biz) {
        if p.category not in cats { cats.append(p.category); }
    }
    return cats + [c for c in BASE_CATEGORIES if c not in cats];
}

"""Check one document and store it as a notice. Returns (notice or None, reason it was skipped)."""
def ingest(biz: Business, doc: SourceDoc, today: str, live: bool) -> tuple[RegNotice | None, str] {
    if doc.notice_id and find_notice(biz, doc.notice_id) is not None { return (None, ""); }
    nid = doc.notice_id or f"REG-P{len(list_notices(biz)) + 1}";
    checked = read_notice(doc, product_categories(biz), today, live);
    if not checked.ok { return (None, f"{doc.title}: {checked.reason}"); }
    ex = checked.extract;
    # A public notice from the tax authority is an announcement, not a bill: if the model could not
    # tell, it is in force once its date has passed (or no date is given), otherwise passed and pending.
    if doc.origin == "LIVE" and ex.status == "UNKNOWN" {
        ex.status = "ENACTED" if ex.effective_on != "UNKNOWN" and ex.effective_on > today else "IN_FORCE";
    }
    notice = RegNotice(
        notice_id=nid, title=doc.title, source_name=doc.source_name, url=doc.url,
        published_on=doc.published_on or "UNKNOWN", status=ex.status, effective_on=ex.effective_on, kind=ex.kind,
        summary=ex.summary or doc.title, evidence=pick_evidence(doc.text, ex),
        rate_before=ex.rate_before, rate_after=ex.rate_after, applies_to=ex.applies_to,
        categories=ex.categories, keywords=ex.keywords, confidence=checked.confidence, origin=doc.origin,
        caveat=("Not confirmed in the source and left out: " + "; ".join(checked.removed)) if len(checked.removed) > 0 else "",
        fetched_at=now_iso()
    );
    biz +>:HasNotice():+> notice;
    return (notice, "");
}

"""Walks the business's notices; for each, matches products, computes the money at stake, plans actions."""
walker ComplianceScout {
    has today: str;

    can start with Business entry {
        visit [->:HasNotice:->];
    }

    can scout with RegNotice entry {
        biz = [here <-:HasNotice:<-][0];
        (alert, is_new) = upsert_alert(biz, here, self.today, now_iso());
        if is_new { plan_actions(biz, alert, here, self.today); }
        report {"alert_id": alert.alert_id, "new": is_new};
    }
}

"""Read the sources, store new notices, then run the scout. With `fetch_live` the radar also reads the
latest KRA public notices from kra.go.ke; if that fails it carries on with the reviewed snapshot."""
def refresh_radar(biz: Business, today: str, live: bool = False, fetch_live: bool = False) -> RefreshResult {
    result = RefreshResult(mode="live" if fetch_live else "snapshot");
    docs = load_snapshot();
    if fetch_live {
        try {
            fresh = fetch_kra_notices(today, [n["url"] for n in SNAPSHOT]);
            result.live_read = len(fresh);
            docs = fresh + docs;
        } except Exception as e {
            result.mode = "snapshot";
            result.skipped.append(f"live sources unreachable ({type(e).__name__}); used the reviewed snapshot");
        }
    }
    for doc in docs {
        (notice, reason) = ingest(biz, doc, today, live);
        if notice is not None { result.new_notices += 1; }
        elif reason { result.skipped.append(reason); }
    }
    run = biz spawn ComplianceScout(today=today);
    result.new_alerts = len([r for r in run.reports if r["new"]]);
    return result;
}

"""Analyse a notice the wholesaler pasted in; returns the stored notice. Raises DomainError with the reason."""
def analyse_pasted(biz: Business, text: str, title: str, today: str, live: bool) -> RegNotice {
    doc = pasted_doc(text, title);
    (notice, reason) = ingest(biz, doc, today, live);
    if notice is None {
        raise DomainError("NOTICE_NOT_USABLE", reason or "That notice is not about goods or rules that affect your business.");
    }
    biz spawn ComplianceScout(today=today);
    return notice;
}
