import from "sonner" { toast }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { ArrowUp01Icon, Camera01Icon, Tick02Icon, TickDouble02Icon }
import from ...api.chat { send_chat_message, get_conversation, get_chat_image }
import from ...api.contracts { MessageView, ChatResult, ChatInput, ConversationQuery, ImageQuery }
import from ...lib.image { downscale_to_jpeg_base64 }
import from ..ui.dialog { Dialog, DialogContent, DialogHeader, DialogTitle }

glob MAX_PHOTO_SIDE: int = 1600;
glob POLL_MS: int = 3000;

def hhmm(iso: str) -> str {
    return iso[11:16] if len(iso) >= 16 else "";
}

def new_client_id() -> str {
    return "m-" + str(Date.now()) + "-" + str(Math.floor(Math.random() * 100000));
}

"""A photo bubble: fetches the stored image once and shows it as a thumbnail."""
def:pub PhotoBubble(invite: str, mediaRef: str, onOpen: any) -> JsxElement {
    has src: str = "";
    has failed: bool = False;

    async can with (mediaRef) entry {
        if not mediaRef or src { return; }
        res = await get_chat_image(ImageQuery(invite=invite, media_ref=mediaRef));
        if res.ok { src = res.data_url; } else { failed = True; }
    }

    if failed {
        return <p className="text-sm text-[#585c52]">Photo unavailable</p>;
    }
    if not src {
        return <div className="flex h-32 w-44 items-center justify-center rounded-xl bg-[#e4e7dc] text-xs text-[#585c52]">Loading photo…</div>;
    }
    <button type="button" aria-label="Open photo" onClick={lambda { onOpen(src); }} className="block cursor-pointer overflow-hidden rounded-xl">
        <img src={src} alt="Photo sent in chat" className="max-h-56 w-auto max-w-full object-cover" />
    </button>
}

