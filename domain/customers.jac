"""Customer (retailer) records for a business."""

import from domain.models { Business, Customer, ServesCustomer }
import from domain.errors { DomainError }
import from domain.catalogue { require_text }

"""Normalise a Kenyan mobile number to +254XXXXXXXXX."""
def normalise_phone(phone: str) -> str {
    raw = phone.strip() if isinstance(phone, str) else "";
    digits = "".join([c for c in raw if c.isdigit()]);
    if digits.startswith("254") and len(digits) == 12 {
        national = digits[3:];
    } elif digits.startswith("0") and len(digits) == 10 {
        national = digits[1:];
    } elif len(digits) == 9 {
        national = digits;
    } else {
        raise DomainError(code="VALIDATION_ERROR", message=f"Phone must be a Kenyan mobile number, got {phone!r}");
    }
    if national[0] not in ["7", "1"] {
        raise DomainError(code="VALIDATION_ERROR", message=f"Phone must be a Kenyan mobile number, got {phone!r}");
    }
    return "+254" + national;
}

def list_customers(biz: Business) -> list[Customer] {
    return sorted(
        [c for c in [biz ->:ServesCustomer:->] if c.active],
        key=lambda (c: Customer) { c.name.lower(); }
    );
}

def find_customer(biz: Business, customer_id: str) -> Customer | None {
    for c in [biz ->:ServesCustomer:->] {
        if c.customer_id == customer_id { return c; }
    }
    return None;
}

def get_customer(biz: Business, customer_id: str) -> Customer {
    customer = find_customer(biz, customer_id);
    if customer is None or not customer.active {
        raise DomainError(code="CUSTOMER_NOT_FOUND", message=f"No customer {customer_id}");
    }
    return customer;
}

def find_customer_by_phone(biz: Business, phone: str) -> Customer | None {
    wanted = normalise_phone(phone);
    for c in [biz ->:ServesCustomer:->] {
        if c.phone == wanted { return c; }
    }
    return None;
}

def create_customer(biz: Business, name: str, phone: str) -> Customer {
    clean_name = require_text(name, "Name");
    clean_phone = normalise_phone(phone);
    existing = find_customer_by_phone(biz, clean_phone);
    if existing is not None {
        raise DomainError(code="DUPLICATE_CUSTOMER", message=f"{clean_phone} already belongs to {existing.name}");
    }
    customer = Customer(
        customer_id=f"C-{biz.next_customer_number:03d}",
        name=clean_name,
        phone=clean_phone
    );
    biz.next_customer_number += 1;
    biz +>:ServesCustomer():+> customer;
    return customer;
}
