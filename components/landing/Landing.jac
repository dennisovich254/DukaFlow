import from "@jac/runtime" { Link }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    Message01Icon, Camera01Icon, CheckmarkCircle02Icon, PackageIcon, ArrowUpRight01Icon,
    FlashIcon, Asterisk02Icon, Add01Icon, MinusSignIcon, Alert02Icon, File01Icon
}

glob NAV_LINKS: list[list[str]] = [
    ["How it works", "#how"], ["Features", "#features"], ["FAQ", "#faq"]
];

glob STEPS: list[dict[str, any]] = [
    {"n": "01", "icon": Message01Icon, "title": "Retailer sends a list", "body": "A chat message or a photo of a handwritten list, in English, Swahili or Sheng. No app to install, just a personal link."},
    {"n": "02", "icon": FlashIcon, "title": "The agent works it out", "body": "It searches your catalogue, checks live stock, offers an in-stock alternative when you are short, and quotes in whole shillings."},
    {"n": "03", "icon": CheckmarkCircle02Icon, "title": "You approve", "body": "The customer confirms the quote, then it lands in your approval queue. One tap reserves the stock; dispatch deducts it."}
];

glob TOOLS: list[str] = ["search_catalogue", "check_stock", "suggest_alternatives", "recent_orders"];

glob FAQS: list[list[str]] = [
    ["What is DukaFlow, and who is it for?", "An AI order desk for Kenyan wholesalers and distributors. Retailers order by chat or by photo of a handwritten list; DukaFlow turns it into a priced order for you to approve."],
    ["Do I need technical skills to use it?", "No. You add products and customers, load stock, and approve orders from a simple dashboard. Retailers just chat from a personal link, with no account to create."],
    ["Does the AI approve orders by itself?", "Never. The agent reads and quotes. Stock is checked and reserved only when you approve, so a misread can never ship."],
    ["Which languages does the agent understand?", "English, Swahili and Sheng. It answers in the language the customer used and keeps to it for the rest of the conversation."],
    ["How does ordering by photo work?", "The retailer sends a photo of their list. The agent reads each line, matches it to your catalogue, and asks about any line it cannot read before it quotes."],
    ["How are prices and stock handled?", "Whole Kenyan shillings throughout. Prices, totals and stock figures always come from your catalogue, never from the language model, and a quote keeps its price even if you edit the catalogue later."]
];

"""Black pill call to action with an up-right arrow."""
def:pub PillButton(to: str, label: str, large: bool = False) -> JsxElement {
    <Link to={to} className={"inline-flex cursor-pointer items-center gap-2 rounded-full bg-[#0e0f0c] font-medium text-white transition-colors duration-200 hover:bg-[#2b2d26] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#65a30d] " + ("pt-3.5 pb-3.5 pl-7 pr-6 text-base" if large else "pt-2.5 pb-2.5 pl-5 pr-4 text-sm")}>
        {label}
        <HugeiconsIcon icon={ArrowUpRight01Icon} strokeWidth={2} className="size-4" />
    </Link>
}

"""Hand-drawn style curved arrow pointing from a floating card to the phone."""
def:pub Squiggle(flip: bool = False) -> JsxElement {
    <svg aria-hidden="true" viewBox="0 0 120 60" className={"h-10 w-24 text-[#0e0f0c] " + ("-scale-x-100" if flip else "")} fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round">
        <path d="M4 48 C 30 10, 70 6, 108 22" />
        <path d="M96 12 L 109 22 L 95 29" />
    </svg>
}

def:pub Logo() -> JsxElement {
    <span className="flex items-center gap-2 text-lg font-semibold tracking-tight">
        <HugeiconsIcon icon={Asterisk02Icon} strokeWidth={2.5} className="size-7" />
        DukaFlow
    </span>
}

