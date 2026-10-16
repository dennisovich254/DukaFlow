import from "sonner" { toast }
import from "@jac/runtime" { Link }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    Money03Icon, ShoppingBag01Icon, Alert02Icon, ArrowUpRight01Icon, ArrowDownRight01Icon,
    CheckmarkCircle02Icon, Add01Icon
}
import from ....api.dashboard { dashboard_analytics, load_demo_data }
import from ....api.contracts { AnalyticsView }
import from ....lib.money { format_kes }
import from ....components.dashboard.Shell { DashboardShell, PageHeader }
import from ....components.dashboard.StatusBadge { StatusBadge, STATUS_LABELS }
import from ....components.dashboard.charts { BarChart, HBarList, Donut }
import from ....components.ui.button { Button }
import from ....components.ui.card { Card, CardHeader, CardTitle, CardDescription, CardContent }

glob CHANNEL_LABELS: dict[str, str] = {"chat": "Customer chat", "manual": "Entered by you"};

"""'2026-10-16T14:02:11+03:00' -> '16 Oct, 14:02'."""
def short_when(iso: str) -> str {
    months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    if len(iso) < 16 { return iso; }
    return str(int(iso[8:10])) + " " + months[int(iso[5:7]) - 1] + ", " + iso[11:16];
}

def initials(name: str) -> str {
    parts = [p for p in name.split(" ") if len(p) > 0];
    if len(parts) == 0 { return "?"; }
    return (parts[0][0] + (parts[1][0] if len(parts) > 1 else "")).upper();
}

"""Percentage change as text, or '' when there is nothing to compare with."""
def change_text(now: int, before: int) -> str {
    if before <= 0 { return ""; }
    pct = int(abs(now - before) * 100 / before);
    return ("+" if now >= before else "-") + str(pct) + "% vs previous 7 days";
}

