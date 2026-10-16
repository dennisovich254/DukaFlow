import from ...api.chat { staff_get_chat_image }
import from ...api.contracts { StaffImageQuery }

"""Wholesaler-side photo thumbnail for a customer's chat photo (opens full size on click)."""
def:pub PhotoThumb(customerId: str, mediaRef: str) -> JsxElement {
    has src: str = "";
    has failed: bool = False;
    has big: bool = False;

    async can with (mediaRef) entry {
        if not mediaRef or src { return; }
        res = await staff_get_chat_image(StaffImageQuery(customer_id=customerId, media_ref=mediaRef));
        if res.ok { src = res.data_url; } else { failed = True; }
    }

    if failed { return <p className="text-sm text-muted-foreground">Photo unavailable</p>; }
    if not src { return <div className="flex h-24 w-32 items-center justify-center rounded-lg bg-muted text-xs text-muted-foreground">Loading photo…</div>; }
    <div>
        <button type="button" aria-label="Open photo full size" onClick={lambda { big = not big; }} className="block cursor-pointer overflow-hidden rounded-lg border">
            <img src={src} alt="Photo from the customer" className={("max-h-[70vh] " if big else "max-h-48 ") + "w-auto max-w-full object-contain"} />
        </button>
        <p className="mt-1 text-xs text-muted-foreground">{"Tap to shrink" if big else "Tap to enlarge"}</p>
    </div>
}
