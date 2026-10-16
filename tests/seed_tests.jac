"""P2.8: seed data."""

import from domain.models { Business, Order, HasOrder }
import from domain.catalogue { list_products, inventory_of, get_product }
import from domain.customers { list_customers }
import from domain.seed { seed_demo_data }
import from domain.orders { list_orders }

test "seed loads catalogue, stock, customers and delivered history without touching stock" {
    biz = Business(name="My Wholesale");
    n = seed_demo_data(biz);
    assert n == 39 and len(list_products(biz)) == 39 and len(list_customers(biz)) == 3;
    assert biz.name == "Karibu Wholesalers";
    assert any([inventory_of(p).quantity_on_hand == 0 for p in list_products(biz)]);
    rina = inventory_of(get_product(biz, "RINA-1L-CTN"));
    assert (rina.quantity_on_hand, rina.quantity_reserved) == (8, 0);
    orders = list_orders(biz);
    assert len(orders) == 7 and all([o.status == "DELIVERED" for o in orders]);
    mama = [o for o in orders if o.customer_id == "C-001"];
    assert len(mama) == 3 and all([o.total_kes == 28500 for o in mama]);
    assert seed_demo_data(biz) == 0 and len(list_products(biz)) == 39 and len(list_orders(biz)) == 7;
}
