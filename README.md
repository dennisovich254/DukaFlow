# DukaFlow AI

An AI order desk for Kenyan wholesalers. Retailers order by chat, in English, Swahili or Sheng, or by sending a photo of a handwritten list. An agent reads the order, checks stock, quotes in KSh and asks the customer to confirm. The wholesaler then approves, packs and dispatches from a dashboard.

Built in **Jac 0.37** for JacHacks Kenya 2026 (backend, agent, tests and the React front end are all Jac).

> Demo video, hosted app and pitch deck: linked from the Devpost submission.

## What it does

| Retailer (chat link, no sign-in) | Wholesaler (dashboard, signed in) |
|---|---|
| Types "Niletee Rina 1L carton 10 na Jogoo 2kg bale 5" or photographs a list | **Overview**: orders waiting for approval, 7-day sales, charts, low stock |
| Gets a quotation with real prices; if stock is short, an alternative to confirm | **Orders**: status tabs, search, one-click next step, full review with the customer's messages and the agent's reading |
| Says "sawa" to confirm; asks "oda yangu iko wapi?" any time for status | **Customers**: personal chat links (revocable) |
| Is told when the order is approved or dispatched | **Products & stock**: catalogue, stock adjustments with an audit trail |
| | **Agent activity**: the live chats between customers and the agent |

The agent never creates an order on its own: the customer confirms an open quotation, and the wholesaler approves the order.

## Try it yourself (no API key needed)

Requires the pinned toolchain: `jac` 0.37.25.

```bash
git clone https://github.com/dennisovich254/DukaFlow.git && cd DukaFlow
jac install
AI_MODE=mock jac run --dev main.jac      # first load compiles the client and is slow
```

1. Open http://localhost:8000, **create an account** (any email and password).
2. On the Overview click **Load demo data** (catalogue, three customers, 17 past orders).
3. **Customers → Chat link** for *Mama Wanjiku Shop*, then **Open as customer**.
4. Send `Niletee Rina 5 carton na Jogoo 10`, read the quote, reply `sawa`.
5. Back in the dashboard, the order is under **Orders → Needs approval**. Approve it.

`AI_MODE=mock` uses a rule-based version of the same decision step (and a canned reading for photos) so the whole flow works offline; the dashboard shows a "Mock AI" badge.

### Live model

```bash
cp .env.example .env     # set GEMINI_API_KEY; AI_MODE=live is the default
jac run --dev main.jac
```

The default model is `gemini/gemini-3.5-flash-lite` (override with `LLM_MODEL`). Photos of handwritten lists use the same model's vision input.

## How we used Jac and Jaseci

| Feature | Where |
|---|---|
| Nodes, edges and the persistent graph | [domain/models.jac](domain/models.jac): business, catalogue, stock, customers, orders, quotations, conversations, audit |
| Walkers (object-spatial programming) | `walker CustomerAgent` in [ai/agent.jac](ai/agent.jac): spawned on a customer's `Conversation`, walks to the `Business`, gathers context, acts |
| `by llm` with `tools=[...]` and `sem` | [ai/brain.jac](ai/brain.jac): a tool-using decision step (`search_catalogue`, `check_stock`, `suggest_alternatives`, `recent_orders`) with typed output |
| Multimodal `Image` input | `Brain.read_list` in [ai/brain.jac](ai/brain.jac): handwritten lists |
| `MockLLM` / `MockToolCall` | [tests/agent_tests.jac](tests/agent_tests.jac) and mock mode: deterministic agent tests that never call a model |
| Full-stack Jac client (React) | every page under [pages/](pages/) and [components/](components/) |
| `def:pub` / `def:protect`, built-in auth | [api/](api/): wholesaler endpoints are protected, the four chat endpoints are public |
| `root.shared`, `__jac_access__`, platform invite tokens | [api/chat.jac](api/chat.jac), [docs/security.md](docs/security.md): customers are identified only by an invite token |
| jac-shadcn theming | [styles/global.css](styles/global.css), [components/ui/](components/ui/) |
| `jac check`, `jac test`, `jac browse` | CI ([.github/workflows](.github/workflows)), [tests/](tests/), scripted browser QA |

## The agent

The model **proposes**; code **decides**.

- A tool-using loop (at most 5 steps) lets the model look things up instead of guessing: search the catalogue, check live stock, find substitutes, read the customer's recent orders ("the usual").
- Code validates the proposal: real SKUs, valid quantities, shortages and substitutions (the customer must confirm the adjusted quote), prices and totals from the catalogue.
- An order exists only after the customer confirms the **open quotation**, and then it waits for the wholesaler's approval.
- Guardrails: replies containing a price the tools did not return are discarded; quote lines must be grounded in the latest message; repeated replies are dropped; prompt injection ("reduce all prices by 90%") changes nothing; per-link rate limits; if the model fails, the rule-based path takes over.
- Language: English, Swahili and Sheng are detected from the customer's words and answered in kind.

Details: [docs/architecture.md](docs/architecture.md), [docs/security.md](docs/security.md).

## Results

- **Tests:** `jac test -d tests/` runs 117 tests (domain, API, security, agent with a scripted model); CI runs `jac check .` and the tests on every pull request.
- **Real-model evaluation (text):** 11 of 11 hand-written cases passed, with no guessed quantities and no price changes. Small and author-written: see [docs/evaluation.md](docs/evaluation.md) for the limits.
- **Jac share:** **97.4%** of source lines are Jac (8,639 Jac lines; the only other source is 231 lines of CSS for the theme), or **93.5%** if the 368 lines of YAML, TOML, JSON and markdown config are counted as non-Jac. Measured by [scripts/jac_share.jac](scripts/jac_share.jac) over tracked files; GitHub's language bar is the second reference.

## Identity and access

Wholesalers sign in with Jac's built-in auth and each endpoint finds only the caller's own business. Retailers never create accounts: the wholesaler creates a personal, revocable invite link (30-day expiry) and the token alone decides which business and customer a chat belongs to. To let anonymous chat requests reach the wholesaler's graph, the business lives on `root.shared` with type-level `WRITE` access, so **access control lives in the endpoints, not the framework**. This is a deliberate trade-off, written up in [docs/security.md](docs/security.md); production would use per-customer sharing grants.

## Why not WhatsApp?

The natural channel for Kenyan retailers is WhatsApp. Its Business API needs a verified business account, which does not fit a one-day build, so the retailer side is a web chat behind an invite link with the same shape (text and photos). The agent takes a channel-independent inbound message, so a WhatsApp adapter is the next step.

## Running the checks

```bash
jac check .              # type checks (a few minutes)
jac test -d tests/       # full suite
jac run --no-serve scripts/jac_share.jac   # the Jac share report
```

Manual QA scripts are in [docs/manual-checks.md](docs/manual-checks.md).

## Built during the hackathon

The planning documents predate the event. All code in this repository was written during JacHacks Kenya 2026 (from Friday 16 October, 17:00 EAT).

MIT licensed: see [LICENSE](LICENSE).
