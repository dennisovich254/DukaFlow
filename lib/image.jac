"""Browser-side photo preparation for the Shop chat.

Phone photos are 3-8 MB; shrinking to <= 1600 px JPEG before upload cuts upload time and
model cost. Browser-only code; browser classes are reached through globalThis so
`jac check` (which has no browser type stubs) stays clean.
"""

def read_as_data_url(file: any) -> any {
    return new(Promise, lambda (resolve: any, reject: any) {
        ReaderCls: any = globalThis["FileReader"];
        reader: any = new(ReaderCls);
        reader.onload = lambda { resolve.call(None, reader.result); };
        reader.onerror = lambda { reject.call(None, "Could not read the photo"); };
        reader.readAsDataURL(file);
    });
}

def load_image(src: str) -> any {
    return new(Promise, lambda (resolve: any, reject: any) {
        ImageCls: any = globalThis["Image"];
        img: any = new(ImageCls);
        img.onload = lambda { resolve.call(None, img); };
        img.onerror = lambda { reject.call(None, "That file is not a readable image"); };
        img.src = src;
    });
}

"""Return the base64 payload (no data: prefix) of the photo scaled to `max_side` px, as JPEG."""
async def:pub downscale_to_jpeg_base64(file: any, max_side: int) -> str {
    src: str = await read_as_data_url(file);
    img: any = await load_image(src);
    longest = Math.max(img.width, img.height);
    scale = Math.min(1, max_side / longest);
    canvas: any = document.createElement("canvas");
    canvas.width = Math.round(img.width * scale);
    canvas.height = Math.round(img.height * scale);
    ctx: any = canvas.getContext("2d");
    ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
    out: str = canvas.toDataURL("image/jpeg", 0.85);
    return out.split(",")[1];
}
