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

"""Agent activity: every run of the chat agent, with the tools it called and how it ended."""
def:pub AgentActivityPage() -> JsxPage {
    has runs: list[ExecutionView] = [];
    has loading: bool = True;

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

    <DashboardShell>
        <PageHeader title="Agent activity" description="Every message the chat agent handled: the tools it called and how each run ended. Updates every few seconds." />
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-5">
            <Card><CardHeader><CardDescription>Runs</CardDescription><CardTitle className="display text-2xl font-medium tabular-nums">{len(runs)}</CardTitle></CardHeader></Card>
            <Card><CardHeader><CardDescription>Used tools</CardDescription><CardTitle className="display text-2xl font-medium tabular-nums">{with_tools}</CardTitle></CardHeader></Card>
            <Card><CardHeader><CardDescription>Quotes made</CardDescription><CardTitle className="display text-2xl font-medium tabular-nums">{quotes}</CardTitle></CardHeader></Card>
            <Card><CardHeader><CardDescription>Orders placed</CardDescription><CardTitle className="display text-2xl font-medium tabular-nums">{orders}</CardTitle></CardHeader></Card>
            <Card><CardHeader><CardDescription>Average time</CardDescription><CardTitle className="display text-2xl font-medium tabular-nums">{avg_ms} ms</CardTitle></CardHeader></Card>
        </div>
        <Card>
            <CardHeader>
                <CardTitle>Recent runs</CardTitle>
                <CardDescription>Newest first, up to 50.</CardDescription>
            </CardHeader>
            <CardContent>
                {if not loading and len(runs) == 0 {
                    <p className="text-sm text-muted-foreground">No chat messages yet. Create a chat link on the Customers page and send a message.</p>
                } else {
                    <ul className="divide-y">
                        {for (i, a) in enumerate(runs) {
                            <li key={str(i) + a.created_at} className="flex flex-col gap-1 pt-3 pb-3 text-sm">
                                <div className="flex flex-wrap items-center justify-between gap-2">
                                    <span className="font-medium">{a.customer_name} · {"photo" if a.input_type == "image" else "text"}</span>
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
                }}
            </CardContent>
        </Card>
    </DashboardShell>
}
