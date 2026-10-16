"""Inventory changes. Every change goes through `apply_stock_change`, which validates
before writing and records an InventoryMovement."""

import from domain.models { Business, Product, InventoryRecord, InventoryMovement, HasMovement }
import from domain.errors { DomainError }
import from domain.catalogue { get_product, inventory_of, require_text }
import from domain.clock { now_iso }

def require_nonzero_int(value: any) -> int {
    if isinstance(value, bool) or not isinstance(value, int) or (value as int) == 0 {
        raise DomainError(
            code="INVALID_QUANTITY",
            message=f"Quantity change must be a non-zero whole number, got {value!r}"
        );
    }
    return value as int;
}

"""Apply on-hand and reserved deltas: both results are validated before either is written."""
def apply_stock_change(
    product: Product, on_hand_delta: int, reserved_delta: int,
    movement_type: str, reason: str, reference: str = ""
) -> InventoryRecord {
    rec = inventory_of(product);
    new_on_hand = rec.quantity_on_hand + on_hand_delta;
    new_reserved = rec.quantity_reserved + reserved_delta;
    if new_on_hand < 0 or new_reserved < 0 or new_reserved > new_on_hand {
        raise DomainError(
            code="INSUFFICIENT_STOCK",
            message=(
                f"{product.sku}: on hand {rec.quantity_on_hand}, reserved "
                f"{rec.quantity_reserved}; cannot apply on-hand {on_hand_delta:+d}, "
                f"reserved {reserved_delta:+d}"
            )
        );
    }
    rec.quantity_on_hand = new_on_hand;
    rec.quantity_reserved = new_reserved;
    product +>:HasMovement():+> InventoryMovement(
        movement_type=movement_type,
        quantity=on_hand_delta if on_hand_delta != 0 else reserved_delta,
        reason=reason,
        reference=reference,
        created_at=now_iso()
    );
    return rec;
}

"""Manual stock correction by the wholesaler (deliveries, damage, counts)."""
def adjust_inventory(biz: Business, sku: str, quantity_change: any, reason: str) -> InventoryRecord {
    change = require_nonzero_int(quantity_change);
    clean_reason = require_text(reason, "Reason");
    product = get_product(biz, sku);
    return apply_stock_change(product, change, 0, "ADJUSTMENT", clean_reason);
}
