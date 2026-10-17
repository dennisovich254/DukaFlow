"""Authenticated dashboard summary and demo-data endpoints."""

import from domain.dashboard { get_dashboard_summary }
import from domain.analytics { get_analytics }
import from domain.customers { list_customers }
import from domain.catalogue { list_products }
import from domain.seed { seed_demo_data }
import from domain.clock { now_iso }
import from ai.agent { current_mode }
import from api.business { current_business }
import from api.orders { order_view }
import from api.contracts {
    DashboardSummaryView, AnalyticsView, DayPointView, StatusCountView, TopProductView,
    ChannelCountView, LowStockView, PendingView
}

def:protect dashboard_summary() -> DashboardSummaryView {
    biz = current_business();
    s = get_dashboard_summary(biz, now_iso()[:10]);
    return DashboardSummaryView(
        orders_today=s.orders_today,
        pending_approval=s.pending_approval,
        low_stock_count=s.low_stock_count,
        recent_orders=[order_view(biz, o) for o in s.recent_orders],
        ai_mode=current_mode()
    );
}

"""Load the demo catalogue into an empty business; returns products added."""
def:protect load_demo_data() -> int {
    return seed_demo_data(current_business());
}

"""Series and headline numbers for the Overview charts."""
def:protect dashboard_analytics() -> AnalyticsView {
    biz = current_business();
    today = now_iso()[:10];
    a = get_analytics(biz, today);
    s = get_dashboard_summary(biz, today);
    return AnalyticsView(
        days=[DayPointView(date=d.date, label=d.label, revenue_kes=d.revenue_kes, orders=d.orders) for d in a.days],
        revenue_7d=a.revenue_7d,
        revenue_prev_7d=a.revenue_prev_7d,
        orders_7d=a.orders_7d,
        avg_order_kes=a.avg_order_kes,
        status_counts=[StatusCountView(status=c.status, count=c.count) for c in a.status_counts],
        top_products=[TopProductView(sku=t.sku, name=t.name, quantity=t.quantity, revenue_kes=t.revenue_kes) for t in a.top_products],
        channels=[ChannelCountView(channel=c.channel, count=c.count) for c in a.channels],
        low_stock=[LowStockView(sku=i.sku, name=i.name, available=i.available) for i in a.low_stock],
        pending_count=a.pending_count,
        pending=[PendingView(order_id=p.order_id, customer_name=p.customer_name, total_kes=p.total_kes, created_at=p.created_at) for p in a.pending],
        recent_orders=[order_view(biz, o) for o in s.recent_orders],
        customer_count=len(list_customers(biz)),
        product_count=len(list_products(biz)),
        today=today,
        ai_mode=current_mode()
    );
}
