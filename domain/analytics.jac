"""Numbers and series for the Overview: sales by day, week-over-week change, status mix,
top products, channel split, low stock and orders waiting for approval.

"Sales" are orders the wholesaler has committed to (approved, packed, dispatched or delivered)."""

import from datetime { datetime, timedelta }
import from domain.models { Business, Order }
import from domain.catalogue { list_products, inventory_of }
import from domain.orders { list_orders, order_lines, order_number }
import from domain.customers { find_customer }

glob SALES_STATUSES: list[str] = ["APPROVED", "PACKED", "DISPATCHED", "DELIVERED"];
glob STATUS_ORDER: list[str] = [
    "PENDING_APPROVAL", "APPROVED", "PACKED", "DISPATCHED", "DELIVERED", "DRAFT", "REJECTED", "CANCELLED", "EXPIRED"
];
glob LOW_STOCK_LEVEL: int = 5;

obj DayPoint {
    has date: str,
        label: str,
        revenue_kes: int,
        orders: int;
}

obj StatusCount {
    has status: str,
        count: int;
}

obj TopProduct {
    has sku: str,
        name: str,
        quantity: int,
        revenue_kes: int;
}

obj ChannelCount {
    has channel: str,
        count: int;
}

obj LowStockItem {
    has sku: str,
        name: str,
        available: int;
}

obj PendingItem {
    has order_id: str,
        customer_name: str,
        total_kes: int,
        created_at: str;
}

obj Analytics {
    has days: list[DayPoint],
        revenue_7d: int,
        revenue_prev_7d: int,
        orders_7d: int,
        avg_order_kes: int,
        status_counts: list[StatusCount],
        top_products: list[TopProduct],
        channels: list[ChannelCount],
        low_stock: list[LowStockItem],
        pending_count: int,
        pending: list[PendingItem];
}

def day_strings(today: str, count: int, offset: int = 0) -> list[str] {
    base = datetime.strptime(today, "%Y-%m-%d");
    return [(base - timedelta(days=offset + i)).strftime("%Y-%m-%d") for i in range(count - 1, -1, -1)];
}

def day_label(day: str) -> str {
    return datetime.strptime(day, "%Y-%m-%d").strftime("%a %d");
}

def on_days(o: Order, days: list[str]) -> bool {
    return o.created_at[:10] in days;
}

"""`today` is an ISO date such as 2026-10-17 (Africa/Nairobi)."""
def get_analytics(biz: Business, today: str) -> Analytics {
    orders = list_orders(biz);
    week = day_strings(today, 7);
    prev_week = day_strings(today, 7, 7);
    month = day_strings(today, 30);

    points: list[DayPoint] = [];
    for d in week {
        todays = [o for o in orders if o.created_at[:10] == d];
        points.append(DayPoint(
            date=d, label=day_label(d),
            revenue_kes=sum([o.total_kes for o in todays if o.status in SALES_STATUSES]),
            orders=len(todays)
        ));
    }
    week_orders = [o for o in orders if on_days(o, week)];
    revenue = sum([p.revenue_kes for p in points]);
    prev_revenue = sum([o.total_kes for o in orders if on_days(o, prev_week) and o.status in SALES_STATUSES]);
    sales_orders = [o for o in week_orders if o.status in SALES_STATUSES];
    avg = int(revenue / len(sales_orders)) if sales_orders else 0;

    counts: dict[str, int] = {};
    for o in orders { counts[o.status] = counts.get(o.status, 0) + 1; }
    status_counts = [StatusCount(status=s, count=counts[s]) for s in STATUS_ORDER if counts.get(s, 0) > 0];

    sold: dict[str, tuple[str, int, int]] = {};
    chan: dict[str, int] = {};
    for o in [x for x in orders if on_days(x, month)] {
        if o.status not in ["CANCELLED", "REJECTED", "EXPIRED"] {
            chan[o.channel] = chan.get(o.channel, 0) + 1;
        }
        if o.status in SALES_STATUSES {
            for l in order_lines(o) {
                (name, qty, rev) = sold.get(l.product_sku, (l.product_name, 0, 0));
                sold[l.product_sku] = (name, qty + l.quantity, rev + l.line_total_kes);
            }
        }
    }
    top = sorted(
        [TopProduct(sku=k, name=v[0], quantity=v[1], revenue_kes=v[2]) for (k, v) in sold.items()],
        key=lambda (t: TopProduct) { -t.revenue_kes; }
    )[:5];
    channels = sorted(
        [ChannelCount(channel=k, count=v) for (k, v) in chan.items()],
        key=lambda (c: ChannelCount) { -c.count; }
    );

    low = sorted(
        [LowStockItem(sku=p.sku, name=p.name, available=max(inventory_of(p).available(), 0))
         for p in list_products(biz) if inventory_of(p).available() <= LOW_STOCK_LEVEL],
        key=lambda (i: LowStockItem) { (i.available, i.name); }
    )[:6];

    waiting = sorted([o for o in orders if o.status == "PENDING_APPROVAL"], key=lambda (o: Order) { (o.created_at, order_number(o)); });
    pending: list[PendingItem] = [];
    for o in waiting[:3] {
        c = find_customer(biz, o.customer_id);
        pending.append(PendingItem(
            order_id=o.order_id, customer_name=c.name if c else o.customer_id,
            total_kes=o.total_kes, created_at=o.created_at
        ));
    }
    return Analytics(
        days=points, revenue_7d=revenue, revenue_prev_7d=prev_revenue, orders_7d=len(week_orders),
        avg_order_kes=avg, status_counts=status_counts, top_products=top, channels=channels,
        low_stock=low, pending_count=len(waiting), pending=pending
    );
}
