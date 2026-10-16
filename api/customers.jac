"""Authenticated customer endpoints."""

import from domain.errors { DomainError }
import from domain.customers { create_customer, list_customers }
import from api.business { current_business }
import from api.results { to_api_error }
import from api.contracts { CustomerView, CustomerResult, NewCustomerInput }

def:protect list_customer_records() -> list[CustomerView] {
    return [
        CustomerView(customer_id=c.customer_id, name=c.name, phone=c.phone)
        for c in list_customers(current_business())
    ];
}

def:protect add_customer(data: NewCustomerInput) -> CustomerResult {
    try {
        c = create_customer(current_business(), data.name, data.phone);
        return CustomerResult(ok=True, customer=CustomerView(customer_id=c.customer_id, name=c.name, phone=c.phone));
    } except DomainError as e {
        return CustomerResult(ok=False, error=to_api_error(e));
    }
}
