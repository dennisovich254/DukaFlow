import from ....api.chat { get_chat_session }
import from ....api.contracts { ChatSessionQuery }
import from ....components.chat.ChatThread { ChatThread }

glob STORAGE_KEY: str = "dukaflow.chat.invite";

"""The invite token from the link, else the one remembered from an earlier visit."""
def read_invite() -> str {
    try {
        ParamsCls: any = globalThis["URLSearchParams"];
        params: any = new(ParamsCls, window.location.search);
        fromLink: str = params.get("invite") or "";
        if fromLink {
            localStorage.setItem(STORAGE_KEY, fromLink);
            return fromLink;
        }
        stored: str = localStorage.getItem(STORAGE_KEY) or "";
        return stored;
    } except Exception {
        return "";
    }
}

def forget_invite() {
    try {
        localStorage.removeItem(STORAGE_KEY);
    } except Exception {
        return;
    }
}

"""DukaFlow Chat, the retailer's screen. No sign-in: the personal link is the credential.
Its own layout; nothing here links to the dashboard."""
def:pub ChatPage() -> JsxPage {
    has status: str = "loading";
    has invite: str = "";
    has businessName: str = "";
    has customerName: str = "";

    async can with entry {
        token = read_invite();
        if not token {
            status = "invalid";
            return;
        }
        res = await get_chat_session(ChatSessionQuery(invite=token));
        if res.ok {
            invite = token;
            businessName = res.business_name;
            customerName = res.customer_name;
            status = "ready";
        } else {
            forget_invite();
            status = "invalid";
        }
    }

    <div className="min-h-svh bg-white sm:flex sm:items-center sm:justify-center sm:bg-[#f1fbe0]">
        <div className="flex h-svh w-full flex-col overflow-hidden bg-white sm:h-[820px] sm:max-h-[94svh] sm:w-[400px] sm:rounded-[40px] sm:border-[10px] sm:border-[#0e0f0c] sm:shadow-2xl">
            {if status == "ready" {
                <ChatThread key={invite} invite={invite} businessName={businessName} customerName={customerName} />
            } elif status == "invalid" {
                <div className="flex flex-1 flex-col items-center justify-center bg-gradient-to-b from-[#d9f99d] via-[#f1fbe0] to-white pl-8 pr-8 text-center">
                    <h1 className="text-3xl font-medium tracking-tight" style={{"letterSpacing": "-0.03em"}}>Ask your wholesaler for your chat link</h1>
                    <p className="mt-3 text-[#3d4037]">Your wholesaler can send you a personal link to order here.</p>
                </div>
            } else {
                <div className="flex flex-1 items-center justify-center"><p className="text-sm text-[#585c52]">Opening your chat…</p></div>
            }}
        </div>
    </div>
}
