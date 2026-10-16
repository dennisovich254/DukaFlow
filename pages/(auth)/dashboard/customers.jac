import from "sonner" { toast }
import from ....api.customers { list_customer_records, add_customer }
import from ....api.contracts { CustomerView, CustomerResult, NewCustomerInput }
import from ....components.dashboard.Shell { DashboardShell, PageHeader }
import from ....components.ui.button { Button }
import from ....components.ui.input { Input }
import from ....components.ui.field { Field, FieldLabel, FieldGroup }
import from ....components.ui.card { Card, CardContent }
import from ....components.ui.table { Table, TableHeader, TableBody, TableRow, TableHead, TableCell }
import from ....components.ui.dialog {
    Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter
}

"""Retailers who buy from this business."""
def:pub CustomersPage() -> JsxPage {
    has customers: list[CustomerView] = [];
    has loading: bool = True;
    has adding: bool = False;
    has saving: bool = False;
    has name: str = "";
    has phone: str = "";

    async def refresh {
        customers = await list_customer_records();
        loading = False;
    }

    async can with entry {
        await refresh();
    }

    async def save(e: FormEvent) {
        e.preventDefault();
        saving = True;
        result: CustomerResult | None = None;
        result = await add_customer(NewCustomerInput(name=name, phone=phone));
        saving = False;
        if result.ok and result.customer is not None {
            toast.success(f"Added {result.customer.name} ({result.customer.customer_id})");
            adding = False;
            await refresh();
        } elif result.error is not None {
            toast.error(result.error.message);
        }
    }

    <DashboardShell>
        <PageHeader title="Customers" description="Retailers who order from you.">
            <Button onClick={lambda { name = ""; phone = ""; adding = True; }}>Add customer</Button>
        </PageHeader>
        <Card>
            <CardContent>
                {if loading {
                    <p className="text-sm text-muted-foreground">Loading customers…</p>
                } elif len(customers) == 0 {
                    <p className="text-sm text-muted-foreground">No customers yet.</p>
                } else {
                    <Table>
                        <TableHeader>
                            <TableRow>
                                <TableHead>ID</TableHead>
                                <TableHead>Name</TableHead>
                                <TableHead>Phone</TableHead>
                            </TableRow>
                        </TableHeader>
                        <TableBody>
                            {for c in customers {
                                <TableRow key={c.customer_id}>
                                    <TableCell className="font-mono text-xs">{c.customer_id}</TableCell>
                                    <TableCell className="font-medium">{c.name}</TableCell>
                                    <TableCell className="tabular-nums">{c.phone}</TableCell>
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
                    <DialogTitle>Add customer</DialogTitle>
                    <DialogDescription>Kenyan mobile numbers are saved as +254…</DialogDescription>
                </DialogHeader>
                <form className="flex flex-col gap-6" onSubmit={save}>
                    <FieldGroup>
                        <Field>
                            <FieldLabel htmlFor="c-name">Shop name</FieldLabel>
                            <Input id="c-name" required={True} placeholder="Mama Wanjiku Shop" value={name}
                                onChange={lambda (e: ChangeEvent) { name = e.target.value; }} />
                        </Field>
                        <Field>
                            <FieldLabel htmlFor="c-phone">Phone</FieldLabel>
                            <Input id="c-phone" type="tel" required={True} placeholder="0712 345 678" value={phone}
                                onChange={lambda (e: ChangeEvent) { phone = e.target.value; }} />
                        </Field>
                    </FieldGroup>
                    <DialogFooter>
                        <Button type="button" variant="outline" onClick={lambda { adding = False; }}>Cancel</Button>
                        <Button type="submit" disabled={saving}>{"Saving…" if saving else "Add customer"}</Button>
                    </DialogFooter>
                </form>
            </DialogContent>
        </Dialog>
    </DashboardShell>
}
