"""Realistic demo data: a Kenyan wholesaler's catalogue, stock, three customers and
order history for the agent's customer memory."""

import from domain.models { Business, Order }
import from domain.catalogue { create_product, list_products }
import from domain.customers { create_customer }
import from domain.inventory { adjust_inventory }
import from domain.orders { create_manual_order }
import from domain.order_input { OrderItemInput }

# [sku, name, brand, category, unit, price_kes, aliases, opening stock]
glob SEED_PRODUCTS: list[list[any]] = [
 [
  "RINA-1L-CTN",
  "Rina Cooking Oil 1L (12)",
  "Rina",
  "Cooking oil",
  "carton",
  2800,
  [
   "rina",
   "rina oil",
   "cooking oil 1l"
  ],
  8
 ],
 [
  "RINA-3L-CTN",
  "Rina Cooking Oil 3L (4)",
  "Rina",
  "Cooking oil",
  "carton",
  3100,
  [
   "rina 3l"
  ],
  25
 ],
 [
  "FRYING-1L-CTN",
  "Fresh Fri Oil 1L (12)",
  "Fresh Fri",
  "Cooking oil",
  "carton",
  2950,
  [
   "fresh fri",
   "fresh fry"
  ],
  30
 ],
 [
  "ELIANTO-1L-CTN",
  "Elianto Oil 1L (12)",
  "Elianto",
  "Cooking oil",
  "carton",
  3050,
  [
   "elianto"
  ],
  20
 ],
 [
  "JOGOO-2KG-BALE",
  "Jogoo Maize Flour 2kg (12)",
  "Jogoo",
  "Flour",
  "bale",
  1450,
  [
   "jogoo",
   "unga jogoo",
   "maize flour"
  ],
  60
 ],
 [
  "PEMBE-2KG-BALE",
  "Pembe Maize Flour 2kg (12)",
  "Pembe",
  "Flour",
  "bale",
  1480,
  [
   "pembe",
   "unga pembe"
  ],
  50
 ],
 [
  "SOKO-2KG-BALE",
  "Soko Maize Flour 2kg (12)",
  "Soko",
  "Flour",
  "bale",
  1420,
  [
   "soko",
   "unga soko"
  ],
  45
 ],
 [
  "EXE-2KG-BALE",
  "Exe Wheat Flour 2kg (12)",
  "Exe",
  "Flour",
  "bale",
  1650,
  [
   "exe",
   "wheat flour"
  ],
  30
 ],
 [
  "AJAB-2KG-BALE",
  "Ajab Wheat Flour 2kg (12)",
  "Ajab",
  "Flour",
  "bale",
  1670,
  [
   "ajab"
  ],
  28
 ],
 [
  "KABRAS-2KG-BALE",
  "Kabras Sugar 2kg (6)",
  "Kabras",
  "Sugar",
  "bale",
  1020,
  [
   "kabras",
   "sukari kabras",
   "sugar"
  ],
  70
 ],
 [
  "MUMIAS-2KG-BALE",
  "Mumias Sugar 2kg (6)",
  "Mumias",
  "Sugar",
  "bale",
  1040,
  [
   "mumias",
   "sukari mumias"
  ],
  55
 ],
 [
  "KABRAS-1KG-BALE",
  "Kabras Sugar 1kg (12)",
  "Kabras",
  "Sugar",
  "bale",
  1980,
  [
   "kabras 1kg"
  ],
  40
 ],
 [
  "SUNLIGHT-1KG-CTN",
  "Sunlight Soap Powder 1kg (12)",
  "Sunlight",
  "Detergent",
  "carton",
  1750,
  [
   "sunlight",
   "sunlight powder"
  ],
  35
 ],
 [
  "OMO-1KG-CTN",
  "Omo Detergent 1kg (12)",
  "Omo",
  "Detergent",
  "carton",
  2150,
  [
   "omo"
  ],
  30
 ],
 [
  "OMO-500G-CTN",
  "Omo Detergent 500g (24)",
  "Omo",
  "Detergent",
  "carton",
  2300,
  [
   "omo 500g"
  ],
  20
 ],
 [
  "TOP-1KG-CTN",
  "Ariel Powder 1kg (12)",
  "Ariel",
  "Detergent",
  "carton",
  2250,
  [
   "ariel"
  ],
  12
 ],
 [
  "JAMAA-BAR-CTN",
  "Jamaa Soap Bar (20)",
  "Jamaa",
  "Soap",
  "carton",
  1900,
  [
   "jamaa",
   "jamaa soap"
  ],
  25
 ],
 [
  "MENENGAI-BAR-CTN",
  "Menengai Soap Bar (20)",
  "Menengai",
  "Soap",
  "carton",
  1850,
  [
   "menengai"
  ],
  22
 ],
 [
  "GEISHA-BAR-DOZ",
  "Geisha Soap 175g",
  "Geisha",
  "Soap",
  "dozen",
  680,
  [
   "geisha"
  ],
  40
 ],
 [
  "ROYCO-CUBE-CTN",
  "Royco Mchuzi Mix Cubes (50)",
  "Royco",
  "Seasoning",
  "carton",
  1500,
  [
   "royco",
   "royco cubes"
  ],
  30
 ],
 [
  "ROYCO-MIX-CTN",
  "Royco Mchuzi Mix 200g (24)",
  "Royco",
  "Seasoning",
  "carton",
  2400,
  [
   "royco mix",
   "mchuzi mix"
  ],
  18
 ],
 [
  "BLUEBAND-500-CTN",
  "Blue Band 500g (12)",
  "Blue Band",
  "Spreads",
  "carton",
  2100,
  [
   "blue band",
   "blueband"
  ],
  20
 ],
 [
  "TROPICAL-HEAT-CTN",
  "Tropical Heat Cubes (40)",
  "Tropical Heat",
  "Seasoning",
  "carton",
  1200,
  [
   "tropical heat"
  ],
  15
 ],
 [
  "SALT-1KG-BALE",
  "Kensalt Table Salt 1kg (20)",
  "Kensalt",
  "Salt",
  "bale",
  780,
  [
   "kensalt",
   "chumvi"
  ],
  50
 ],
 [
  "TEA-KETEPA-CTN",
  "Ketepa Pride Tea 100g (50)",
  "Ketepa",
  "Tea",
  "carton",
  3400,
  [
   "ketepa",
   "chai",
   "ketepa pride"
  ],
  18
 ],
 [
  "TEA-TUSKYS-CTN",
  "Tusker Tea Leaves 250g (24)",
  "Tusker",
  "Tea",
  "carton",
  3000,
  [
   "majani chai"
  ],
  10
 ],
 [
  "RICE-PISHORI-BAG",
  "Pishori Rice 5kg",
  "Mwea",
  "Rice",
  "bag",
  950,
  [
   "pishori",
   "rice",
   "mchele"
  ],
  35
 ],
 [
  "RICE-BASMATI-BAG",
  "Basmati Rice 5kg",
  "Pearl",
  "Rice",
  "bag",
  1350,
  [
   "basmati"
  ],
  15
 ],
 [
  "BEANS-ROSECOCO-BAG",
  "Rosecoco Beans 2kg (6)",
  "Local",
  "Pulses",
  "bale",
  1250,
  [
   "beans",
   "maharagwe"
  ],
  30
 ],
 [
  "NDENGU-2KG-BALE",
  "Green Grams 2kg (6)",
  "Local",
  "Pulses",
  "bale",
  1350,
  [
   "ndengu",
   "green grams"
  ],
  20
 ],
 [
  "SPAGHETTI-400-CTN",
  "Santa Lucia Spaghetti 400g (20)",
  "Santa Lucia",
  "Pasta",
  "carton",
  1500,
  [
   "spaghetti",
   "pasta"
  ],
  25
 ],
 [
  "INDOMIE-CHICKEN-CTN",
  "Indomie Chicken Noodles (40)",
  "Indomie",
  "Noodles",
  "carton",
  1700,
  [
   "indomie",
   "noodles"
  ],
  40
 ],
 [
  "TISSUE-SOFT-BALE",
  "Softcare Tissue (10)",
  "Softcare",
  "Household",
  "bale",
  420,
  [
   "tissue",
   "toilet paper"
  ],
  4
 ],
 [
  "MATCH-BOX-DOZ",
  "Chui Matchboxes (12 packs)",
  "Chui",
  "Household",
  "dozen",
  320,
  [
   "matchbox",
   "kibiriti"
  ],
  30
 ],
 [
  "MILK-LATO-CTN",
  "Lato Milk UHT 500ml (12)",
  "Brookside",
  "Dairy",
  "carton",
  1250,
  [
   "maziwa",
   "milk"
  ],
  0
 ],
 [
  "BISCUIT-MARIE-CTN",
  "Menengai Marie Biscuits (24)",
  "Menengai",
  "Snacks",
  "carton",
  1100,
  [
   "biscuits",
   "marie"
  ],
  14
 ],
 [
  "COLGATE-100-DOZ",
  "Colgate Toothpaste 100g",
  "Colgate",
  "Toiletries",
  "dozen",
  1450,
  [
   "colgate",
   "toothpaste"
  ],
  20
 ],
 [
  "VASELINE-250-DOZ",
  "Vaseline Petroleum Jelly 250g",
  "Vaseline",
  "Toiletries",
  "dozen",
  2350,
  [
   "vaseline"
  ],
  12
 ],
 [
  "SODA-COKE-CRATE",
  "Coca-Cola 300ml Crate (24)",
  "Coca-Cola",
  "Drinks",
  "crate",
  1050,
  [
   "coke",
   "soda"
  ],
  25
 ]
];

