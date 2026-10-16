import from "sonner" { toast }
import from "@jac/runtime" { Link }
import from ....api.dashboard { dashboard_summary, load_demo_data }
import from ....api.customers { list_customer_records }
import from ....api.products { list_catalogue }
import from ....api.contracts { OrderView, CustomerView, ProductView, CatalogueQuery }
import from ....lib.money { format_kes }
import from ....components.dashboard.Shell { DashboardShell, PageHeader }
import from ....components.dashboard.StatusBadge { StatusBadge }
import from ....components.ui.button { Button }
import from ....components.ui.card { Card, CardHeader, CardTitle, CardDescription, CardContent }
import from ....components.ui.table { Table, TableHeader, TableBody, TableRow, TableHead, TableCell }

"""Overview: headline numbers and the most recent orders."""
def:pub OverviewPage() -> JsxPage {
    has products: list[ProductView] = [];
    has orders: list[OrderView] = [];
    has customers: list[CustomerView] = [];
    has ordersToday: int = 0;
    has pendingApproval: int = 0;
    has lowStock: int = 0;
    has aiMode: str = "live";
    has loading: bool = True;

    async def load_all {
        products = await list_catalogue(CatalogueQuery(include_inactive=False));
        summary = await dashboard_summary();
        orders = summary.recent_orders;
        ordersToday = summary.orders_today;
        pendingApproval = summary.pending_approval;
        lowStock = summary.low_stock_count;
        aiMode = summary.ai_mode;
        customers = await list_customer_records();
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

    <DashboardShell>
        <PageHeader title="Overview" description="What is happening in your business today.">
            {if aiMode == "mock" {
                <span className="rounded-full bg-amber-100 pt-1 pb-1 pl-3 pr-3 text-xs font-medium text-amber-900">Mock AI: rule-based demo mode</span>
            }}
            {if not loading and len(products) == 0 {
                <Button onClick={seed}>Load demo data</Button>
            }}
        </PageHeader>
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            <Card><CardHeader><CardDescription>Orders today</CardDescription><CardTitle className="text-3xl font-semibold tabular-nums">{"–" if loading else ordersToday}</CardTitle></CardHeader></Card>
            <Card className="ink-card border-0"><CardHeader><CardDescription className="text-[#c9cdbf]">Pending approval</CardDescription><CardTitle className="text-3xl font-semibold tabular-nums">{"–" if loading else pendingApproval}</CardTitle></CardHeader></Card>
            <Card><CardHeader><CardDescription>Low or out of stock</CardDescription><CardTitle className="text-3xl font-semibold tabular-nums">{"–" if loading else lowStock}</CardTitle></CardHeader></Card>
            <Card><CardHeader><CardDescription>Customers</CardDescription><CardTitle className="text-3xl font-semibold tabular-nums">{"–" if loading else len(customers)}</CardTitle></CardHeader></Card>
        </div>
        <Card>
            <CardHeader>
                <CardTitle>Recent orders</CardTitle>
                <CardDescription><Link to="/dashboard/orders" className="underline underline-offset-4">View all orders</Link></CardDescription>
            </CardHeader>
            <CardContent>
                {if not loading and len(orders) == 0 {
                    <p className="text-sm text-muted-foreground">No orders yet.</p>
                } else {
                    <Table>
                        <TableHeader>
                            <TableRow>
                                <TableHead>Order</TableHead>
                                <TableHead>Customer</TableHead>
                                <TableHead className="text-right">Amount</TableHead>
                                <TableHead>Status</TableHead>
                            </TableRow>
                        </TableHeader>
                        <TableBody>
                            {for o in orders {
                                <TableRow key={o.order_id}>
                                    <TableCell className="font-medium">{o.order_id}</TableCell>
                                    <TableCell>{o.customer_name}</TableCell>
                                    <TableCell className="text-right tabular-nums">{format_kes(o.total_kes)}</TableCell>
                                    <TableCell><StatusBadge status={o.status} /></TableCell>
                                </TableRow>
                            }}
                        </TableBody>
                    </Table>
                }}
            </CardContent>
        </Card>
    </DashboardShell>
}
