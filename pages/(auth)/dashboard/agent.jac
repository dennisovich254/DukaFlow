import from ....api.chat { list_conversations, staff_get_conversation }
import from ....api.contracts { ConversationSummaryView, MessageView, StaffConversationQuery }
import from ....components.dashboard.Shell { DashboardShell, PageHeader }
import from ....components.dashboard.PhotoThumb { PhotoThumb }
import from ....components.ui.card { Card, CardContent }

def initials(name: str) -> str {
    parts = [p for p in name.split(" ") if len(p) > 0];
    if len(parts) == 0 { return "?"; }
    return (parts[0][0] + (parts[1][0] if len(parts) > 1 else "")).upper();
}

"""'2026-10-16T14:02:11+03:00' -> '16 Oct, 14:02'."""
def when(iso: str) -> str {
    months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    if len(iso) < 16 { return ""; }
    return str(int(iso[8:10])) + " " + months[int(iso[5:7]) - 1] + ", " + iso[11:16];
}

"""Agent activity: the actual chats between customers and the agent, one conversation per customer.
Read-only; refreshes every few seconds."""
def:pub AgentActivityPage() -> JsxPage {
    has convos: list[ConversationSummaryView] = [];
    has selected: str = "";
    has messages: list[MessageView] = [];
    has loading: bool = True;

    async def load_thread(cid: str) {
        if cid == "" { messages = []; return; }
        res = await staff_get_conversation(StaffConversationQuery(customer_id=cid));
        if res.ok { messages = res.messages; }
    }

    async def refresh {
        convos = await list_conversations();
        loading = False;
        if selected == "" and len(convos) > 0 { selected = convos[0].customer_id; }
        await load_thread(selected);
    }

    async def pick(cid: str) {
        selected = cid;
        messages = [];
        await load_thread(cid);
    }

    async can with entry {
        await refresh();
    }

    useEffect(lambda {
        timer = setInterval(lambda { refresh(); }, 5000);
        return lambda { clearInterval(timer); };
    }, [selected]);

    current = [c for c in convos if c.customer_id == selected];

    <DashboardShell>
        <PageHeader title="Agent activity" description="Your customers' chats with the AI agent, as they happen. Read-only." />
        {if not loading and len(convos) == 0 {
            <Card><CardContent className="pt-6 pb-6"><p className="text-sm text-muted-foreground">No chats yet. Create a chat link on the Customers page and send a message.</p></CardContent></Card>
        } else {
            <div className="grid gap-4 lg:grid-cols-[20rem_1fr]">
                <Card className="overflow-hidden">
                    <ul className="divide-y" aria-label="Conversations">
                        {for c in convos {
                            <li key={c.customer_id}>
                                <button type="button" onClick={lambda (e: any) { pick(c.customer_id); }}
                                    aria-current={"true" if c.customer_id == selected else None}
                                    className={"flex w-full cursor-pointer items-center gap-3 pt-3 pb-3 pl-4 pr-4 text-left outline-none hover:bg-[#f3f5ee] focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-[#0e0f0c] " + ("bg-[#e7f8c4]" if c.customer_id == selected else "")}>
                                    <span className="flex size-10 shrink-0 items-center justify-center rounded-full bg-[#d9f99d] text-sm font-semibold text-[#1a2e05]" aria-hidden="true">{initials(c.customer_name)}</span>
                                    <span className="min-w-0 flex-1">
                                        <span className="flex items-baseline justify-between gap-2">
                                            <span className="truncate text-sm font-medium">{c.customer_name}</span>
                                            <span className="shrink-0 text-[11px] text-muted-foreground">{when(c.last_at)}</span>
                                        </span>
                                        <span className="block truncate text-xs text-muted-foreground">{c.last_message}</span>
                                    </span>
                                </button>
                            </li>
                        }}
                    </ul>
                </Card>
                <Card className="overflow-hidden">
                    <div className="flex items-center gap-3 border-b pt-3 pb-3 pl-4 pr-4">
                        {if len(current) > 0 {
                            <span className="flex size-9 shrink-0 items-center justify-center rounded-full bg-[#d9f99d] text-sm font-semibold text-[#1a2e05]" aria-hidden="true">{initials(current[0].customer_name)}</span>
                            <div>
                                <p className="text-sm font-medium">{current[0].customer_name}</p>
                                <p className="text-xs text-muted-foreground">{current[0].message_count} messages</p>
                            </div>
                        }}
                    </div>
                    <div className="flex max-h-[65vh] min-h-[20rem] flex-col gap-3 overflow-y-auto bg-[#fbfcf8] pt-4 pb-4 pl-4 pr-4" aria-live="polite">
                        {for (i, m) in enumerate(messages) {
                            <div key={str(i) + str(m.seq)} className={"flex " + ("justify-end" if m.sender_type == "customer" else "justify-start")}>
                                <div className="max-w-[80%]">
                                    <p className={"mb-0.5 text-[11px] text-muted-foreground " + ("text-right" if m.sender_type == "customer" else "")}>{current[0].customer_name if m.sender_type == "customer" and len(current) > 0 else "DukaFlow agent"}</p>
                                    <div className={("p-1 " if m.message_type == "image" else "pt-2 pb-2 pl-3 pr-3 ") + "text-[15px] leading-snug " + ("rounded-2xl rounded-br-sm bg-[#0e0f0c] text-white" if m.sender_type == "customer" else "rounded-2xl rounded-bl-sm border border-[#e4e7dc] bg-white text-[#0e0f0c]")}>
                                        {if m.message_type == "image" {
                                            <PhotoThumb customerId={selected} mediaRef={m.media_ref} />
                                        }}
                                        {if m.message_type != "image" or m.content {
                                            <p className={"break-words whitespace-pre-wrap " + ("mt-1 pl-2 pr-2 pb-1" if m.message_type == "image" else "")}>{m.content}</p>
                                        }}
                                    </div>
                                    <p className={"mt-0.5 text-[11px] text-muted-foreground " + ("text-right" if m.sender_type == "customer" else "")}>{when(m.created_at)}</p>
                                </div>
                            </div>
                        }}
                    </div>
                </Card>
            </div>
        }}
    </DashboardShell>
}
