import from "sonner" { toast }
import from ....api.products { list_catalogue }
import from ....api.customers { list_customer_records }
import from ....api.orders { list_order_records, create_order, act_on_order }
import from ....api.contracts {
    ProductView, CustomerView, OrderView, OrderResult, CatalogueQuery, NewOrderInput, OrderActionInput
}
import from ....domain.order_input { OrderItemInput }
import from ....lib.money { format_kes }
import from ....components.dashboard.Shell { DashboardShell, PageHeader }
import from ....components.dashboard.StatusBadge { StatusBadge }
import from ....components.ui.button { Button }
import from ....components.ui.input { Input }
import from ....components.ui.field { Field, FieldLabel, FieldGroup }
import from ....components.ui.native_select { NativeSelect, NativeSelectOption }
import from ....components.ui.card { Card, CardContent }
import from ....components.ui.table { Table, TableHeader, TableBody, TableRow, TableHead, TableCell }
import from ....components.ui.dialog {
    Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter
}

"""Buttons offered for each order status: [action, label]."""
glob ORDER_ACTIONS: dict[str, list[list[str]]] = {
    "DRAFT": [["submit", "Submit"], ["cancel", "Cancel"]],
    "QUOTED": [["cancel", "Cancel"]],
    "PENDING_APPROVAL": [["approve", "Approve"], ["reject", "Reject"]],
    "APPROVED": [["dispatch", "Dispatch"], ["cancel", "Cancel"]],
    "PACKED": [["dispatch", "Dispatch"], ["cancel", "Cancel"]],
    "DISPATCHED": [["deliver", "Mark delivered"]]
};

"""A draft order line in the form (strings until submitted)."""
obj DraftLine {
    has sku: str = "",
        quantity: str = "1";
}

