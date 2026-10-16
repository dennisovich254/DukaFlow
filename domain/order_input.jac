"""Order line input shared by endpoints and domain. Quantity is `any` so a fractional
value reaches validation instead of being truncated."""

obj OrderItemInput {
    has sku: str,
        quantity: any;
}
