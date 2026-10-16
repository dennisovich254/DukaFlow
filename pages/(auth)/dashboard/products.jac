import from "sonner" { toast }
import from ....api.products { list_catalogue, add_product, adjust_stock }
import from ....api.contracts { ProductView, ProductResult, NewProductInput, AdjustStockInput, CatalogueQuery }
import from ....lib.money { format_kes }
import from ....components.dashboard.Shell { DashboardShell, PageHeader }
import from ....components.ui.button { Button }
import from ....components.ui.input { Input }
import from ....components.ui.field { Field, FieldLabel, FieldGroup }
import from ....components.ui.native_select { NativeSelect, NativeSelectOption }
import from ....components.ui.card { Card, CardContent }
import from ....components.ui.table { Table, TableHeader, TableBody, TableRow, TableHead, TableCell }
import from ....components.ui.dialog {
    Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter
}

glob UNIT_CHOICES: list[str] = ["carton", "bale", "dozen", "bag", "crate", "piece", "bottle", "packet", "kg", "litre"];

"""Products and stock: add products, correct stock levels."""
def:pub ProductsPage() -> JsxPage {
    has products: list[ProductView] = [];
    has loading: bool = True;
    has adding: bool = False;
    has saving: bool = False;
    has sku: str = "";
    has name: str = "";
    has brand: str = "";
    has category: str = "";
    has unit: str = "carton";
    has price: str = "";
    has adjustSku: str = "";
    has change: str = "";
    has reason: str = "";

    async def refresh {
        products = await list_catalogue(CatalogueQuery(include_inactive=False));
        loading = False;
    }

    async can with entry {
        await refresh();
    }

    def open_add(e: MouseEvent) {
        sku = ""; name = ""; brand = ""; category = ""; unit = "carton"; price = "";
        adding = True;
    }

    async def save_product(e: FormEvent) {
        e.preventDefault();
        saving = True;
        result: ProductResult | None = None;
        result = await add_product(NewProductInput(
            sku=sku, name=name, unit=unit, price_kes=float(price), brand=brand, category=category
        ));
        saving = False;
        if result.ok and result.product is not None {
            toast.success(f"Added {result.product.name}");
            adding = False;
            await refresh();
        } elif result.error is not None {
            toast.error(result.error.message);
        }
    }

    async def save_adjustment(e: FormEvent) {
        e.preventDefault();
        saving = True;
        result: ProductResult | None = None;
        result = await adjust_stock(AdjustStockInput(sku=adjustSku, quantity_change=float(change), reason=reason));
        saving = False;
        if result.ok {
            toast.success("Stock updated");
            adjustSku = "";
            await refresh();
        } elif result.error is not None {
            toast.error(result.error.message);
        }
    }

    <DashboardShell>
        <PageHeader title="Products & stock" description="Prices are in whole shillings per selling unit.">
            <Button onClick={open_add}>Add product</Button>
        </PageHeader>
        <Card>
            <CardContent>
                {if loading {
                    <p className="text-sm text-muted-foreground">Loading products…</p>
                } elif len(products) == 0 {
                    <p className="text-sm text-muted-foreground">No products yet. Add your first product.</p>
                } else {
                    <Table>
                        <TableHeader>
                            <TableRow>
                                <TableHead>Product</TableHead>
                                <TableHead>SKU</TableHead>
                                <TableHead>Unit</TableHead>
                                <TableHead className="text-right">Price</TableHead>
                                <TableHead className="text-right">Available</TableHead>
                                <TableHead></TableHead>
                            </TableRow>
                        </TableHeader>
                        <TableBody>
                            {for p in products {
                                <TableRow key={p.sku}>
                                    <TableCell>
                                        <div className="font-medium">{p.name}</div>
                                        <div className="text-xs text-muted-foreground">{p.brand}{" · " if p.brand and p.category else ""}{p.category}</div>
                                    </TableCell>
                                    <TableCell className="font-mono text-xs">{p.sku}</TableCell>
                                    <TableCell>{p.unit}</TableCell>
                                    <TableCell className="text-right tabular-nums">{format_kes(p.price_kes)}</TableCell>
                                    <TableCell className="text-right tabular-nums">{"Out of stock" if p.quantity_available <= 0 else p.quantity_available}</TableCell>
                                    <TableCell className="text-right">
                                        <Button size="sm" variant="outline" onClick={lambda { adjustSku = p.sku; change = ""; reason = ""; }}>Adjust stock</Button>
                                    </TableCell>
                                </TableRow>
                            }}
                        </TableBody>
                    </Table>
                }}
            </CardContent>
        </Card>

        <Dialog open={adding} onOpenChange={lambda (v: bool) { adding = v; }}>
            <DialogContent>
                <DialogHeader>
                    <DialogTitle>Add product</DialogTitle>
                    <DialogDescription>Stock starts at zero; adjust it after adding.</DialogDescription>
                </DialogHeader>
                <form className="flex flex-col gap-6" onSubmit={save_product}>
                    <FieldGroup>
                        <Field>
                            <FieldLabel htmlFor="p-name">Name</FieldLabel>
                            <Input id="p-name" required={True} placeholder="Rina Cooking Oil 1L Carton" value={name}
                                onChange={lambda (e: ChangeEvent) { name = e.target.value; }} />
                        </Field>
                        <Field>
                            <FieldLabel htmlFor="p-sku">SKU</FieldLabel>
                            <Input id="p-sku" required={True} placeholder="RINA-1L-CTN" value={sku}
                                onChange={lambda (e: ChangeEvent) { sku = e.target.value; }} />
                        </Field>
                        <Field>
                            <FieldLabel htmlFor="p-brand">Brand</FieldLabel>
                            <Input id="p-brand" placeholder="Rina" value={brand}
                                onChange={lambda (e: ChangeEvent) { brand = e.target.value; }} />
                        </Field>
                        <Field>
                            <FieldLabel htmlFor="p-category">Category</FieldLabel>
                            <Input id="p-category" placeholder="Cooking oil" value={category}
                                onChange={lambda (e: ChangeEvent) { category = e.target.value; }} />
                        </Field>
                        <Field>
                            <FieldLabel htmlFor="p-unit">Unit</FieldLabel>
                            <NativeSelect id="p-unit" value={unit} onChange={lambda (e: ChangeEvent) { unit = e.target.value; }}>
                                {for u in UNIT_CHOICES { <NativeSelectOption key={u} value={u}>{u}</NativeSelectOption> }}
                            </NativeSelect>
                        </Field>
                        <Field>
                            <FieldLabel htmlFor="p-price">Price (KSh, whole shillings)</FieldLabel>
                            <Input id="p-price" type="number" min="1" step="1" required={True} value={price}
                                onChange={lambda (e: ChangeEvent) { price = e.target.value; }} />
                        </Field>
                    </FieldGroup>
                    <DialogFooter>
                        <Button type="button" variant="outline" onClick={lambda { adding = False; }}>Cancel</Button>
                        <Button type="submit" disabled={saving}>{"Saving…" if saving else "Add product"}</Button>
                    </DialogFooter>
                </form>
            </DialogContent>
        </Dialog>

        <Dialog open={adjustSku != ""} onOpenChange={lambda (v: bool) { if not v { adjustSku = ""; } }}>
            <DialogContent>
                <DialogHeader>
                    <DialogTitle>Adjust stock</DialogTitle>
                    <DialogDescription>{adjustSku}. Use a positive number to add stock and a negative number to remove it.</DialogDescription>
                </DialogHeader>
                <form className="flex flex-col gap-6" onSubmit={save_adjustment}>
                    <FieldGroup>
                        <Field>
                            <FieldLabel htmlFor="a-change">Change</FieldLabel>
                            <Input id="a-change" type="number" step="1" required={True} value={change}
                                onChange={lambda (e: ChangeEvent) { change = e.target.value; }} />
                        </Field>
                        <Field>
                            <FieldLabel htmlFor="a-reason">Reason</FieldLabel>
                            <Input id="a-reason" required={True} placeholder="Opening stock" value={reason}
                                onChange={lambda (e: ChangeEvent) { reason = e.target.value; }} />
                        </Field>
                    </FieldGroup>
                    <DialogFooter>
                        <Button type="button" variant="outline" onClick={lambda { adjustSku = ""; }}>Cancel</Button>
                        <Button type="submit" disabled={saving}>{"Saving…" if saving else "Update stock"}</Button>
                    </DialogFooter>
                </form>
            </DialogContent>
        </Dialog>
    </DashboardShell>
}
