"""Resolve a business. The business graph lives on root.shared, one Business per
wholesaler, found by the owner's root id."""

import from domain.models { Business, HasBusiness }

glob DEFAULT_BUSINESS_NAME: str = "My Wholesale";

def find_business(owner_root_id: str) -> Business | None {
    for b in [root.shared ->:HasBusiness:->] {
        if b.owner_root_id == owner_root_id { return b; }
    }
    return None;
}

"""Return the signed-in wholesaler's Business, creating it on first use."""
def current_business() -> Business {
    owner = str(jid(root));
    found = find_business(owner);
    if found is not None { return found; }
    biz = Business(name=DEFAULT_BUSINESS_NAME, owner_root_id=owner);
    root.shared +>:HasBusiness():+> biz;
    return biz;
}
