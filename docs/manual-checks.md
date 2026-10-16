# Manual checks

## G1 / P1.8: wholesaler basics and persistence

1. `jac run --dev main.jac`, open `http://localhost:8000/`, wait for the app to compile on first load.
2. **Create an account** with any email and password: you land on `/dashboard`.
3. **Products & stock → Add product**: `Rina Cooking Oil 1L Carton`, SKU `RINA-1L-CTN`, unit `carton`, price `2800`. The table shows **KSh 2,800**. A fractional price is refused.
4. **Adjust stock** on it: change `20`, reason `Opening stock`: Available shows `20`. Try `-25`: refused with an "on hand" message.
5. **Customers → Add customer**: `Mama Wanjiku Shop`, `0712 345 678`: the table shows `C-001` and `+254712345678`.
6. **Orders → New manual order**: customer Mama Wanjiku, 5 × Rina: `ORD-1001`, `KSh 14,000`, `Draft`, `Manual`.
7. **Persistence:** stop the server (Ctrl+C), start it again, sign in: everything from steps 3–6 is still there.
8. **Isolation:** sign out and create a second account: its catalogue, customers and orders are empty.

## G3: Shop chat (customer and wholesaler are separate; invite links)

1. Sign in as the wholesaler on the laptop and **Load demo data** (Overview).
2. **Customers → Chat link** on *Mama Wanjiku Shop*. The link is copied and shown once. For a phone, replace `localhost` with the laptop's Wi-Fi IP (e.g. `http://192.168.x.x:8000/chat?invite=…`); on one laptop use **Open as customer**.
3. On the phone open the link. **Expected:** the chat opens straight away with no sign-in, header "Karibu Wholesalers · online · AI assistant".
4. Type `Niletee Rina 5 carton na Jogoo 10` and send. The bubble appears at once, then gets double ticks, then the reply *"Karibu DukaFlow! Tuambie bidhaa unazohitaji."* (the placeholder until P4).
5. Tap the camera button and photograph a handwritten list: the thumbnail appears, then *"Tumepokea picha yako. Tunaishughulikia."*. Tap the photo to open it full size.
6. **Separation:** `/chat` with no `?invite=` (and after clearing site data) shows "Ask your wholesaler for your chat link"; nothing on the chat page links to the dashboard; opening `/dashboard` on the phone asks for a wholesaler login.
7. **Revoke links** for that customer: reopening the old link (after clearing site data) shows the "Ask your wholesaler" screen and nothing is stored.
8. Nothing scrolls sideways at 360 px.

## G4: the agent in the Shop chat (phone, live model)

1. Wholesaler: **Load demo data**, then **Customers → Chat link** for Mama Wanjiku Shop; open it on the phone.
2. Send `Niletee Rina 1L carton 10 na Jogoo 2kg bale 5`. Expect a quotation that says only 8 Rina are available and adds 2 Fresh Fri 1L for the rest, **total KSh 35,550**, and asks you to confirm. No order exists yet.
3. Reply `sawa`. Expect "Oda ORD-… imetumwa". In the dashboard **Orders**, one `Pending approval` order from the Shop chat appears; sending `sawa` again creates no second order.
4. Send `nipe kama kawaida`: a quotation of Mama Wanjiku's usual order (5 Rina + 10 Jogoo, KSh 28,500).
5. Send `kuku na samaki`: the agent says it does not stock them (no quotation).
6. Photograph a handwritten list with one unreadable line: the agent quotes or lists the lines it read and asks about the unclear line before quoting.
7. Approve the order from the dashboard (Approve): stock reserves as in P2.
8. With `AI_MODE=mock` (no key) the Overview shows the "Mock AI" badge and steps 2–4 still work.


## G5: order review and agent activity

1. Place a chat order (see G4) with a shortage, e.g. `Niletee Rina 1L carton 10 na Jogoo 2kg bale 5`, then confirm with `sawa`.
2. **Agent activity** (sidebar): both runs appear within about 5 seconds, the first as QUOTED with the tools it called, the second as ORDER_PLACED.
3. **Orders → Review** on the new order: the customer's messages (and photos, if you sent one) are on the left; on the right the lines, the amber shortage note ("only 8 available; added 2 × Fresh Fri…"), and the agent's steps.
4. Click **Approve** inside the dialog: the status changes and the customer's chat receives the approval message.
5. Review a hand-entered order: it says "Entered by hand: no chat messages."
