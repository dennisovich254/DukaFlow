"""P1.7: customers."""

import from domain.models { Business }
import from domain.customers { create_customer, list_customers, find_customer_by_phone, normalise_phone }
import from domain.errors { DomainError }
import from tests.helpers { code_of }

test "create then find by phone, in any common format" {
    biz = Business(name="T");
    c = create_customer(biz, name="Mama Wanjiku Shop", phone="0712 345 678");
    assert (c.customer_id, c.phone) == ("C-001", "+254712345678");
    found = find_customer_by_phone(biz, "+254 712-345-678");
    assert found is not None and found.name == "Mama Wanjiku Shop";
    assert create_customer(biz, name="Kamau", phone="0722000002").customer_id == "C-002";
}

test "duplicate phone is rejected" {
    biz = Business(name="T");
    create_customer(biz, name="A", phone="0712345678");
    with testraises(DomainError) as e { create_customer(biz, name="B", phone="+254712345678"); }
    assert code_of(e.value) == "DUPLICATE_CUSTOMER";
    assert len(list_customers(biz)) == 1;
}

test "bad names and numbers are rejected" {
    biz = Business(name="T");
    for bad in ["12345", "0812345678", "abc", ""] {
        with testraises(DomainError) as e { create_customer(biz, name="X", phone=bad); }
        assert code_of(e.value) == "VALIDATION_ERROR";
    }
    with testraises(DomainError) as e2 { create_customer(biz, name="  ", phone="0712345678"); }
    assert code_of(e2.value) == "VALIDATION_ERROR";
    assert normalise_phone("0112345678") == "+254112345678";
}