"""All orders, plus manual order entry (e.g. orders taken by phone)."""
def:pub OrdersPage() -> JsxPage {
    has orders: list[OrderView] = [];
    has products: list[ProductView] = [];
    has customers: list[CustomerView] = [];
    has loading: bool = True;
    has creating: bool = False;
    has saving: bool = False;
    has customerId: str = "";
    has lines: list[DraftLine] = [];

    async def refresh {
        orders = await list_order_records();
        loading = False;
    }

    async can with entry {
        products = await list_catalogue(CatalogueQuery(include_inactive=False));
        customers = await list_customer_records();
        await refresh();
    }

    async def run_action(order_id: str, action: str) {
        result: OrderResult | None = None;
        result = await act_on_order(OrderActionInput(
            order_id=order_id, action=action,
            reason="Rejected by wholesaler" if action == "reject" else ""
        ));
        if result.ok and result.order is not None {
            toast.success(f"{result.order.order_id}: {action} done");
        } elif result.error is not None {
            toast.error(result.error.message);
        }
        await refresh();
        products = await list_catalogue(CatalogueQuery(include_inactive=False));
    }

    def first_sku() -> str {
        return products[0].sku if len(products) > 0 else "";
    }

    def open_new(e: MouseEvent) {
        customerId = customers[0].customer_id if len(customers) > 0 else "";
        lines = [DraftLine(sku=first_sku(), quantity="1")];
        creating = True;
    }

    def set_line(index: int, sku: str, quantity: str) {
        lines = [DraftLine(sku=sku, quantity=quantity) if i == index else l for (i, l) in enumerate(lines)];
    }

    def add_line(e: MouseEvent) {
        lines = lines + [DraftLine(sku=first_sku(), quantity="1")];
    }

    def remove_line(index: int) {
        lines = [l for (i, l) in enumerate(lines) if i != index];
    }

    def price_of(sku: str) -> int {
        for p in products {
            if p.sku == sku { return p.price_kes; }
        }
        return 0;
    }

    async def save(e: FormEvent) {
        e.preventDefault();
        saving = True;
        result: OrderResult | None = None;
        result = await create_order(NewOrderInput(
            customer_id=customerId,
            items=[OrderItemInput(sku=l.sku, quantity=float(l.quantity)) for l in lines]
        ));
        saving = False;
        if result.ok and result.order is not None {
            toast.success(f"Created {result.order.order_id} · {format_kes(result.order.total_kes)}");
            creating = False;
            await refresh();
        } elif result.error is not None {
            toast.error(result.error.message);
        }
    }

    preview_total = sum([price_of(l.sku) * int(float(l.quantity or "0")) for l in lines]);
    can_create = len(products) > 0 and len(customers) > 0;

    <DashboardShell>
        <PageHeader title="Orders" description="Orders from all channels. Manual orders start as drafts.">
            <Button onClick={open_new} disabled={not can_create}>New manual order</Button>
        </PageHeader>
        {if not loading and not can_create {
            <p className="text-sm text-muted-foreground">Add at least one product and one customer before creating orders.</p>
        }}
        <Card>
            <CardContent>
                {if loading {
                    <p className="text-sm text-muted-foreground">Loading orders…</p>
                } elif len(orders) == 0 {
                    <p className="text-sm text-muted-foreground">No orders yet.</p>
                } else {
                    <Table>
                        <TableHeader>
                            <TableRow>
                                <TableHead>Order</TableHead>
                                <TableHead>Customer</TableHead>
                                <TableHead>Items</TableHead>
                                <TableHead className="text-right">Amount</TableHead>
                                <TableHead>Status</TableHead>
                                <TableHead>Channel</TableHead>
                                <TableHead>Actions</TableHead>
                            </TableRow>
                        </TableHeader>
                        <TableBody>
                            {for o in orders {
                                <TableRow key={o.order_id}>
                                    <TableCell className="font-medium">{o.order_id}</TableCell>
                                    <TableCell>{o.customer_name}</TableCell>
                                    <TableCell className="text-sm text-muted-foreground">
                                        {", ".join([f"{l.quantity} {l.unit} {l.product_name}" for l in o.lines])}
                                    </TableCell>
                                    <TableCell className="text-right tabular-nums">{format_kes(o.total_kes)}</TableCell>
                                    <TableCell><StatusBadge status={o.status} /></TableCell>
                                    <TableCell className="capitalize">{o.channel}</TableCell>
                                    <TableCell>
                                        <div className="flex gap-2">
                                            {for a in ORDER_ACTIONS.get(o.status, []) {
                                                <Button key={a[0]} size="sm"
                                                    variant={"default" if a[0] in ["approve", "submit", "dispatch"] else "outline"}
                                                    onClick={lambda { run_action(o.order_id, a[0]); }}>{a[1]}</Button>
                                            }}
                                        </div>
                                    </TableCell>
                                </TableRow>
                            }}
                        </TableBody>
                    </Table>
                }}
            </CardContent>
        </Card>
        <Dialog open={creating} onOpenChange={lambda (v: bool) { creating = v; }}>
            <DialogContent>
                <DialogHeader>
                    <DialogTitle>New manual order</DialogTitle>
                    <DialogDescription>Prices come from the catalogue; the total is calculated on the server.</DialogDescription>
                </DialogHeader>
                <form className="flex flex-col gap-6" onSubmit={save}>
                    <FieldGroup>
                        <Field>
                            <FieldLabel htmlFor="o-customer">Customer</FieldLabel>
                            <NativeSelect id="o-customer" value={customerId} onChange={lambda (e: ChangeEvent) { customerId = e.target.value; }}>
                                {for c in customers { <NativeSelectOption key={c.customer_id} value={c.customer_id}>{c.name}</NativeSelectOption> }}
                            </NativeSelect>
                        </Field>
                        {for (i, line) in enumerate(lines) {
                            <div key={str(i)} className="flex items-end gap-2">
                                <Field>
                                    <FieldLabel htmlFor={f"o-sku-{i}"}>Product</FieldLabel>
                                    <NativeSelect id={f"o-sku-{i}"} value={line.sku}
                                        onChange={lambda (e: ChangeEvent) { set_line(i, e.target.value, line.quantity); }}>
                                        {for p in products { <NativeSelectOption key={p.sku} value={p.sku}>{p.name} ({format_kes(p.price_kes)})</NativeSelectOption> }}
                                    </NativeSelect>
                                </Field>
                                <div className="w-24">
                                    <Field>
                                        <FieldLabel htmlFor={f"o-qty-{i}"}>Qty</FieldLabel>
                                        <Input id={f"o-qty-{i}"} type="number" min="1" step="1" required={True} value={line.quantity}
                                            onChange={lambda (e: ChangeEvent) { set_line(i, line.sku, e.target.value); }} />
                                    </Field>
                                </div>
                                <Button type="button" variant="ghost" disabled={len(lines) == 1}
                                    onClick={lambda { remove_line(i); }}>Remove</Button>
                            </div>
                        }}
                        <Button type="button" variant="outline" onClick={add_line}>Add another product</Button>
                    </FieldGroup>
                    <p className="text-right text-sm">Estimated total: <span className="font-semibold tabular-nums">{format_kes(preview_total)}</span></p>
                    <DialogFooter>
                        <Button type="button" variant="outline" onClick={lambda { creating = False; }}>Cancel</Button>
                        <Button type="submit" disabled={saving}>{"Creating…" if saving else "Create order"}</Button>
                    </DialogFooter>
                </form>
            </DialogContent>
        </Dialog>
    </DashboardShell>
}
