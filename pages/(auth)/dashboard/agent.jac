import from ....api.review { recent_agent_activity }
import from ....api.contracts { ExecutionView }
import from ....components.dashboard.Shell { DashboardShell, PageHeader }
import from ....components.ui.card { Card, CardHeader, CardTitle, CardDescription, CardContent }

"""'2026-10-16T14:02:11+03:00' -> '16 Oct, 14:02:11'."""
def run_time(iso: str) -> str {
    months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    if len(iso) < 19 { return iso; }
    return str(int(iso[8:10])) + " " + months[int(iso[5:7]) - 1] + ", " + iso[11:19];
}

def initials(name: str) -> str {
    parts = [p for p in name.split(" ") if len(p) > 0];
    if len(parts) == 0 { return "?"; }
    return (parts[0][0] + (parts[1][0] if len(parts) > 1 else "")).upper();
}

"""Agent activity: every run of the chat agent, with the tools it called and how it ended."""
def:pub AgentActivityPage() -> JsxPage {
    has runs: list[ExecutionView] = [];
    has loading: bool = True;
    has opened: list[str] = [];

    def toggle(cid: str) {
        opened = [x for x in opened if x != cid] if cid in opened else opened + [cid];
    }

    async def refresh {
        runs = await recent_agent_activity();
        loading = False;
    }

    async can with entry {
        await refresh();
    }

    useEffect(lambda {
        timer = setInterval(lambda { refresh(); }, 5000);
        return lambda { clearInterval(timer); };
    }, []);

    total_ms = sum([r.duration_ms for r in runs]);
    avg_ms = int(total_ms / len(runs)) if len(runs) > 0 else 0;
    quotes = len([r for r in runs if r.outcome == "QUOTED"]);
    orders = len([r for r in runs if r.outcome == "ORDER_PLACED"]);
    with_tools = len([r for r in runs if len(r.steps) > 0]);

    # runs arrive newest first, so a customer's first run is their latest
    groups: list[dict[str, any]] = [];
    for r in runs {
        found = [g for g in groups if g["id"] == r.customer_id];
        if len(found) == 0 {
            groups.append({"id": r.customer_id, "name": r.customer_name, "runs": [r], "last": r.created_at, "quotes": 0, "orders": 0});
        } else {
            found[0]["runs"].append(r);
        }
    }
    for g in groups {
        g["quotes"] = len([r for r in g["runs"] if r.outcome == "QUOTED"]);
        g["orders"] = len([r for r in g["runs"] if r.outcome == "ORDER_PLACED"]);
    }

    <DashboardShell>
        <PageHeader title="Agent activity" description="The chat agent's runs, grouped by customer: the tools it called and how each run ended. Updates every few seconds." />
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-5">
            <Card><CardHeader><CardDescription>Runs</CardDescription><CardTitle className="display text-2xl font-medium tabular-nums">{len(runs)}</CardTitle></CardHeader></Card>
            <Card><CardHeader><CardDescription>Used tools</CardDescription><CardTitle className="display text-2xl font-medium tabular-nums">{with_tools}</CardTitle></CardHeader></Card>
            <Card><CardHeader><CardDescription>Quotes made</CardDescription><CardTitle className="display text-2xl font-medium tabular-nums">{quotes}</CardTitle></CardHeader></Card>
            <Card><CardHeader><CardDescription>Orders placed</CardDescription><CardTitle className="display text-2xl font-medium tabular-nums">{orders}</CardTitle></CardHeader></Card>
            <Card><CardHeader><CardDescription>Average time</CardDescription><CardTitle className="display text-2xl font-medium tabular-nums">{avg_ms} ms</CardTitle></CardHeader></Card>
        </div>
        {if not loading and len(runs) == 0 {
            <Card><CardContent className="pt-6 pb-6"><p className="text-sm text-muted-foreground">No chat messages yet. Create a chat link on the Customers page and send a message.</p></CardContent></Card>
        } else {
            <div className="flex flex-col gap-4">
                {for g in groups {
                    <Card key={g["id"]}>
                        <CardHeader>
                            <button type="button" onClick={lambda (e: any) { toggle(g["id"]); }}
                                aria-expanded={g["id"] in opened}
                                className="flex w-full cursor-pointer flex-wrap items-center gap-4 text-left outline-none focus-visible:ring-2 focus-visible:ring-[#0e0f0c] rounded-lg">
                                <span className="flex size-10 shrink-0 items-center justify-center rounded-full bg-[#d9f99d] text-sm font-semibold text-[#1a2e05]" aria-hidden="true">{initials(g["name"])}</span>
                                <span className="min-w-0 flex-1">
                                    <CardTitle>{g["name"]}</CardTitle>
                                    <CardDescription>{len(g["runs"])} {"run" if len(g["runs"]) == 1 else "runs"} · {g["quotes"]} quoted · {g["orders"]} {"order" if g["orders"] == 1 else "orders"} placed · last {run_time(g["last"])}</CardDescription>
                                </span>
                                <span className="text-xs text-muted-foreground">{"Hide" if g["id"] in opened else "Show runs"}</span>
                            </button>
                        </CardHeader>
                        {if g["id"] in opened {
                            <CardContent>
                                <ul className="divide-y">
                                    {for (i, a) in enumerate(g["runs"]) {
                                        <li key={str(i) + a.created_at} className="flex flex-col gap-1 pt-3 pb-3 text-sm">
                                            <div className="flex flex-wrap items-center justify-between gap-2">
                                                <span className="font-medium">{"Photo" if a.input_type == "image" else "Text"} message</span>
                                                <span className="rounded-full bg-[#e7f8c4] pt-0.5 pb-0.5 pl-2.5 pr-2.5 text-xs font-medium text-[#1a2e05]">{a.outcome}</span>
                                            </div>
                                            {if len(a.steps) > 0 {
                                                <p className="break-words font-mono text-[11px] text-muted-foreground">{" → ".join([st.split("(")[0] for st in a.steps])}</p>
                                            } else {
                                                <p className="text-xs text-muted-foreground">answered directly, no tools needed</p>
                                            }}
                                            <p className="text-[11px] text-muted-foreground">{run_time(a.created_at)} · {a.duration_ms} ms</p>
                                        </li>
                                    }}
                                </ul>
                            </CardContent>
                        }}
                    </Card>
                }}
            </div>
        }}
    </DashboardShell>
}