"""Overview: what needs you now, how the week is going, and the latest orders."""
def:pub OverviewPage() -> JsxPage {
    has data: AnalyticsView | None = None;
    has loading: bool = True;

    async def load_all {
        data = await dashboard_analytics();
        loading = False;
    }

    async def seed(e: MouseEvent) {
        added = await load_demo_data();
        toast.success(f"Loaded {added} demo products");
        await load_all();
    }

    async can with entry {
        await load_all();
    }

    a = data;
    up = a is not None and a.revenue_7d >= a.revenue_prev_7d;
    delta = change_text(a.revenue_7d, a.revenue_prev_7d) if a is not None else "";

    <DashboardShell>
        <PageHeader title="Overview" description={("Today, " + short_when(a.today + "T00:00")[:-7]) if a is not None else "What is happening in your business."}>
            {if a is not None and a.ai_mode == "mock" {
                <span className="rounded-full bg-amber-100 pt-1 pb-1 pl-3 pr-3 text-xs font-medium text-amber-900">Mock AI: rule-based demo mode</span>
            }}
            {if a is not None and a.product_count == 0 {
                <Button onClick={seed}>Load demo data</Button>
            }}
            <Link to="/dashboard/orders">
                <Button><HugeiconsIcon icon={Add01Icon} strokeWidth={2} className="size-4" /> New order</Button>
            </Link>
        </PageHeader>

        {if a is None {
            <p className="text-sm text-muted-foreground">Loading your numbers…</p>
        } else {
            <div className="flex flex-col gap-6">
                {if a.pending_count > 0 {
                    <Card className="ink-card border-0">
                        <CardContent className="flex flex-col gap-4 pt-6 pb-6 lg:flex-row lg:items-center lg:justify-between">
                            <div>
                                <p className="text-xs uppercase tracking-wide text-[#c9cdbf]">Needs your approval</p>
                                <p className="display mt-1 text-4xl font-medium">{a.pending_count} {"order" if a.pending_count == 1 else "orders"} waiting</p>
                                <p className="mt-1 text-sm text-[#c9cdbf]">Customers have confirmed their quotes. Nothing ships until you approve.</p>
                            </div>
                            <ul className="flex flex-col gap-2 text-sm lg:min-w-[22rem]">
                                {for p in a.pending {
                                    <li key={p.order_id} className="flex items-center justify-between gap-4 rounded-xl bg-white/10 pt-2 pb-2 pl-3 pr-3">
                                        <span className="truncate">{p.customer_name}</span>
                                        <span className="shrink-0 tabular-nums">{format_kes(p.total_kes)}</span>
                                    </li>
                                }}
                            </ul>
                            <Link to="/dashboard/orders"><Button className="bg-[#a3e635] text-[#0e0f0c] hover:bg-[#d9f99d]">Review orders</Button></Link>
                        </CardContent>
                    </Card>
                } else {
                    <Card className="wash-lime border-0">
                        <CardContent className="flex items-center gap-3 pt-5 pb-5">
                            <HugeiconsIcon icon={CheckmarkCircle02Icon} strokeWidth={2} className="size-6" />
                            <div>
                                <p className="font-medium">All caught up</p>
                                <p className="text-sm text-muted-foreground">No orders are waiting for your approval.</p>
                            </div>
                        </CardContent>
                    </Card>
                }}

                <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
                    <Card>
                        <CardHeader>
                            <CardDescription className="flex items-center gap-2"><HugeiconsIcon icon={Money03Icon} strokeWidth={2} className="size-4" /> Sales, last 7 days</CardDescription>
                            <CardTitle className="display text-2xl font-medium tabular-nums">{format_kes(a.revenue_7d)}</CardTitle>
                            {delta != "" and <p className={"flex items-center gap-1 text-xs " + ("text-[#4d7c0f]" if up else "text-orange-700")}>
                                <HugeiconsIcon icon={ArrowUpRight01Icon if up else ArrowDownRight01Icon} strokeWidth={2} className="size-3.5" /> {delta}
                            </p>}
                        </CardHeader>
                    </Card>
                    <Card>
                        <CardHeader>
                            <CardDescription className="flex items-center gap-2"><HugeiconsIcon icon={ShoppingBag01Icon} strokeWidth={2} className="size-4" /> Orders, last 7 days</CardDescription>
                            <CardTitle className="display text-2xl font-medium tabular-nums">{a.orders_7d}</CardTitle>
                            <p className="text-xs text-muted-foreground">Average {format_kes(a.avg_order_kes)} per order</p>
                        </CardHeader>
                    </Card>
                    <Card>
                        <CardHeader>
                            <CardDescription>Customers</CardDescription>
                            <CardTitle className="display text-2xl font-medium tabular-nums">{a.customer_count}</CardTitle>
                            <p className="text-xs text-muted-foreground">{a.product_count} products in the catalogue</p>
                        </CardHeader>
                    </Card>
                    <Card>
                        <CardHeader>
                            <CardDescription className="flex items-center gap-2"><HugeiconsIcon icon={Alert02Icon} strokeWidth={2} className="size-4" /> Low or out of stock</CardDescription>
                            <CardTitle className="display text-2xl font-medium tabular-nums">{len(a.low_stock)}</CardTitle>
                            <p className="text-xs text-muted-foreground">5 units or fewer available</p>
                        </CardHeader>
                    </Card>
                </div>

                <div className="grid gap-4 lg:grid-cols-3">
                    <Card className="lg:col-span-2">
                        <CardHeader>
                            <CardTitle>Sales this week</CardTitle>
                            <CardDescription>Approved, packed, dispatched and delivered orders per day.</CardDescription>
                        </CardHeader>
                        <CardContent>
                            <BarChart labels={[d.label for d in a.days]} values={[d.revenue_kes for d in a.days]} />
                        </CardContent>
                    </Card>
                    <Card>
                        <CardHeader>
                            <CardTitle>Orders by status</CardTitle>
                            <CardDescription>All orders, all time.</CardDescription>
                        </CardHeader>
                        <CardContent>
                            <Donut names={[STATUS_LABELS.get(s.status, s.status) for s in a.status_counts]}
                                values={[s.count for s in a.status_counts]} centre="orders" />
                        </CardContent>
                    </Card>
                </div>

                <div className="grid gap-4 lg:grid-cols-3">
                    <Card>
                        <CardHeader>
                            <CardTitle>Top products</CardTitle>
                            <CardDescription>By sales, last 30 days.</CardDescription>
                        </CardHeader>
                        <CardContent>
                            {if len(a.top_products) == 0 {
                                <p className="text-sm text-muted-foreground">Sales will show here once orders are approved.</p>
                            } else {
                                <HBarList names={[t.name for t in a.top_products]} values={[t.revenue_kes for t in a.top_products]}
                                    captions={[format_kes(t.revenue_kes) + " · " + str(t.quantity) + " sold" for t in a.top_products]} />
                            }}
                        </CardContent>
                    </Card>
                    <Card>
                        <CardHeader>
                            <CardTitle>Where orders come from</CardTitle>
                            <CardDescription>Last 30 days.</CardDescription>
                        </CardHeader>
                        <CardContent>
                            <Donut names={[CHANNEL_LABELS.get(c.channel, c.channel) for c in a.channels]}
                                values={[c.count for c in a.channels]} centre="orders" />
                        </CardContent>
                    </Card>
                    <Card>
                        <CardHeader>
                            <CardTitle>Running low</CardTitle>
                            <CardDescription><Link to="/dashboard/products" className="underline underline-offset-4">Restock in Products & stock</Link></CardDescription>
                        </CardHeader>
                        <CardContent>
                            {if len(a.low_stock) == 0 {
                                <p className="text-sm text-muted-foreground">Every product has healthy stock.</p>
                            } else {
                                <ul className="flex flex-col gap-3">
                                    {for i in a.low_stock {
                                        <li key={i.sku} className="flex items-center justify-between gap-3 text-sm">
                                            <span className="truncate">{i.name}</span>
                                            <span className={"shrink-0 rounded-full pt-0.5 pb-0.5 pl-2.5 pr-2.5 text-xs font-medium " + ("bg-orange-100 text-orange-900" if i.available == 0 else "bg-amber-100 text-amber-900")}>
                                                {"Out of stock" if i.available == 0 else str(i.available) + " left"}
                                            </span>
                                        </li>
                                    }}
                                </ul>
                            }}
                        </CardContent>
                    </Card>
                </div>

                <Card>
                    <CardHeader className="flex flex-row items-center justify-between">
                        <div>
                            <CardTitle>Recent orders</CardTitle>
                            <CardDescription>The latest five.</CardDescription>
                        </div>
                        <Link to="/dashboard/orders"><Button variant="outline">View all</Button></Link>
                    </CardHeader>
                    <CardContent>
                        {if len(a.recent_orders) == 0 {
                            <p className="text-sm text-muted-foreground">No orders yet.</p>
                        } else {
                            <ul className="divide-y">
                                {for o in a.recent_orders {
                                    <li key={o.order_id} className="flex flex-wrap items-center gap-4 pt-3 pb-3">
                                        <span className="flex size-10 shrink-0 items-center justify-center rounded-full bg-[#d9f99d] text-sm font-semibold text-[#1a2e05]" aria-hidden="true">{initials(o.customer_name)}</span>
                                        <div className="min-w-0 flex-1">
                                            <p className="truncate font-medium">{o.customer_name}</p>
                                            <p className="text-xs text-muted-foreground">{o.order_id} · {short_when(o.created_at)} · {CHANNEL_LABELS.get(o.channel, o.channel)} · {len(o.lines)} {"item" if len(o.lines) == 1 else "items"}</p>
                                        </div>
                                        <span className="tabular-nums font-medium">{format_kes(o.total_kes)}</span>
                                        <StatusBadge status={o.status} />
                                    </li>
                                }}
                            </ul>
                        }}
                    </CardContent>
                </Card>
            </div>
        }}
    </DashboardShell>
}
