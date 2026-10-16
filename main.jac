"""DukaFlow AI entry point: server endpoints are imported here; the client is
file-routed from pages/."""

import from api.products { list_catalogue, add_product, edit_product, adjust_stock }

import from .components.ui.sonner { Toaster }
import ".styles.global.css";

def:pub app(children: any) -> JsxElement {
    <>
        {children}
        <Toaster richColors={True} theme="light" position="top-right" />
    </>
}
