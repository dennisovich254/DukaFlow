"""Authenticated product and stock endpoints."""

import from domain.models { Product }
import from domain.errors { DomainError }
import from domain.catalogue { create_product, list_products, update_product, inventory_of, get_product }
import from domain.inventory { adjust_inventory }
import from api.business { current_business }
import from api.results { to_api_error }
import from api.contracts {
    ProductView, ProductResult, NewProductInput, EditProductInput, AdjustStockInput, CatalogueQuery
}

def to_view(p: Product) -> ProductView {
    rec = inventory_of(p);
    return ProductView(
        sku=p.sku, name=p.name, brand=p.brand, category=p.category, unit=p.unit,
        price_kes=p.price_kes, aliases=p.aliases, active=p.active,
        quantity_on_hand=rec.quantity_on_hand,
        quantity_reserved=rec.quantity_reserved,
        quantity_available=rec.available()
    );
}

def:protect list_catalogue(query: CatalogueQuery) -> list[ProductView] {
    return [to_view(p) for p in list_products(current_business(), query.include_inactive)];
}

def:protect add_product(data: NewProductInput) -> ProductResult {
    try {
        aliases = data.aliases if isinstance(data.aliases, list) else [];
        product = create_product(
            current_business(), data.sku, data.name, clean(data.brand), clean(data.category),
            data.unit, data.price_kes, aliases
        );
        return ProductResult(ok=True, product=to_view(product));
    } except DomainError as e {
        return ProductResult(ok=False, error=to_api_error(e));
    }
}

def:protect edit_product(data: EditProductInput) -> ProductResult {
    try {
        product = update_product(
            current_business(), data.sku, name=data.name, brand=data.brand,
            category=data.category, unit=data.unit, price_kes=data.price_kes,
            aliases=data.aliases, active=data.active
        );
        return ProductResult(ok=True, product=to_view(product));
    } except DomainError as e {
        return ProductResult(ok=False, error=to_api_error(e));
    }
}

def:protect adjust_stock(data: AdjustStockInput) -> ProductResult {
    try {
        biz = current_business();
        adjust_inventory(biz, data.sku, data.quantity_change, data.reason);
        return ProductResult(ok=True, product=to_view(get_product(biz, data.sku)));
    } except DomainError as e {
        return ProductResult(ok=False, error=to_api_error(e));
    }
}

"""An omitted optional top-level field can arrive as the string "None"."""
def clean(value: str) -> str {
    return "" if value == "None" else value;
}
