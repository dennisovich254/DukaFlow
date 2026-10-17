import from "sonner" { toast }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { Legal01Icon, CheckmarkCircle02Icon, LinkSquare02Icon }
import from ....api.compliance { radar_overview, radar_check_now, radar_analyse, radar_act, radar_dismiss }
import from ....api.contracts {
    RadarView, AlertView, ActionView, DraftMessageView, AnalyseInput, RadarActionInput, AlertLookup
}
import from ....lib.money { format_kes }
import from ....components.dashboard.Shell { DashboardShell, PageHeader }
import from ....components.ui.button { Button }
import from ....components.ui.input { Input }
import from ....components.ui.card { Card, CardHeader, CardTitle, CardDescription, CardContent }
import from ....components.ui.dialog {
    Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter
}

glob MONTHS: list[str] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

glob SEVERITY_CLASSES: dict[str, str] = {
    "HIGH": "bg-orange-100 text-orange-900",
    "MEDIUM": "bg-amber-100 text-amber-900",
    "LOW": "bg-[#d9f99d] text-[#1a2e05]",
    "INFO": "bg-[#f3f5ee] text-[#585c52]"
};
glob SEVERITY_LABELS: dict[str, str] = {"HIGH": "High", "MEDIUM": "Medium", "LOW": "Watch", "INFO": "No impact"};
glob KIND_LABELS: dict[str, str] = {
    "TAX_RATE": "Tax rate", "LEVY": "Levy", "STANDARD": "Standard", "PACKAGING": "Packaging", "LICENCE": "Licence", "OTHER": "Compliance"
};
glob TABS: list[list[str]] = [
    ["NEW", "To do"], ["HANDLED", "Handled"], ["NO_IMPACT", "No impact"], ["DISMISSED", "Dismissed"]
];

def nice_date(iso: str) -> str {
    if len(iso) < 10 or iso == "UNKNOWN" { return ""; }
    return str(int(iso[8:10])) + " " + MONTHS[int(iso[5:7]) - 1] + " " + iso[:4];
}

"""'Law, in force since 1 Jul 2026' / 'Law, starts 1 Dec 2026' / 'Proposal, not law yet'."""
def status_text(a: AlertView, today: str) -> str {
    when = nice_date(a.effective_on);
    if a.notice_status == "IN_FORCE" { return "In force" + (" since " + when if when else ""); }
    if a.notice_status == "ENACTED" { return "Passed, starts " + when if when else "Passed, start date not stated"; }
    if a.notice_status == "PROPOSED" { return "Proposal, not law yet"; }
    return "Status not stated";
}

def rate_text(a: AlertView) -> str {
    if a.rate_after == "UNKNOWN" { return ""; }
    if a.rate_before == "UNKNOWN" { return "New rate: " + a.rate_after; }
    return a.rate_before + " to " + a.rate_after;
}

