"""Wire contracts shared by server endpoints and client pages.

Kept free of server imports so client pages can import these types without
pulling server modules into the browser bundle. Money is integer whole KSh.
"""

obj ApiError {
    has code: str,
        message: str;
}

"""Product as returned to clients, including current stock levels."""
obj ProductView {
    has sku: str,
        name: str,
        brand: str,
        category: str,
        unit: str,
        price_kes: int,
        aliases: list[str],
        active: bool,
        quantity_on_hand: int,
        quantity_reserved: int,
        quantity_available: int;
}

obj ProductResult {
    has ok: bool,
        product: ProductView | None = None,
        error: ApiError | None = None;
}

"""Money and quantities are typed `any` so a fractional value reaches domain
validation instead of being silently truncated by an `int` parameter."""
obj NewProductInput {
    has sku: str,
        name: str,
        unit: str,
        price_kes: any,
        brand: str = "",
        category: str = "",
        aliases: list[str] | None = None;
}

obj EditProductInput {
    has sku: str,
        name: str | None = None,
        brand: str | None = None,
        category: str | None = None,
        unit: str | None = None,
        price_kes: any = None,
        aliases: list[str] | None = None,
        active: bool | None = None;
}

obj AdjustStockInput {
    has sku: str,
        quantity_change: any,
        reason: str;
}

obj CatalogueQuery {
    has include_inactive: bool = False;
}
