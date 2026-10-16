"""Authenticated dashboard summary and demo-data endpoints."""

import from domain.dashboard { get_dashboard_summary }
import from domain.seed { seed_demo_data }
import from domain.clock { now_iso }
import from ai.agent { current_mode }
import from api.business { current_business }
import from api.orders { order_view }
import from api.contracts { DashboardSummaryView }

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