glob SEED_CUSTOMERS: list[list[str]] = [
    ["Mama Wanjiku Shop", "+254712000001"],
    ["Kamau General Stores", "+254722000002"],
    ["Baraka Minimart", "+254733000003"]
];

# [created_at, customer id, [[sku, quantity], ...]] in date order; all are written as DELIVERED
# and never touch stock. Each customer's newest order is their usual (the agent's memory).
glob SEED_ORDERS: list[list[any]] = [
    ["2026-10-02T09:15:00+03:00", "C-001", [["RINA-1L-CTN", 5], ["JOGOO-2KG-BALE", 10]]],
    ["2026-10-05T11:20:00+03:00", "C-002", [["OMO-1KG-CTN", 3], ["KABRAS-2KG-BALE", 2]]],
    ["2026-10-06T12:30:00+03:00", "C-003", [["SALT-1KG-BALE", 4], ["RICE-PISHORI-BAG", 2]]],
    ["2026-10-07T10:02:00+03:00", "C-001", [["RINA-1L-CTN", 5], ["JOGOO-2KG-BALE", 10]]],
    ["2026-10-11T14:05:00+03:00", "C-002", [["OMO-1KG-CTN", 3], ["KABRAS-2KG-BALE", 2]]],
    ["2026-10-12T08:40:00+03:00", "C-001", [["RINA-1L-CTN", 5], ["JOGOO-2KG-BALE", 10]]],
    ["2026-10-13T09:50:00+03:00", "C-003", [["SALT-1KG-BALE", 4], ["RICE-PISHORI-BAG", 2]]],
    ["2026-10-14T08:45:00+03:00", "C-002", [["OMO-1KG-CTN", 6], ["ROYCO-CUBE-CTN", 2]]],
    ["2026-10-14T10:30:00+03:00", "C-003", [["SALT-1KG-BALE", 8], ["SUNLIGHT-1KG-CTN", 2]]],
    ["2026-10-14T15:05:00+03:00", "C-001", [["RINA-1L-CTN", 5], ["JOGOO-2KG-BALE", 10]]],
    ["2026-10-15T09:20:00+03:00", "C-002", [["KABRAS-2KG-BALE", 6], ["MUMIAS-2KG-BALE", 4]]],
    ["2026-10-15T11:40:00+03:00", "C-003", [["INDOMIE-CHICKEN-CTN", 3], ["SPAGHETTI-400-CTN", 2]]],
    ["2026-10-15T14:10:00+03:00", "C-002", [["AJAB-2KG-BALE", 5], ["EXE-2KG-BALE", 3]]],
    ["2026-10-15T16:25:00+03:00", "C-003", [["OMO-500G-CTN", 4], ["TEA-KETEPA-CTN", 1]]],
    ["2026-10-16T08:15:00+03:00", "C-002", [["BLUEBAND-500-CTN", 3], ["ROYCO-MIX-CTN", 2]]],
    ["2026-10-16T09:50:00+03:00", "C-001", [["RINA-1L-CTN", 5], ["JOGOO-2KG-BALE", 10]]],
    ["2026-10-16T12:05:00+03:00", "C-003", [["COLGATE-100-DOZ", 2], ["VASELINE-250-DOZ", 1]]]
];

"""Past orders are written as DELIVERED directly and never touch stock."""
def seed_history(biz: Business) {
    for h in SEED_ORDERS {
        order = create_manual_order(
            biz, h[1], [OrderItemInput(sku=ln[0], quantity=ln[1]) for ln in h[2]]
        );
        order.status = "DELIVERED";
        order.created_at = h[0];
    }
}

"""Load the demo catalogue once. Does nothing if the business already has products."""
def seed_demo_data(biz: Business) -> int {
    if len(list_products(biz, True)) > 0 { return 0; }
    if biz.name == "My Wholesale" { biz.name = "Karibu Wholesalers"; }
    for r in SEED_PRODUCTS {
        create_product(biz, sku=r[0], name=r[1], brand=r[2], category=r[3],
                       unit=r[4], price_kes=r[5], aliases=r[6]);
        if r[7] > 0 { adjust_inventory(biz, r[0], r[7], "opening stock", "seed"); }
    }
    for c in SEED_CUSTOMERS {
        create_customer(biz, name=c[0], phone=c[1]);
    }
    seed_history(biz);
    return len(SEED_PRODUCTS);
}
