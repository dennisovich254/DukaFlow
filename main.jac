"""DukaFlow AI entry point: server endpoints are imported here; the client is
file-routed from pages/."""

import from api.products { list_catalogue, add_product, edit_product, adjust_stock }
import from api.customers { list_customer_records, add_customer }
import from api.orders { list_order_records, get_order_record, create_order }

import from .components.ui.sonner { Toaster }
import ".styles.global.css";

def:pub app(children: any) -> JsxElement {
    <>
        {children}
        <Toaster richColors={True} theme="light" position="top-right" />
    </>
}
