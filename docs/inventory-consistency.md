# Inventory consistency

**What the code guarantees**
- Every stock change goes through `apply_stock_change` (`domain/inventory.jac`). It validates on-hand and reserved against the current record immediately before writing, and refuses anything that would make stock negative or reserved exceed on-hand.
- Approving, dispatching or cancelling an order moves stock for all its lines through `move_order_stock`. If any line fails, lines already applied are reversed (recorded as `ROLLBACK` movements), so an order reserves fully or not at all.
- Order status only changes through `transition()`. A second approve or dispatch is refused (`INVALID_ORDER_STATE`), so it cannot double-reserve or double-deduct.

**What it does not guarantee**
- There is no database transaction or row lock. Correctness under truly simultaneous requests relies on each endpoint call running its check-then-write without yielding, which holds for a single-process demo.
- A multi-process deployment would need a real lock or an atomic database update.
- The rollback after a mid-order failure is compensating (reverse movements), not an atomic rollback.
