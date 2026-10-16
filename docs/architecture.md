# Architecture notes

## The customer agent (P4)

A chat message becomes an `InboundMessage`, is stored, and then `walker CustomerAgent` is spawned on the customer's `Conversation` node. The walker walks back to the `Business`, gathers context (open draft or quotation, recent messages), asks the model for a **decision**, and acts through deterministic code.

- **Decision step** (`ai/brain.jac`, `Brain.decide`): a tool-using `by llm` call (ReAct, at most 5 iterations). Tools: `search_catalogue`, `check_stock`, `suggest_alternatives`, `recent_orders`. The model returns an `AgentDecision` (QUOTE, CLARIFY, ANSWER or ESCALATE plus the lines it understood).
- **What code decides** (`ai/agent.jac`, `domain/quotations.jac`): whether the SKUs are real and quantities valid; shortages and substitutions (the customer must confirm the adjusted quote); prices and totals; confirmation (only a short yes-like message against the **open quotation**); creating exactly one `PENDING_APPROVAL` order at the quoted prices. The wholesaler still approves.
- **Replies** (`ai/replies.jac`): quotations, stock notes and confirmations are templates (English and Swahili, chosen from the customer's words). Model-written clarifications and answers are kept only if every `KSh` figure in them came from a tool result in the same run.
- **Photos**: `Brain.read_list` (vision) returns the list lines; unclear lines are asked about before quoting, and the clear lines are kept in a `DRAFT` quotation that the customer's answer completes.
- **Fallback and mock mode** (`rule_decide`): the same decision made by rules. `AI_MODE=mock` uses it, and it takes over when the model call fails. Mock photos use a canned demo reading and the dashboard shows a "Mock AI" badge.
- **Limits**: message length 1000 characters, 30 lines per quotation, quotation expiry 24 hours.
- **Trace**: each processed message stores an `AgentExecution` (tool calls, outcome, duration).

## Real-model runs (Gemini, `gemini/gemini-3.5-flash-lite`)

| When (EAT) | Purpose | Messages | Notes |
|---|---|---|---|
| Fri 16 Oct, 17:05 | P0.4 smoke | 1 text, 1 image | typed output and image reading worked |
| Fri 16 Oct, ~21:00 | P4.9 first agent check | 5 text messages | found two prompt mistakes: asked about shortages instead of quoting; claimed an order was placed. Both fixed in the decision instructions |
| Fri 16 Oct, ~21:25 | P4.9 recheck | shortage, "the usual", sample photo | shortage quoted at KSh 35,550; "the usual" quoted from history; photo read and quoted; one order created only after "sawa" |
