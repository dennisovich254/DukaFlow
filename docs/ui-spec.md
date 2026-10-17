# DukaFlow UI specification

## Theme (applies to every surface)

**Direction (v2, 2026-10-15):** light, editorial fintech, after a Dribbble "Better Business Banking" shot the team supplied. Replaces the v1 dark glassmorphism theme, which read as generic and AI-generated. Style family per the ui-ux-pro-max skill: *Minimalism & Swiss*: high contrast, white space, no purple/pink "AI" gradients, no glass blur.

**Tokens** (`styles/global.css` `:root`, shadcn variable names)

| Role | Value | Use |
|---|---|---|
| Ink | `#0e0f0c` | Text, primary buttons, dark accents |
| Paper | `#ffffff` / dashboard canvas `#fbfcf8` | Backgrounds |
| Olive-black card | `#2b2d26` (`.ink-card`, text `#f5f7ef`, secondary `#c9cdbf`) | One highlighted card per view |
| Lime | `#a3e635` strong, `#d9f99d` soft, `#e7f8c4` nav active | **Backgrounds only, always with ink text** (lime text on white fails 4.5:1) |
| Muted text | `#585c52` | Secondary copy (≥ 4.5:1 on white) |
| Border | `#e4e7dc` | Hairlines, card borders |
| Focus ring | `#65a30d` | `focus-visible` outline |
| Danger | `#c2410c` | Errors |

- Radius 1rem (cards 1.5rem/`rounded-3xl`); **all buttons are pills** (`rounded-full`, set in `components/ui/button.jac`), with `cursor-pointer`.
- Typography: Inter Variable only. Display headings use `.display` (letter-spacing −0.035em, line-height 1.04), weight 500. No serif.
- Primary action: black pill with an up-right arrow (`PillButton`). Secondary: plain text link (Login) or outline pill.
- `.wash-lime`: soft lime radial glow rising from the bottom of the hero, the closing CTA band and the login page.
- Status badges (`StatusBadge`): text plus colour pills: Pending approval amber, Approved/Packed lime, Dispatched ink, Delivered olive/lime, Rejected orange, Cancelled grey with strikethrough.
- Motion: 200 ms colour transitions only; `prefers-reduced-motion` disables animation globally.
- Toaster forced to `theme="light"`.

## Surfaces

| Surface | Route | Audience | Notes |
|---|---|---|---|
| Landing | `/` (signed out) | Prospects, judges | Below |
| Sign in / create account | `/login` | Wholesaler | White card (`rounded-3xl`, shadow) on `.wash-lime`; asterisk logo top-left links home; black pill submit |
| Dashboard | `/dashboard/*` | Wholesaler | Light shell below |
| Shop chat | `/chat` (P3) | Retailer | Separate layout, unbranded, no links to the dashboard. Bubble styling as in the landing phone mock: retailer bubbles ink with white text (right), agent bubbles white (left), quote card inside a white bubble |

Signed-in visitors to `/` are redirected to `/dashboard`.

## Landing page (P7.1)

Implementation: `components/landing/Landing.jac`, mounted by `pages/index.jac`.