"""A phone showing a sample chat order (illustrative data)."""
def:pub ChatPhone() -> JsxElement {
    <div className="relative mx-auto w-[280px] rounded-[44px] border-[10px] border-[#0e0f0c] bg-[#0e0f0c] shadow-2xl sm:w-[300px]">
        <div className="overflow-hidden rounded-[34px] bg-gradient-to-b from-[#d9f99d] via-[#ecfccb] to-white">
            <div className="flex items-center justify-between pt-4 pb-2 pl-5 pr-5">
                <span className="text-lg font-semibold tracking-tight">Duka chat</span>
                <span className="h-6 w-20 rounded-full bg-[#0e0f0c]" />
            </div>
            <div className="space-y-2 pt-3 pb-5 pl-4 pr-4 text-[13px] leading-snug">
                <div className="ml-auto w-fit max-w-[85%] rounded-2xl rounded-br-md bg-[#0e0f0c] pt-2 pb-2 pl-3 pr-3 text-white">Niletee Rina 1L carton 5 na Jogoo 2kg bale 10</div>
                <div className="w-fit max-w-[90%] rounded-2xl rounded-bl-md bg-white pt-2 pb-2 pl-3 pr-3 shadow-sm">
                    <p className="font-medium">Hii hapa bei yako:</p>
                    <p className="mt-1 text-[#585c52]">5 × Rina 1L · KSh 14,000</p>
                    <p className="text-[#585c52]">10 × Jogoo 2kg · KSh 14,500</p>
                    <p className="mt-1 border-t border-[#e4e7dc] pt-1 font-semibold">Jumla: KSh 28,500</p>
                </div>
                <div className="ml-auto w-fit rounded-2xl rounded-br-md bg-[#0e0f0c] pt-2 pb-2 pl-3 pr-3 text-white">sawa</div>
                <div className="w-fit max-w-[85%] rounded-2xl rounded-bl-md bg-white pt-2 pb-2 pl-3 pr-3 shadow-sm">Sawa! Oda imetumwa kwa muuzaji kwa idhini.</div>
            </div>
            <div className="flex flex-col items-center pb-6">
                <div className="relative flex size-36 items-center justify-center rounded-full border-[14px] border-[#0e0f0c] border-r-[#a3e635]">
                    <div className="text-center"><p className="text-2xl font-medium tracking-tight">28.5K</p><p className="text-[11px] text-[#585c52]">KSh quoted</p></div>
                </div>
            </div>
        </div>
    </div>
}

def:pub FaqItem(question: str, answer: str, open: bool, onToggle: any) -> JsxElement {
    <div className="border-b border-[#e4e7dc]">
        <button type="button" onClick={onToggle} aria-expanded={open}
            className="flex w-full cursor-pointer items-center justify-between gap-4 pt-6 pb-6 text-left focus-visible:outline-2 focus-visible:outline-[#65a30d]">
            <span className="text-lg tracking-tight">{question}</span>
            <span className={"flex size-8 shrink-0 items-center justify-center rounded-full transition-colors duration-200 " + ("bg-[#a3e635]" if open else "bg-[#f3f5ee]")}>
                <HugeiconsIcon icon={MinusSignIcon if open else Add01Icon} strokeWidth={2} className="size-4" />
            </span>
        </button>
        {open and <p className="max-w-2xl pb-6 text-[#585c52]">{answer}</p>}
    </div>
}

def:pub Faq() -> JsxElement {
    has openIndex: int = 0;
    <div className="mx-auto max-w-3xl border-t border-[#e4e7dc]">
        {for (i, f) in enumerate(FAQS) {
            <FaqItem key={str(i)} question={f[0]} answer={f[1]} open={openIndex == i}
                onToggle={lambda { openIndex = -1 if openIndex == i else i; }} />
        }}
    </div>
}