"""The customer's chat, identified only by their invite token: optimistic sends, polling, photo upload."""
def:pub ChatThread(invite: str, businessName: str, customerName: str) -> JsxElement {
    has messages: list[MessageView] = [];
    has pending: list[MessageView] = [];
    has failedIds: list[str] = [];
    has draft: str = "";
    has sending: bool = False;
    has viewing: str = "";
    has endRef: Ref[any] = Ref(None);
    has fileRef: Ref[any] = Ref(None);

    async def refresh {
        res = await get_conversation(ConversationQuery(invite=invite, after_seq=0));
        if res.ok { messages = res.messages; }
    }

    async can with entry {
        await refresh();
    }

    useEffect(lambda {
        timer = setInterval(lambda { refresh(); }, POLL_MS);
        return lambda { clearInterval(timer); };
    }, [invite]);

    can with (messages, pending, sending) entry {
        if endRef.current { endRef.current.scrollIntoView({"behavior": "smooth", "block": "end"}); }
    }

    async def deliver(input: ChatInput, optimistic: MessageView) {
        pending = pending + [optimistic];
        sending = True;
        res = ChatResult(ok=False);
        try {
            res = await send_chat_message(input);
        } except Exception {
            res = ChatResult(ok=False);
        }
        sending = False;
        pending = [p for p in pending if p.client_message_id != input.client_message_id];
        if res.ok {
            messages = res.messages;
            failedIds = [f for f in failedIds if f != input.client_message_id];
        } else {
            failedIds = failedIds + [input.client_message_id];
            message = res.error.message if res.error else "Could not send. Check your connection.";
            toast.error(message);
        }
    }

    async def send_text(e: any) {
        e.preventDefault();
        text = draft.strip();
        if not text or sending { return; }
        draft = "";
        cid = new_client_id();
        await deliver(
            ChatInput(invite=invite, client_message_id=cid, text=text),
            MessageView(seq=-1, sender_type="customer", message_type="text", content=text, created_at="", client_message_id=cid)
        );
    }

    async def send_photo(e: ChangeEvent) {
        files: any = e.target.files;
        if not files or len(files) == 0 { return; }
        file = files[0];
        e.target.value = "";
        cid = new_client_id();
        try {
            b64 = await downscale_to_jpeg_base64(file, MAX_PHOTO_SIDE);
            await deliver(
                ChatInput(invite=invite, client_message_id=cid, text="", photo_base64=b64,
                          photo_mime_type="image/jpeg", photo_name="photo.jpg"),
                MessageView(seq=-1, sender_type="customer", message_type="text", content="Sending photo…",
                            created_at="", client_message_id=cid)
            );
        } except Exception {
            toast.error("That file could not be read as a photo.");
        }
    }

    def open_picker(e: MouseEvent) {
        if fileRef.current { fileRef.current.click(); }
    }

    seen = [m.client_message_id for m in messages if m.client_message_id];
    shown = messages + [p for p in pending if p.client_message_id not in seen];

    <div className="flex h-full flex-col bg-white">
        <header className="flex items-center gap-3 bg-[#0e0f0c] pt-3 pb-3 pl-4 pr-4 text-white">
            <span className="flex size-10 items-center justify-center rounded-full bg-[#a3e635] font-semibold text-[#0e0f0c]">{businessName[:1]}</span>
            <div className="min-w-0">
                <p className="truncate font-medium">{businessName}</p>
                <p className="text-xs text-[#c9cdbf]">online · AI assistant</p>
            </div>
        </header>

        <div role="log" aria-live="polite" className="flex-1 space-y-3 overflow-y-auto bg-[#f4f6ee] pt-4 pb-4 pl-3 pr-3">
            {if len(shown) == 0 {
                <p className="mt-10 text-center text-sm text-[#585c52]">Hi {customerName}! Say hello, or send a photo of your list.</p>
            }}
            {for (i, m) in enumerate(shown) {
                <div key={str(i) + m.client_message_id} className={"flex " + ("justify-end" if m.sender_type == "customer" else "justify-start")}>
                    <div className="max-w-[82%]">
                        <div className={("p-1 " if m.message_type == "image" else "pt-2 pb-2 pl-3 pr-3 ") + "text-[15px] leading-snug " + ("rounded-2xl rounded-br-sm bg-[#0e0f0c] text-white" if m.sender_type == "customer" else "rounded-2xl rounded-bl-sm border border-[#e4e7dc] bg-white text-[#0e0f0c]")}>
                            {if m.message_type == "image" {
                                <PhotoBubble invite={invite} mediaRef={m.media_ref} onOpen={lambda (s: str) { viewing = s; }} />
                            }}
                            {if m.message_type != "image" or m.content {
                                <p className={"break-words " + ("mt-1 pl-2 pr-2 pb-1" if m.message_type == "image" else "")}>{m.content}</p>
                            }}
                        </div>
                        <p className={"mt-1 flex items-center gap-1 text-[11px] text-[#585c52] " + ("justify-end" if m.sender_type == "customer" else "")}>
                            {if m.client_message_id in failedIds {
                                <span className="text-[#c2410c]">Not sent</span>
                            } else {
                                <span>{hhmm(m.created_at)}</span>
                            }}
                            {if m.sender_type == "customer" and m.seq > 0 {
                                <HugeiconsIcon icon={TickDouble02Icon} strokeWidth={2} className="size-3.5 text-[#65a30d]" />
                            } elif m.sender_type == "customer" {
                                <HugeiconsIcon icon={Tick02Icon} strokeWidth={2} className="size-3.5" />
                            }}
                        </p>
                    </div>
                </div>
            }}
            {if sending {
                <div className="flex justify-start" aria-label="Assistant is typing">
                    <div className="flex gap-1 rounded-2xl rounded-bl-sm border border-[#e4e7dc] bg-white pt-3 pb-3 pl-4 pr-4">
                        <span className="size-2 animate-bounce rounded-full bg-[#585c52]" />
                        <span className="size-2 animate-bounce rounded-full bg-[#585c52] [animation-delay:150ms]" />
                        <span className="size-2 animate-bounce rounded-full bg-[#585c52] [animation-delay:300ms]" />
                    </div>
                </div>
            }}
            <div ref={endRef} />
        </div>

        <form onSubmit={send_text} className="flex items-center gap-2 border-t border-[#e4e7dc] bg-white pt-3 pb-3 pl-3 pr-3">
            <input ref={fileRef} type="file" accept="image/*" onChange={send_photo} className="hidden" aria-label="Choose a photo" />
            <button type="button" onClick={open_picker} aria-label="Send a photo"
                className="flex size-11 shrink-0 cursor-pointer items-center justify-center rounded-full bg-[#f3f5ee] hover:bg-[#e7f8c4]">
                <HugeiconsIcon icon={Camera01Icon} strokeWidth={2} className="size-5" />
            </button>
            <input aria-label="Message" placeholder="Type your order…" value={draft}
                onChange={lambda (e: ChangeEvent) { draft = e.target.value; }}
                onKeyDown={lambda (e: any) { if e.key == "Enter" { send_text(e); } }}
                className="h-11 min-w-0 flex-1 rounded-full border border-[#dcdfd3] bg-white pl-4 pr-4 text-[15px] outline-none focus-visible:border-[#65a30d]" />
            <button type="submit" aria-label="Send" disabled={sending or not draft.strip()}
                className="flex size-11 shrink-0 cursor-pointer items-center justify-center rounded-full bg-[#0e0f0c] text-white disabled:opacity-40">
                <HugeiconsIcon icon={ArrowUp01Icon} strokeWidth={2.5} className="size-5" />
            </button>
        </form>

        <Dialog open={viewing != ""} onOpenChange={lambda (v: bool) { if not v { viewing = ""; } }}>
            <DialogContent>
                <DialogHeader><DialogTitle>Photo</DialogTitle></DialogHeader>
                <img src={viewing} alt="Full size photo" className="max-h-[70svh] w-full rounded-xl object-contain" />
            </DialogContent>
        </Dialog>
    </div>
}
