import from "@jac/runtime" { Link, useLocation, useNavigate, jacLogout }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    DashboardSquare01Icon, File01Icon, UserIcon, Folder01Icon, Logout01Icon, Asterisk02Icon
}
import from ..ui.sidebar {
    SidebarProvider, Sidebar, SidebarHeader, SidebarContent, SidebarFooter, SidebarGroup,
    SidebarGroupLabel, SidebarMenu, SidebarMenuItem, SidebarMenuButton, SidebarInset, SidebarTrigger
}
import from ..ui.separator { Separator }

glob NAV_ITEMS: list[dict[str, any]] = [
    {"to": "/dashboard", "label": "Overview", "icon": DashboardSquare01Icon},
    {"to": "/dashboard/orders", "label": "Orders", "icon": File01Icon},
    {"to": "/dashboard/customers", "label": "Customers", "icon": UserIcon},
    {"to": "/dashboard/products", "label": "Products & stock", "icon": Folder01Icon}
];

# Styled like SidebarMenuButton. The installed SidebarMenuButton forwards its
# asChild/isActive props onto the DOM, so nav links use a plain Link instead.
glob NAV_LINK_CLASS: str = "flex w-full cursor-pointer items-center gap-2 rounded-md pt-2 pb-2 pl-2 pr-2 text-sm outline-none ring-sidebar-ring transition-colors hover:bg-sidebar-accent hover:text-sidebar-accent-foreground focus-visible:ring-2 data-[active=true]:bg-sidebar-accent data-[active=true]:font-semibold data-[active=true]:text-sidebar-accent-foreground";

"""Wholesaler app shell: sidebar navigation plus a top bar. Every /dashboard page wraps
itself in this (Jac only applies a root layout, not nested ones). Never used by /chat."""
def:pub DashboardShell(children: any = None) -> JsxElement {
    location = useLocation();
    nav = useNavigate();

    def sign_out(e: MouseEvent) {
        jacLogout();
        nav("/login", {"replace": True});
    }

    <SidebarProvider>
        <Sidebar collapsible="offcanvas">
            <SidebarHeader>
                <div className="flex items-center gap-2 pt-2 pb-2 pl-2 pr-2">
                    <HugeiconsIcon icon={Asterisk02Icon} strokeWidth={2.5} className="size-7" />
                    <div className="flex flex-col leading-tight">
                        <span className="text-base font-medium tracking-tight">DukaFlow</span>
                        <span className="text-xs text-muted-foreground">Wholesale dashboard</span>
                    </div>
                </div>
            </SidebarHeader>
            <SidebarContent>
                <SidebarGroup>
                    <SidebarGroupLabel>Business</SidebarGroupLabel>
                    <SidebarMenu>
                        {for item in NAV_ITEMS {
                            <SidebarMenuItem key={item["to"]}>
                                <Link to={item["to"]} className={NAV_LINK_CLASS}
                                    data-active={location.pathname == item["to"]}
                                    aria-current={"page" if location.pathname == item["to"] else None}>
                                    <HugeiconsIcon icon={item["icon"]} strokeWidth={2} className="size-4" />
                                    <span>{item["label"]}</span>
                                </Link>
                            </SidebarMenuItem>
                        }}
                    </SidebarMenu>
                </SidebarGroup>
            </SidebarContent>
            <SidebarFooter>
                <SidebarMenu>
                    <SidebarMenuItem>
                        <SidebarMenuButton onClick={sign_out}>
                            <HugeiconsIcon icon={Logout01Icon} strokeWidth={2} />
                            <span>Sign out</span>
                        </SidebarMenuButton>
                    </SidebarMenuItem>
                </SidebarMenu>
            </SidebarFooter>
        </Sidebar>
        <SidebarInset>
            <header className="flex h-14 items-center gap-2 border-b bg-white pl-4 pr-4">
                <SidebarTrigger />
                <Separator orientation="vertical" className="mr-2 h-4" />
                <span className="text-sm text-muted-foreground">DukaFlow · Wholesale dashboard</span>
            </header>
            <main className="flex flex-1 flex-col gap-6 bg-[#fbfcf8] pt-8 pb-8 pl-6 pr-6 lg:pl-10 lg:pr-10">{children}</main>
        </SidebarInset>
    </SidebarProvider>
}

"""Page title row used at the top of every dashboard page."""
def:pub PageHeader(title: str, description: str = "", children: any = None) -> JsxElement {
    <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
            <h1 className="display text-3xl font-medium sm:text-4xl">{title}</h1>
            {description and <p className="text-sm text-muted-foreground">{description}</p>}
        </div>
        <div className="flex gap-2">{children}</div>
    </div>
}