"""Public landing page for signed-out visitors at `/` (spec: docs/ui-spec.md, Landing)."""
def:pub Landing() -> JsxElement {
    <div id="top" className="min-h-svh overflow-x-hidden bg-white text-[#0e0f0c]">
        <header className="mx-auto grid max-w-6xl grid-cols-[1fr_auto] items-center gap-4 pt-6 pb-6 pl-4 pr-4 md:grid-cols-3">
            <div className="flex items-center gap-3">
                <Logo />
                <span className="hidden text-sm text-[#585c52] lg:inline">/ for Kenyan wholesalers</span>
            </div>
            <nav aria-label="Sections" className="hidden items-center justify-center gap-2 text-sm md:flex">
                {for (i, l) in enumerate(NAV_LINKS) {
                    <span key={l[0]} className="flex items-center gap-2">
                        {i > 0 and <span aria-hidden="true" className="text-[#585c52]">·</span>}
                        <a href={l[1]} className="cursor-pointer rounded hover:underline hover:underline-offset-4">{l[0]}</a>
                    </span>
                }}
            </nav>
            <div className="flex items-center justify-end gap-4 text-sm">
                <Link to="/login" className="cursor-pointer hover:underline hover:underline-offset-4">Login</Link>
                <PillButton to="/login" label="Try demo" />
            </div>
        </header>

        <section className="wash-lime relative overflow-hidden pb-0">
            <div className="mx-auto max-w-5xl pt-10 pl-4 pr-4 text-center sm:pt-16">
                <p className="mx-auto inline-flex items-center gap-2 rounded-xl border border-[#e4e7dc] bg-white pt-1.5 pb-1.5 pl-3 pr-1.5 text-sm shadow-sm">
                    <HugeiconsIcon icon={FlashIcon} strokeWidth={2} className="size-4" />
                    Orders by chat and by photo
                    <span className="flex size-6 items-center justify-center rounded-full bg-[#a3e635]"><HugeiconsIcon icon={ArrowUpRight01Icon} strokeWidth={2} className="size-3.5" /></span>
                </p>
                <h1 className="display mt-7 text-5xl font-medium sm:text-7xl">Better Wholesale Ordering, From Chat To Dispatch</h1>
                <p className="mx-auto mt-6 max-w-xl text-lg text-[#3d4037]">Retailers order the way they already do, in English, Swahili or Sheng. An AI agent reads it, checks your stock and quotes. You approve.</p>
                <div className="mt-8 flex justify-center"><PillButton to="/login" label="Start taking orders" large={True} /></div>
            </div>

            <div className="relative mx-auto mt-14 max-w-6xl pl-4 pr-4">
                <div className="grid items-end gap-6 lg:grid-cols-[1fr_auto_1fr]">
                    <div className="hidden flex-col items-end gap-6 pb-24 lg:flex">
                        <div className="flex items-center gap-2">
                            <div className="ink-card flex items-center gap-3 rounded-2xl pt-3 pb-3 pl-3 pr-5 shadow-lg">
                                <span className="flex size-11 items-center justify-center rounded-xl bg-[#d9f99d] text-[#0e0f0c]"><HugeiconsIcon icon={Camera01Icon} strokeWidth={2} className="size-5" /></span>
                                <div><p className="font-medium">Photo order read</p><p className="text-sm text-[#c9cdbf]">4 lines · 1 needs a check</p></div>
                            </div>
                            <Squiggle />
                        </div>
                        <div className="mr-20 w-56 rounded-2xl border border-[#e4e7dc] bg-white p-4 shadow-lg">
                            <p className="text-3xl font-medium tracking-tight">8<span className="text-base text-[#585c52]"> available</span></p>
                            <p className="text-sm">Rina 1L carton (sample)</p>
                            <p className="mt-1 text-xs text-[#585c52]">Short by 2 → alternative offered</p>
                        </div>
                    </div>

                    <div className="translate-y-6"><ChatPhone /></div>

                    <div className="hidden flex-col items-start gap-6 pb-24 lg:flex">
                        <div className="flex items-center gap-2">
                            <Squiggle flip={True} />
                            <div className="ink-card flex items-center gap-3 rounded-2xl pt-3 pb-3 pl-3 pr-5 shadow-lg">
                                <span className="flex size-11 items-center justify-center rounded-xl bg-[#d9f99d] text-[#0e0f0c]"><HugeiconsIcon icon={File01Icon} strokeWidth={2} className="size-5" /></span>
                                <div><p className="font-medium">Order · Pending approval</p><p className="text-sm text-[#c9cdbf]">Mama Wanjiku Shop · KSh 28,500</p></div>
                            </div>
                        </div>
                        <div className="ml-16 w-64 rounded-2xl border border-[#e4e7dc] bg-white/90 p-4 shadow-lg">
                            <p className="text-xs text-[#585c52]">Orders this week (sample)</p>
                            <p className="mt-1 text-2xl font-medium tracking-tight">KSh 412,600</p>
                            <div className="mt-3 flex items-end gap-1.5" aria-hidden="true">
                                {for h in [6, 9, 5, 11, 8, 12, 4] {
                                    <span key={str(h)} className={"w-6 rounded-full " + ("bg-[#0e0f0c]" if h == 12 else "bg-[#a3e635]")} style={{"height": f"{h * 4}px"}} />
                                }}
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </section>

        <section id="how" className="mx-auto max-w-6xl pt-28 pb-20 pl-4 pr-4">
            <div className="flex flex-wrap items-end justify-between gap-6">
                <h2 className="display max-w-xl text-4xl font-medium sm:text-5xl">From a message to a dispatched order in three steps</h2>
                <p className="max-w-sm text-[#585c52]">The AI does the reading and the looking up. You keep the final say on every order.</p>
            </div>
            <div className="mt-12 grid gap-4 md:grid-cols-3">
                {for s in STEPS {
                    <div key={s["n"]} className="rounded-3xl border border-[#e4e7dc] bg-white p-7">
                        <div className="flex items-center justify-between">
                            <span className="flex size-12 items-center justify-center rounded-2xl bg-[#d9f99d]"><HugeiconsIcon icon={s["icon"]} strokeWidth={2} className="size-5" /></span>
                            <span className="text-sm text-[#585c52]">{s["n"]}</span>
                        </div>
                        <h3 className="mt-8 text-xl font-medium tracking-tight">{s["title"]}</h3>
                        <p className="mt-2 text-[#585c52]">{s["body"]}</p>
                    </div>
                }}
            </div>
        </section>

        <section id="features" className="mx-auto max-w-6xl pb-24 pl-4 pr-4">
            <div className="grid gap-4 lg:grid-cols-[1.3fr_1fr]">
                <div className="ink-card flex flex-col justify-between rounded-3xl p-8 sm:p-10">
                    <div>
                        <p className="text-sm text-[#c9cdbf]">An agent, not a form</p>
                        <h3 className="display mt-3 text-3xl font-medium sm:text-4xl">It looks things up before it answers</h3>
                        <p className="mt-4 max-w-md text-[#c9cdbf]">For every message the agent chooses its own steps, and you can see them in your dashboard. Prices, totals and stock always come from your catalogue, never from the model.</p>
                        <div className="mt-6 flex flex-wrap gap-2">
                            {for t in TOOLS {
                                <span key={t} className="rounded-full bg-[#d9f99d] pt-1 pb-1 pl-3 pr-3 font-mono text-xs text-[#1a2e05]">{t}</span>
                            }}
                        </div>
                    </div>
                    <div className="mt-10 rounded-2xl bg-[#f5f7ef] p-4 text-[#0e0f0c]">
                        <p className="flex items-center gap-2 font-medium"><HugeiconsIcon icon={Alert02Icon} strokeWidth={2} className="size-4 text-[#c2410c]" />Rina 1L: only 8 available</p>
                        <p className="mt-1 text-sm text-[#585c52]">Added 2 × Fresh Fri 1L for the rest. The customer confirms before anything is reserved.</p>
                    </div>
                </div>
                <div className="grid gap-4">
                    <div className="rounded-3xl bg-[#d9f99d] p-8">
                        <HugeiconsIcon icon={Camera01Icon} strokeWidth={2} className="size-6" />
                        <h3 className="mt-6 text-2xl font-medium tracking-tight">Reads handwriting</h3>
                        <p className="mt-2 text-[#3d4037]">An unclear "sukari 2" becomes a question, not a guess: which sugar, which pack?</p>
                    </div>
                    <div className="rounded-3xl border border-[#e4e7dc] p-8">
                        <HugeiconsIcon icon={PackageIcon} strokeWidth={2} className="size-6" />
                        <h3 className="mt-6 text-2xl font-medium tracking-tight">You approve, then stock moves</h3>
                        <p className="mt-2 text-[#585c52]">Stock is reserved only when you say yes, so two orders can never claim the last cartons.</p>
                    </div>
                </div>
            </div>
        </section>

        <section id="faq" className="mx-auto max-w-6xl pb-24 pl-4 pr-4">
            <h2 className="display mb-10 text-center text-4xl font-medium sm:text-5xl">Questions, answered</h2>
            <Faq />
        </section>

        <section className="wash-lime pt-20 pb-32 text-center">
            <div className="mx-auto max-w-3xl pl-4 pr-4">
                <h2 className="display text-4xl font-medium sm:text-6xl">Stop retyping orders. Start approving them.</h2>
                <div className="mt-8 flex justify-center"><PillButton to="/login" label="Open your dashboard" large={True} /></div>
            </div>
        </section>

        <footer className="mx-auto flex max-w-6xl flex-wrap items-center justify-between gap-4 pt-8 pb-8 pl-4 pr-4 text-sm text-[#585c52]">
            <Logo />
            <nav aria-label="Footer" className="flex gap-5">
                {for l in NAV_LINKS { <a key={l[0]} href={l[1]} className="cursor-pointer hover:text-[#0e0f0c]">{l[0]}</a> }}
            </nav>
            <p>© 2026 DukaFlow AI · Hackathon prototype built with Jac</p>
        </footer>
    </div>
}