1. **Header**: asterisk logo + "DukaFlow" + "/ for Kenyan wholesalers" (≥ lg); centred dot-separated links (How it works · Features · FAQ, ≥ md); right "Login" text link and "Try demo ↗" black pill.
2. **Hero** (on `.wash-lime`): pill badge "⚡ Orders by chat and by photo" with lime arrow chip; H1 "Better Wholesale Ordering, From Chat To Dispatch" (display, 48/72 px); subcopy mentioning English, Swahili and Sheng; "Start taking orders ↗" large pill.
3. **Hero visual**: centred phone mock showing a Duka chat (retailer Swahili message, quote bubble ORD-1042 KSh 28,500, Confirm, "Sent for approval") and a ring showing "28.5K KSh quoted". Floating cards (≥ lg only): left, olive card "Photo order read · 4 lines · 1 needs a check" and white card "35 / 40 Rina 1L available"; right, olive card "ORD-1042 · Pending approval" and white card "Orders this week (sample)" with lime pill bars. Hand-drawn SVG arrows (`Squiggle`) point at the phone.
4. **How it works** (`#how`): headline + side note; three white cards with lime icon chips and step numbers 01–03.
5. **Features** (`#features`): large olive card "It looks things up before it answers" (the agent's four tools as lime chips and a real-looking shortage note); lime card "Reads handwriting"; outline card "You approve, then stock moves".
6. **FAQ** (`#faq`): six questions (including languages and how prices and stock are handled), hairline accordion, first item open, plus/minus in a round chip (lime when open), `aria-expanded`.
7. **Closing CTA** on `.wash-lime`: "Stop retyping orders. Start approving them." + pill.
8. **Footer**: logo, links, "© 2026 DukaFlow AI · Hackathon prototype built with Jac".

**Rules**: no horizontal scroll at 360 px (verified at 390); floating cards hidden below `lg`; all interactive elements keyboard-focusable with visible lime-dark focus; status never by colour alone; money in whole KSh; any illustrative number is either taken from the demo seed or labelled "(sample)"; no fabricated testimonials, logos, funding claims or compliance badges.

## Dashboard (P1–P2)

- Shell: `components/dashboard/Shell.jac`: off-white sidebar (`#f8f9f4`) with asterisk logo and "DukaFlow / Wholesale dashboard"; active nav item soft lime with semibold text; white top bar with hairline; canvas `#fbfcf8`; page titles `.display` 30/36 px. Sidebar: Overview, Orders, Customers, Products & stock, Agent activity; Sign out.
- Overview: an ink "Needs your approval" hero (count plus the three oldest waiting orders, Review orders) or a lime "All caught up" strip.
- Overview: four KPI tiles (sales and orders over 7 days with week-over-week change and average, customers, low stock ≤ 5); "Sales this week" bar chart (focusable columns with a readout); orders-by-status and order-channel donuts; top products (30 days); "Running low" list; recent orders as a list (avatar, customer, order id, date, channel, items, amount, status). Charts are plain HTML/CSS, no library. "Load demo data" when the catalogue is empty.
- Orders: a summary line (needing approval, value in progress, total), status tabs with counts (All, Needs approval, In progress, Delivered, Closed; "Needs approval" is preselected when something is waiting) and a search box (customer or order ID). Each order is one row: avatar, customer, channel icon, order ID, date ("Today, 14:02"), first two items, amount, status badge and one primary action (Approve, Dispatch…) or View. Reject and Cancel live in the Review dialog (click a row). No table, so nothing overflows on narrow screens.
- Orders table: per-status action buttons (Draft: Submit/Cancel · Pending approval: Approve/Reject · Approved/Packed: Dispatch/Cancel · Dispatched: Mark delivered). Primary variant for Submit/Approve/Dispatch.
- Status badge: text label plus colour (`StatusBadge`).
- Money displays as `KSh 14,000`.

## Shop chat `/chat` (P3.4)

Route `/chat?invite=<token>` (public route group; **no login**, the invite link identifies the customer; there is no picker and no login). **Own layout**: no `DashboardShell`, no link to any `/dashboard` page, unbranded ("DukaFlow Chat"; no WhatsApp name or logo).

- **Frame**: full-screen on phones; on `sm`+ a 400 × 820 px phone frame (10 px ink border, 40 px radius) centred on a soft lime canvas (`#f1fbe0`).
- **Screen 1, entry** (replaces the v1 customer picker): with a valid link the thread opens directly. Without a token, or with an invalid, expired or revoked one, a centred message on the lime wash: title "Ask your wholesaler for your chat link", subcopy "Your wholesaler can send you a personal link to order here." (text only; no sign-in form, no links to any other page).
- **Screen 2, thread**
  - Header (ink background, white text): no back arrow (there is nothing to go back to), lime avatar with the wholesaler's initial, wholesaler name, status line "online · AI assistant".
  - Body (`#f4f6ee`): customer bubbles right, ink with white text, `rounded-br-sm`; agent bubbles left, white with hairline border, `rounded-bl-sm`; max width 82 %; timestamp (HH:MM) under each bubble; customer messages show ✓✓ once the server has stored them and ✓ while pending; failed sends show "Not sent. Tap to retry" in the destructive colour.
  - Image messages: thumbnail (max 220 px wide, rounded) with caption below; "Loading photo…" placeholder; tap opens the full image in a dialog.
  - Typing indicator: three bouncing dots in an agent bubble while a reply is awaited (respects reduced motion).
  - Composer (sticky bottom, white): photo button (camera icon, `aria-label="Send a photo"`, opens the camera or gallery via `accept="image/*"`), text input (placeholder "Type your order…"), round ink send button with an arrow. All targets ≥ 44 px; Enter sends (explicit key handler).
- **Behaviour**: optimistic display of sent messages; poll every 3 s; photos downscaled in the browser to ≤ 1600 px JPEG (quality 0.85) before upload; each message carries a client-generated id so retries never duplicate; the view auto-scrolls to the newest message.
- **Quotation cards and quick-reply chips** (white card with line items and a Confirm / Change button pair) arrive with P4.
- **Accessibility**: message list `role="log"` with `aria-live="polite"`; composer inputs labelled; works at 360 px with no horizontal scroll.

## Customers page: chat links (P3.5)

Each customer row gets two small pill buttons: **Chat link** (creates a fresh invite, copies the full `/chat?invite=…` URL to the clipboard, shows it once in a dialog with a copy button and a note "Shown once. Creating a new link does not cancel older ones; use Revoke to cancel them.") and **Open as customer** (opens the link in a new tab). A **Revoke links** action cancels every invite for that customer.

## Dashboard conversations (P3.5)

`/dashboard/conversations`: two columns on desktop (customer list left with last message and time, thread right), single column on mobile. Read-only; photo thumbnails open full size in a dialog. Shares no components with `/chat`; uses the dashboard shell and theme.

## Planned (specify here before building)

- P5 Order review: detail drawer with original photo beside parsed lines; agent activity panel.


## Order review and agent activity (P5)

- **Orders table**: each row has a **Review** ghost button before its status actions.
- **Review dialog** (`max-w-3xl`, scrolls): two columns on `md`+, stacked on phones. Left, "What the customer sent": the last 8 chat messages up to the confirmation (customer bubbles ink, agent bubbles muted) with photos as thumbnails that enlarge on tap. Right: "Order lines" (quantity × product, line total, bold total), an amber note per shortage or substitution, "How the agent read it" (one card per run: input type, outcome, duration, then each tool step in small monospace), and the status badge with the same action buttons as the table.
- **Hand-entered orders** show "Entered by hand: no chat messages."
- **Agent activity page** (`/dashboard/agent`): a read-only inbox of the real chats. Left: one row per customer (avatar, name, last message, time); right: the selected customer's conversation as bubbles (customer right in ink, agent left in white, photos as thumbnails). Refreshes every 5 seconds; the first customer is selected by default.
