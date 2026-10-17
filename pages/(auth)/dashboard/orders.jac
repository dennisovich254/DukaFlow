import from "sonner" { toast }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { Message01Icon, PencilEdit01Icon, Search01Icon }
import from ....api.products { list_catalogue }
import from ....api.customers { list_customer_records }
import from ....api.orders { list_order_records, create_order, act_on_order }
import from ....api.review { order_review }
import from ....api.dashboard { dashboard_analytics }
import from ....api.contracts {
    ProductView, CustomerView, OrderView, OrderResult, CatalogueQuery, NewOrderInput, OrderActionInput,
    ReviewView, ReviewResult, OrderLookup
}
import from ....domain.order_input { OrderItemInput }
import from ....lib.money { format_kes }
import from ....components.dashboard.Shell { DashboardShell, PageHeader }
import from ....components.dashboard.StatusBadge { StatusBadge }
import from ....components.dashboard.PhotoThumb { PhotoThumb }
import from ....components.ui.button { Button }
import from ....components.ui.input { Input }
import from ....components.ui.field { Field, FieldLabel, FieldGroup }
import from ....components.ui.native_select { NativeSelect, NativeSelectOption }
import from ....components.ui.card { Card, CardContent }
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

"""Status tabs: [key, label, statuses]. An empty list means every status."""
glob TABS: list[list[any]] = [
    ["all", "All", []],
    ["approval", "Needs approval", ["PENDING_APPROVAL"]],
    ["progress", "In progress", ["DRAFT", "QUOTED", "APPROVED", "PACKED", "DISPATCHED"]],
    ["delivered", "Delivered", ["DELIVERED"]],
    ["closed", "Closed", ["REJECTED", "CANCELLED", "EXPIRED"]]
];

glob MONTHS: list[str] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

"""'2026-10-16T14:02:11+03:00' -> 'Today, 14:02' or '16 Oct, 14:02'."""
def when(iso: str, today: str) -> str {
    if len(iso) < 16 { return iso; }
    if iso[:10] == today { return "Today, " + iso[11:16]; }
    return str(int(iso[8:10])) + " " + MONTHS[int(iso[5:7]) - 1] + ", " + iso[11:16];
}

def initials(name: str) -> str {
    parts = [p for p in name.split(" ") if len(p) > 0];
    if len(parts) == 0 { return "?"; }
    return (parts[0][0] + (parts[1][0] if len(parts) > 1 else "")).upper();
}

