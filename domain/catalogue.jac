"""Product catalogue rules. Creating a product also creates its stock record at 0."""

import from domain.models {
    Business, Product, InventoryRecord, OwnsProduct, HasInventory
}
import from domain.errors { DomainError }
import from domain.pricing { validate_price_kes }

glob UNITS: list[str] = ["carton", "bale", "dozen", "bag", "crate", "piece", "bottle", "packet", "kg", "litre"];

def normalise_sku(sku: str) -> str {
    return sku.strip().upper();
}

def require_text(value: str, label: str) -> str {
    clean = value.strip() if isinstance(value, str) else "";
    if not clean {
        raise DomainError(code="VALIDATION_ERROR", message=f"{label} cannot be empty");
    }
    return clean;
}

def require_unit(unit: str) -> str {
    clean = unit.strip().lower() if isinstance(unit, str) else "";
    if clean not in UNITS {
        raise DomainError(code="VALIDATION_ERROR", message=f"Unit must be one of {', '.join(UNITS)}");
    }
    return clean;
}

def find_product(biz: Business, sku: str) -> Product | None {
    wanted = normalise_sku(sku);
    for p in [biz ->:OwnsProduct:->] {
        if p.sku == wanted { return p; }
    }
    return None;
}

def get_product(biz: Business, sku: str) -> Product {
    product = find_product(biz, sku);
    if product is None {
        raise DomainError(code="PRODUCT_NOT_FOUND", message=f"No product with SKU {sku}");
    }
    return product;
}

def inventory_of(product: Product) -> InventoryRecord {
    return [product ->:HasInventory:->][0];
}

def create_product(
    biz: Business, sku: str, name: str, brand: str, category: str, unit: str,
    price_kes: any, aliases: list[str] = []
) -> Product {
    clean_sku = require_text(normalise_sku(sku), "SKU");
    if find_product(biz, clean_sku) is not None {
        raise DomainError(code="DUPLICATE_SKU", message=f"SKU {clean_sku} already exists");
    }
    product = Product(
        sku=clean_sku,
        name=require_text(name, "Name"),
        brand=brand.strip(),
        category=category.strip(),
        unit=require_unit(unit),
        price_kes=validate_price_kes(price_kes),
        aliases=[a.strip().lower() for a in aliases if a.strip()]
    );
    biz +>:OwnsProduct():+> product;
    product +>:HasInventory():+> InventoryRecord();
    return product;
}

def list_products(biz: Business, include_inactive: bool = False) -> list[Product] {
    products = sorted([biz ->:OwnsProduct:->], key=lambda (p: Product) { p.name.lower(); });
    if include_inactive { return products; }
    return [p for p in products if p.active];
}

"""Update permitted fields. Every value is validated before anything changes."""
def update_product(
    biz: Business, sku: str, name: str | None = None, brand: str | None = None,
    category: str | None = None, unit: str | None = None, price_kes: any = None,
    aliases: list[str] | None = None, active: bool | None = None
) -> Product {
    product = get_product(biz, sku);
    new_name = require_text(name, "Name") if name is not None else product.name;
    new_unit = require_unit(unit) if unit is not None else product.unit;
    new_price = validate_price_kes(price_kes) if price_kes is not None else product.price_kes;
    product.name = new_name;
    product.unit = new_unit;
    product.price_kes = new_price;
    if brand is not None { product.brand = brand.strip(); }
    if category is not None { product.category = category.strip(); }
    if aliases is not None { product.aliases = [a.strip().lower() for a in aliases if a.strip()]; }
    if active is not None { product.active = active; }
    return product;
}
