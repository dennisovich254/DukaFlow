import from "@jac/runtime" { Link }
import from ....api.products { list_catalogue }
import from ....api.contracts { ProductView, CatalogueQuery }
import from ....components.dashboard.Shell { DashboardShell, PageHeader }
import from ....components.ui.card { Card, CardHeader, CardTitle, CardDescription }

glob LOW_STOCK: int = 5;

"""Overview: headline numbers (expanded in P2)."""
def:pub OverviewPage() -> JsxPage {
    has products: list[ProductView] = [];
    has loading: bool = True;

    async can with entry {
        products = await list_catalogue(CatalogueQuery(include_inactive=False));
        loading = False;
    }

    low_stock = len([p for p in products if p.quantity_available <= LOW_STOCK]);

    <DashboardShell>
        <PageHeader title="Overview" description="What is happening in your business today." />
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            <Card><CardHeader><CardDescription>Products</CardDescription><CardTitle className="text-3xl font-semibold tabular-nums">{"–" if loading else len(products)}</CardTitle></CardHeader></Card>
            <Card><CardHeader><CardDescription>Low or out of stock</CardDescription><CardTitle className="text-3xl font-semibold tabular-nums">{"–" if loading else low_stock}</CardTitle></CardHeader></Card>
        </div>
        <p className="text-sm text-muted-foreground">
            <Link to="/dashboard/products" className="underline underline-offset-4">Manage products and stock</Link>
        </p>
    </DashboardShell>
}