"""First two lines of an order as text, then '+ N more'."""
def items_text(o: OrderView) -> str {
    first = [f"{l.quantity} {l.unit} {l.product_name}" for l in o.lines[:2]];
    more = len(o.lines) - 2;
    return ", ".join(first) + (f" + {more} more" if more > 0 else "");
}

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
    has review: ReviewView | None = None;
    has reviewingId: str = "";
    has tab: str = "";
    has query: str = "";
    has today: str = "";

    async def refresh {
        orders = await list_order_records();
        loading = False;
        if tab == "" {
            tab = "approval" if len([o for o in orders if o.status == "PENDING_APPROVAL"]) > 0 else "all";
        }
    }

    async can with entry {
        products = await list_catalogue(CatalogueQuery(include_inactive=False));
        customers = await list_customer_records();
        await refresh();
        stats = await dashboard_analytics();
        today = stats.today;
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

    async def open_review(orderId: str) {
        reviewingId = orderId;
        review = None;
        res = await order_review(OrderLookup(order_id=orderId));
        if res.ok and res.review is not None { review = res.review; }
    }

    async def review_action(orderId: str, action: str) {
        await run_action(orderId, action);
        res = await order_review(OrderLookup(order_id=orderId));
        if res.ok and res.review is not None { review = res.review; }
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
    waiting = [o for o in orders if o.status == "PENDING_APPROVAL"];
    in_progress_value = sum([o.total_kes for o in orders if o.status in ["APPROVED", "PACKED", "DISPATCHED"]]);
    needle = query.strip().lower();
    active_statuses = [t[2] for t in TABS if t[0] == tab];
    shown = [
        o for o in orders
        if (len(active_statuses) == 0 or len(active_statuses[0]) == 0 or o.status in active_statuses[0])
        and (needle == "" or needle in o.customer_name.lower() or needle in o.order_id.lower())
    ];

    def tab_count(statuses: list[str]) -> int {
        return len(orders) if len(statuses) == 0 else len([o for o in orders if o.status in statuses]);
    }

    <DashboardShell>
        <PageHeader title="Orders" description="Review, approve and track every order. Click an order to see the customer's chat and the quoted lines.">
            <Button onClick={open_new} disabled={not can_create}>New manual order</Button>
        </PageHeader>
        {if not loading and not can_create {
            <p className="text-sm text-muted-foreground">Add at least one product and one customer before creating orders.</p>
        }}
        {if not loading and len(orders) > 0 {
            <p className="text-sm text-muted-foreground">
                {len(waiting)} {"order needs" if len(waiting) == 1 else "orders need"} approval · {format_kes(in_progress_value)} in progress · {len(orders)} in total
            </p>
        }}
        <div className="flex flex-wrap items-center justify-between gap-3">
            <div className="flex flex-wrap gap-2" role="tablist" aria-label="Filter orders by status">
                {for t in TABS {
                    <button key={t[0]} type="button" role="tab" aria-selected={tab == t[0]} onClick={lambda (e: any) { tab = t[0]; }}
                        className={"cursor-pointer rounded-full border pt-1.5 pb-1.5 pl-3.5 pr-3.5 text-sm outline-none focus-visible:ring-2 focus-visible:ring-[#0e0f0c] " + ("border-[#0e0f0c] bg-[#0e0f0c] text-white" if tab == t[0] else "border-[#e4e7dc] bg-white hover:bg-[#f3f5ee]")}>
                        {t[1]} <span className={"tabular-nums " + ("text-[#d9f99d]" if tab == t[0] else "text-muted-foreground")}>{tab_count(t[2])}</span>
                    </button>
                }}
            </div>
            <div className="relative w-full sm:w-64">
                <HugeiconsIcon icon={Search01Icon} strokeWidth={2} className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
                <Input aria-label="Search orders" placeholder="Search customer or order ID" value={query}
                    onChange={lambda (e: ChangeEvent) { query = e.target.value; }} className="rounded-full pl-9" />
            </div>
        </div>
        <Card>
            <CardContent>
                {if loading {
                    <p className="text-sm text-muted-foreground">Loading orders…</p>
                } elif len(orders) == 0 {
                    <p className="text-sm text-muted-foreground">No orders yet.</p>
                } elif len(shown) == 0 {
                    <p className="text-sm text-muted-foreground">No orders match.</p>
                } else {
                    <ul className="divide-y">
                        {for o in shown {
                            <li key={o.order_id} className="flex flex-wrap items-center gap-3 pt-3 pb-3">
                                <button type="button" onClick={lambda (e: any) { open_review(o.order_id); }}
                                    className="flex min-w-0 flex-1 basis-64 cursor-pointer items-center gap-3 rounded-lg text-left outline-none focus-visible:ring-2 focus-visible:ring-[#0e0f0c]">
                                    <span className="flex size-10 shrink-0 items-center justify-center rounded-full bg-[#d9f99d] text-sm font-semibold text-[#1a2e05]" aria-hidden="true">{initials(o.customer_name)}</span>
                                    <span className="min-w-0 flex-1">
                                        <span className="block truncate font-medium">{o.customer_name}</span>
                                        <span className="flex items-center gap-1.5 text-xs text-muted-foreground">
                                            <span title={"Chat order" if o.channel == "chat" else "Entered by you"} aria-label={"Chat order" if o.channel == "chat" else "Entered by you"}>
                                                <HugeiconsIcon icon={Message01Icon if o.channel == "chat" else PencilEdit01Icon} strokeWidth={2} className="size-3.5" />
                                            </span>
                                            {o.order_id} · {when(o.created_at, today)}
                                        </span>
                                        <span className="block truncate text-xs text-muted-foreground">{items_text(o)}</span>
                                    </span>
                                </button>
                                <span className="tabular-nums font-medium">{format_kes(o.total_kes)}</span>
                                <StatusBadge status={o.status} />
                                <span className="flex w-28 justify-end">
                                    {if len(ORDER_ACTIONS.get(o.status, [])) > 0 {
                                        <Button size="sm" variant={"default" if ORDER_ACTIONS[o.status][0][0] in ["approve", "submit", "dispatch"] else "outline"}
                                            onClick={lambda (e: any) { run_action(o.order_id, ORDER_ACTIONS[o.status][0][0]); }}>{ORDER_ACTIONS[o.status][0][1]}</Button>
                                    } else {
                                        <Button size="sm" variant="ghost" onClick={lambda (e: any) { open_review(o.order_id); }}>View</Button>
                                    }}
                                </span>
                            </li>
                        }}
                    </ul>
                }}
            </CardContent>
        </Card>
        <Dialog open={reviewingId != ""} onOpenChange={lambda (v: bool) { if not v { reviewingId = ""; review = None; } }}>
            <DialogContent className="max-h-[90vh] overflow-y-auto sm:max-w-3xl">
                <DialogHeader>
                    <DialogTitle>Order {reviewingId}</DialogTitle>
                    <DialogDescription>What the customer sent, how the agent read it, and the quoted lines.</DialogDescription>
                </DialogHeader>
                {if review is None {
                    <p className="text-sm text-muted-foreground">Loading…</p>
                } else {
                    <div className="grid gap-6 md:grid-cols-2">
                        <div className="flex flex-col gap-3">
                            <h3 className="text-sm font-medium">What the customer sent</h3>
                            {if len(review.messages) == 0 {
                                <p className="text-sm text-muted-foreground">Entered by hand: no chat messages.</p>
                            }}
                            {for m in review.messages {
                                <div key={str(m.seq)} className={"flex " + ("justify-end" if m.sender_type == "customer" else "justify-start")}>
                                    <div className={"max-w-[85%] rounded-2xl pt-2 pb-2 pl-3 pr-3 text-sm " + ("bg-primary text-primary-foreground" if m.sender_type == "customer" else "border bg-muted")}>
                                        {if m.message_type == "image" {
                                            <PhotoThumb customerId={review.order.customer_id} mediaRef={m.media_ref} />
                                        }}
                                        {if m.content { <p className="whitespace-pre-line break-words">{m.content}</p> }}
                                    </div>
                                </div>
                            }}
                        </div>
                        <div className="flex flex-col gap-4">
                            <div>
                                <h3 className="text-sm font-medium">Order lines</h3>
                                <p className="text-xs text-muted-foreground">{review.order.customer_name} · {review.order.channel} {"· quote " + review.quote_id if review.quote_id else ""}</p>
                                <ul className="mt-2 divide-y text-sm">
                                    {for l in review.order.lines {
                                        <li key={l.product_sku} className="flex justify-between gap-3 pt-2 pb-2">
                                            <span>{l.quantity} × {l.product_name}</span>
                                            <span className="tabular-nums">{format_kes(l.line_total_kes)}</span>
                                        </li>
                                    }}
                                </ul>
                                <p className="mt-2 flex justify-between text-sm font-semibold"><span>Total</span><span className="tabular-nums">{format_kes(review.order.total_kes)}</span></p>
                                {for n in review.quote_notes { <p key={n} className="mt-2 rounded-lg bg-amber-50 pt-2 pb-2 pl-3 pr-3 text-xs text-amber-900">{n}</p> }}
                            </div>
                            {if len(review.executions) > 0 {
                                <div>
                                    <h3 className="text-sm font-medium">How the agent read it</h3>
                                    <ul className="mt-2 flex flex-col gap-2">
                                        {for e in review.executions {
                                            <li key={str(e.message_seq)} className="rounded-lg border pt-2 pb-2 pl-3 pr-3 text-xs">
                                                <p className="font-medium">{e.input_type == "image" and "Photo" or "Text"} → {e.outcome} · {e.duration_ms} ms</p>
                                                {for (i, st) in enumerate(e.steps) { <p key={str(i)} className="font-mono text-[11px] text-muted-foreground break-words">{st}</p> }}
                                            </li>
                                        }}
                                    </ul>
                                </div>
                            }}
                            <div className="flex items-center gap-2">
                                <StatusBadge status={review.order.status} />
                                {for a in ORDER_ACTIONS.get(review.order.status, []) {
                                    <Button key={a[0]} size="sm" variant={"default" if a[0] in ["approve", "submit", "dispatch"] else "outline"}
                                        onClick={lambda { review_action(reviewingId, a[0]); }}>{a[1]}</Button>
                                }}
                            </div>
                        </div>
                    </div>
                }}
            </DialogContent>
        </Dialog>
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
