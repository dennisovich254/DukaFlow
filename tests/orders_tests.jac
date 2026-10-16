"""P1.7: manual orders with captured prices."""

import from domain.models { Business, Customer, ContainsLine, PlacedOrder }
import from domain.catalogue { create_product, update_product }
import from domain.customers { create_customer }
import from domain.orders { create_manual_order, list_orders, get_order }
import from domain.order_input { OrderItemInput }
import from domain.errors { DomainError }
import from tests.helpers { code_of }

def setup() -> Business {
    biz = Business(name="T");
    create_product(biz, sku="RINA-1L-CTN", name="Rina 1L Carton", brand="Rina", category="Oil", unit="carton", price_kes=2800);
    create_product(biz, sku="JOGOO-2KG-BALE", name="Jogoo 2kg Bale", brand="Jogoo", category="Flour", unit="bale", price_kes=1450);
    create_customer(biz, name="Mama Wanjiku Shop", phone="0700000001");
    return biz;
}

test "order with two lines has correct totals" {
    biz = setup();
    order = create_manual_order(biz, "C-001", [
        OrderItemInput(sku="RINA-1L-CTN", quantity=5), OrderItemInput(sku="JOGOO-2KG-BALE", quantity=10)
    ]);
    assert (order.order_id, order.status, order.channel, order.total_kes) == ("ORD-1001", "DRAFT", "manual", 28500);
    lines = [order ->:ContainsLine:->];
    assert sorted([(l.product_sku, l.quantity, l.unit_price_kes, l.line_total_kes) for l in lines]) == [
        ("JOGOO-2KG-BALE", 10, 1450, 14500), ("RINA-1L-CTN", 5, 2800, 14000)
    ];
}

test "ids are sequential, newest first, repeated skus merge" {
    biz = setup();
    create_manual_order(biz, "C-001", [OrderItemInput(sku="RINA-1L-CTN", quantity=1)]);
    o2 = create_manual_order(biz, "C-001", [OrderItemInput(sku="rina-1l-ctn", quantity=1), OrderItemInput(sku="RINA-1L-CTN", quantity=2)]);
    assert [o.order_id for o in list_orders(biz)] == ["ORD-1002", "ORD-1001"];
    assert len([o2 ->:ContainsLine:->]) == 1 and o2.total_kes == 8400;
}

test "captured price does not change when the catalogue price changes" {
    biz = setup();
    create_manual_order(biz, "C-001", [OrderItemInput(sku="RINA-1L-CTN", quantity=5)]);
    update_product(biz, "RINA-1L-CTN", price_kes=3000);
    order = get_order(biz, "ORD-1001");
    assert order.total_kes == 14000;
    assert [order ->:ContainsLine:->][0].unit_price_kes == 2800;
}

test "order is linked to its customer" {
    biz = setup();
    create_manual_order(biz, "C-001", [OrderItemInput(sku="RINA-1L-CTN", quantity=1)]);
    customer = [biz -->[?:Customer]][0];
    assert [o.order_id for o in [customer ->:PlacedOrder:->]] == ["ORD-1001"];
}

test "bad lines create no order and no number is used" {
    biz = setup();
    with testraises(DomainError) as e1 { create_manual_order(biz, "C-001", [OrderItemInput(sku="NOPE", quantity=1)]); }
    assert code_of(e1.value) == "PRODUCT_NOT_FOUND";
    with testraises(DomainError) as e2 { create_manual_order(biz, "C-001", [OrderItemInput(sku="RINA-1L-CTN", quantity=0)]); }
    assert code_of(e2.value) == "INVALID_QUANTITY";
    with testraises(DomainError) as e3 { create_manual_order(biz, "C-009", [OrderItemInput(sku="RINA-1L-CTN", quantity=1)]); }
    assert code_of(e3.value) == "CUSTOMER_NOT_FOUND";
    with testraises(DomainError) as e4 { create_manual_order(biz, "C-001", []); }
    assert code_of(e4.value) == "VALIDATION_ERROR";
    assert list_orders(biz) == [] and biz.next_order_number == 1001;
}
