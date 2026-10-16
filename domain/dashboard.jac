"""Headline numbers for the Overview page."""

import from domain.models { Business, Order }
import from domain.catalogue { list_products, inventory_of }
import from domain.orders { list_orders }

glob LOW_STOCK_THRESHOLD: int = 5;

obj DashboardSummary {
    has orders_today: int,
        pending_approval: int,
        low_stock_count: int,
        recent_orders: list[Order];
}

"""`today` is an ISO date prefix such as 2026-10-16 (Africa/Nairobi)."""
def get_dashboard_summary(biz: Business, today: str) -> DashboardSummary {
    orders = list_orders(biz);
    low = 0;
    for p in list_products(biz) {
        if inventory_of(p).available() <= LOW_STOCK_THRESHOLD { low += 1; }
    }
    return DashboardSummary(
        orders_today=len([o for o in orders if o.created_at.startswith(today)]),
        pending_approval=len([o for o in orders if o.status == "PENDING_APPROVAL"]),
        low_stock_count=low,
        recent_orders=orders[:5]
    );
}
