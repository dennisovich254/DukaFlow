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