"""Compliance radar: notices that affect what you sell, what they cost you, and what to do."""
def:pub CompliancePage() -> JsxPage {
    has view: RadarView | None = None;
    has tab: str = "NEW";
    has busy: bool = False;
    has analyseOpen: bool = False;
    has noticeText: str = "";
    has noticeTitle: str = "";
    has confirmAlert: AlertView | None = None;
    has confirmAction: ActionView | None = None;
    has drafts: list[DraftMessageView] = [];
    has picked: list[str] = [];

    async def load {
        view = await radar_overview();
    }

    async def check_now(e: MouseEvent) {
        busy = True;
        res = await radar_check_now();
        busy = False;
        if res.ok {
            toast.success(f"Checked: {res.new_notices} new notices, {res.new_alerts} new alerts");
        } elif res.error is not None {
            toast.error(res.error.message);
        }
        await load();
    }

    async can with entry {
        await load();
        if view is not None and view.notice_count == 0 {
            await radar_check_now();
            await load();
        }
    }

    async def analyse(e: FormEvent) {
        e.preventDefault();
        busy = True;
        res = await radar_analyse(AnalyseInput(text=noticeText, title=noticeTitle));
        busy = False;
        if res.ok {
            toast.success("Notice analysed");
            analyseOpen = False;
            noticeText = "";
            noticeTitle = "";
            tab = "NEW";
            await load();
        } elif res.error is not None {
            toast.error(res.error.message);
        }
    }

    async def dismiss(alertId: str) {
        res = await radar_dismiss(AlertLookup(alert_id=alertId));
        if res.ok { toast.success("Dismissed"); } elif res.error is not None { toast.error(res.error.message); }
        await load();
    }

    async def mark(actionId: str, kind: str) {
        res = await radar_act(RadarActionInput(action_id=actionId, kind=kind));
        if res.ok { toast.success(res.message); } elif res.error is not None { toast.error(res.error.message); }
        await load();
    }

    def open_confirm(a: AlertView, x: ActionView) {
        confirmAlert = a;
        confirmAction = x;
        drafts = x.messages;
        picked = [d.customer_id for d in x.messages];
    }

    def close_confirm() {
        confirmAlert = None;
        confirmAction = None;
    }

    def edit_draft(cid: str, text: str) {
        drafts = [DraftMessageView(customer_id=d.customer_id, customer_name=d.customer_name, text=text) if d.customer_id == cid else d for d in drafts];
    }

    def toggle_pick(cid: str) {
        picked = [p for p in picked if p != cid] if cid in picked else picked + [cid];
    }

    async def run_confirmed(e: MouseEvent) {
        if confirmAction is None { return; }
        x = confirmAction;
        kind = "apply" if x.kind == "REPRICE" else ("send" if x.kind == "NOTIFY_CUSTOMERS" else "pause");
        chosen = [d for d in drafts if d.customer_id in picked] if kind == "send" else [];
        busy = True;
        res = await radar_act(RadarActionInput(action_id=x.action_id, kind=kind, messages=chosen));
        busy = False;
        if res.ok {
            toast.success(res.message);
            close_confirm();
        } elif res.error is not None {
            toast.error(res.error.message);
        }
        await load();
    }

    alerts = [a for a in view.alerts if a.alert_status == tab] if view is not None else [];
    def count_of(status: str) -> int {
        return len([a for a in view.alerts if a.alert_status == status]) if view is not None else 0;
    }

    <DashboardShell>
        <PageHeader title="Compliance radar" description="Tax, levy and standards changes, matched to what you sell, with what to do about them.">
            <Button variant="outline" onClick={lambda (e: any) { analyseOpen = True; }}>Analyse a notice</Button>
            <Button onClick={check_now} disabled={busy}>{"Checking…" if busy else "Check now"}</Button>
        </PageHeader>

        <div className="flex flex-wrap gap-2" role="tablist" aria-label="Alert status">
            {for t in TABS {
                <button key={t[0]} type="button" role="tab" aria-selected={tab == t[0]} onClick={lambda (e: any) { tab = t[0]; }}
                    className={"cursor-pointer rounded-full border pt-1.5 pb-1.5 pl-3.5 pr-3.5 text-sm outline-none focus-visible:ring-2 focus-visible:ring-[#0e0f0c] " + ("border-[#0e0f0c] bg-[#0e0f0c] text-white" if tab == t[0] else "border-[#e4e7dc] bg-white hover:bg-[#f3f5ee]")}>
                    {t[1]} <span className={"tabular-nums " + ("text-[#d9f99d]" if tab == t[0] else "text-muted-foreground")}>{count_of(t[0])}</span>
                </button>
            }}
        </div>

        {if view is None {
            <p className="text-sm text-muted-foreground">Reading the latest notices…</p>
        } elif len(alerts) == 0 {
            <Card className="wash-lime border-0">
                <CardContent className="flex items-center gap-3 pt-5 pb-5">
                    <HugeiconsIcon icon={CheckmarkCircle02Icon} strokeWidth={2} className="size-6" />
                    <div>
                        <p className="font-medium">{"Nothing to do" if tab == "NEW" else "Nothing here"}</p>
                        <p className="text-sm text-muted-foreground">No changes need your attention in this list.</p>
                    </div>
                </CardContent>
            </Card>
        } else {
            <div className="flex flex-col gap-4">
                {for a in alerts {
                    <Card key={a.alert_id}>
                        <CardHeader>
                            <div className="flex flex-wrap items-center gap-2">
                                <span className={"rounded-full pt-0.5 pb-0.5 pl-2.5 pr-2.5 text-xs font-medium " + SEVERITY_CLASSES.get(a.severity, "")}>{SEVERITY_LABELS.get(a.severity, a.severity)}</span>
                                <span className="rounded-full bg-[#f3f5ee] pt-0.5 pb-0.5 pl-2.5 pr-2.5 text-xs">{KIND_LABELS.get(a.kind, a.kind)}</span>
                                <span className="text-xs text-muted-foreground">{status_text(a, view.today)}</span>
                                {a.origin == "SAMPLE" and <span className="rounded-full bg-amber-100 pt-0.5 pb-0.5 pl-2.5 pr-2.5 text-xs font-medium text-amber-900">Sample, not a real notice</span>}
                                {a.applies_to == "IMPORTED" and <span className="rounded-full bg-[#f3f5ee] pt-0.5 pb-0.5 pl-2.5 pr-2.5 text-xs">Imports only</span>}
                            </div>
                            <CardTitle className="text-lg font-medium leading-snug">{a.title}</CardTitle>
                            {rate_text(a) != "" and <CardDescription>{rate_text(a)}</CardDescription>}
                        </CardHeader>
                        <CardContent className="flex flex-col gap-4">
                            {if len(a.products) > 0 {
                                <div>
                                    <p className="text-sm font-medium">Affects {len(a.products)} of your products · {format_kes(a.sales_30d_kes)} of sales in the last 30 days ({a.share_of_sales_pct}%)</p>
                                    <div className="mt-2 flex flex-wrap gap-1.5">
                                        {for p in a.products[:8] {
                                            <span key={p.sku} className="rounded-full border border-[#e4e7dc] pt-0.5 pb-0.5 pl-2.5 pr-2.5 text-xs">{p.name}</span>
                                        }}
                                        {len(a.products) > 8 and <span className="text-xs text-muted-foreground">+ {len(a.products) - 8} more</span>}
                                    </div>
                                </div>
                            }}
                            <p className="text-sm">{a.effect_text}</p>

                            {if len(a.actions) > 0 {
                                <div className="rounded-xl bg-[#fbfcf8] border border-[#e4e7dc] pt-3 pb-3 pl-4 pr-4">
                                    <p className="text-sm font-semibold">What to do</p>
                                    <ul className="mt-2 flex flex-col divide-y">
                                        {for x in a.actions {
                                            <li key={x.action_id} className="flex flex-wrap items-start justify-between gap-3 pt-3 pb-3">
                                                <div className="min-w-0 flex-1 basis-72">
                                                    <p className="text-sm font-medium">{x.title}{x.impact_kes > 0 and <span className="ml-2 text-xs font-normal text-[#4d7c0f]">about {format_kes(x.impact_kes)}</span>}</p>
                                                    <p className="mt-0.5 text-xs text-muted-foreground">{x.detail}</p>
                                                    {x.due_on != "" and <p className="mt-0.5 text-xs text-muted-foreground">By {nice_date(x.due_on)}</p>}
                                                </div>
                                                <div className="flex items-center gap-2">
                                                    {if x.status == "DONE" {
                                                        <span className="text-xs font-medium text-[#4d7c0f]">Done</span>
                                                    } elif x.status == "SKIPPED" {
                                                        <span className="text-xs text-muted-foreground">Skipped</span>
                                                    } elif x.kind in ["REPRICE", "NOTIFY_CUSTOMERS", "PAUSE_PRODUCT"] {
                                                        <Button size="sm" onClick={lambda (e: any) { open_confirm(a, x); }}>{"Apply prices" if x.kind == "REPRICE" else ("Review and send" if x.kind == "NOTIFY_CUSTOMERS" else "Pause products")}</Button>
                                                        <Button size="sm" variant="ghost" onClick={lambda (e: any) { mark(x.action_id, "skip"); }}>Skip</Button>
                                                    } else {
                                                        <Button size="sm" variant="outline" onClick={lambda (e: any) { mark(x.action_id, "done"); }}>Mark done</Button>
                                                        <Button size="sm" variant="ghost" onClick={lambda (e: any) { mark(x.action_id, "skip"); }}>Skip</Button>
                                                    }}
                                                </div>
                                            </li>
                                        }}
                                    </ul>
                                </div>
                            }}

                            <details className="text-sm">
                                <summary className="cursor-pointer text-muted-foreground">From the source · {a.confidence.lower()} confidence</summary>
                                <p className="mt-2 text-muted-foreground">{a.evidence}</p>
                                {a.caveat != "" and <p className="mt-1 text-xs text-amber-900">{a.caveat}</p>}
                            </details>
                            <div className="flex flex-wrap items-center justify-between gap-2 text-xs text-muted-foreground">
                                <span>
                                    {a.source_name}{a.published_on != "UNKNOWN" and a.published_on != "" and " · " + nice_date(a.published_on)}
                                    {a.url != "" and <a href={a.url} target="_blank" rel="noopener noreferrer" className="ml-2 inline-flex items-center gap-1 underline underline-offset-4">Source <HugeiconsIcon icon={LinkSquare02Icon} strokeWidth={2} className="size-3" /></a>}
                                </span>
                                {a.alert_status != "DISMISSED" and <button type="button" onClick={lambda (e: any) { dismiss(a.alert_id); }} className="cursor-pointer underline underline-offset-4">Not relevant to me</button>}
                            </div>
                            <p className="text-[11px] text-muted-foreground">Not legal advice. Confirm with your accountant or KRA before acting.</p>
                        </CardContent>
                    </Card>
                }}
            </div>
        }}

        <Dialog open={confirmAction is not None} onOpenChange={lambda (v: bool) { if not v { close_confirm(); } }}>
            <DialogContent className="max-h-[90vh] overflow-y-auto sm:max-w-xl">
                <DialogHeader>
                    <DialogTitle>{confirmAction.title if confirmAction is not None else ""}</DialogTitle>
                    <DialogDescription>{"Nothing is sent until you press Send. Edit any message first." if confirmAction is not None and confirmAction.kind == "NOTIFY_CUSTOMERS" else "This is exactly what will change."}</DialogDescription>
                </DialogHeader>
                {if confirmAction is not None and confirmAction.kind == "NOTIFY_CUSTOMERS" {
                    <div className="flex flex-col gap-4">
                        {for d in drafts {
                            <div key={d.customer_id}>
                                <label className="flex items-center gap-2 text-sm font-medium">
                                    <input type="checkbox" checked={d.customer_id in picked} onChange={lambda (e: any) { toggle_pick(d.customer_id); }} />
                                    {d.customer_name}
                                </label>
                                <textarea aria-label={"Message to " + d.customer_name} value={d.text} rows={3} maxLength={600}
                                    onChange={lambda (e: ChangeEvent) { edit_draft(d.customer_id, e.target.value); }}
                                    className="mt-1 w-full rounded-lg border border-[#e4e7dc] pt-2 pb-2 pl-3 pr-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-[#0e0f0c]" />
                            </div>
                        }}
                    </div>
                } else {
                    <p className="text-sm">{confirmAction.detail if confirmAction is not None else ""}</p>
                }}
                <DialogFooter>
                    <Button type="button" variant="outline" onClick={lambda (e: any) { close_confirm(); }}>Cancel</Button>
                    <Button type="button" onClick={run_confirmed} disabled={busy}>
                        {"Working…" if busy else ("Send" if confirmAction is not None and confirmAction.kind == "NOTIFY_CUSTOMERS" else "Confirm")}
                    </Button>
                </DialogFooter>
            </DialogContent>
        </Dialog>

        <Dialog open={analyseOpen} onOpenChange={lambda (v: bool) { analyseOpen = v; }}>
            <DialogContent className="sm:max-w-xl">
                <DialogHeader>
                    <DialogTitle>Analyse a notice</DialogTitle>
                    <DialogDescription>Paste the text of a notice, bill or circular. The radar checks it, matches it to your products and plans next steps.</DialogDescription>
                </DialogHeader>
                <form onSubmit={analyse} className="flex flex-col gap-3">
                    <Input aria-label="Title (optional)" placeholder="Title (optional)" value={noticeTitle} onChange={lambda (e: ChangeEvent) { noticeTitle = e.target.value; }} />
                    <textarea aria-label="Notice text" rows={8} maxLength={20000} value={noticeText} placeholder="Paste the notice text here"
                        onChange={lambda (e: ChangeEvent) { noticeText = e.target.value; }}
                        className="w-full rounded-lg border border-[#e4e7dc] pt-2 pb-2 pl-3 pr-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-[#0e0f0c]" />
                    <DialogFooter>
                        <Button type="button" variant="outline" onClick={lambda (e: any) { analyseOpen = False; }}>Cancel</Button>
                        <Button type="submit" disabled={busy}>{"Analysing…" if busy else "Analyse"}</Button>
                    </DialogFooter>
                </form>
            </DialogContent>
        </Dialog>
    </DashboardShell>
}
