# Compliance radar

A second, proactive agent for the wholesaler: it reads Kenyan tax, levy and standards notices, works out which of **this** business's products they touch and how much of the last 30 days' sales is at stake, and plans next steps the wholesaler can act on with one click. Nothing happens until they click.

## Pipeline

`notice text` -> **read** (`ai/regulation.jac`) -> **check** -> store as `RegNotice` -> **`ComplianceScout`** walker (`ai/radar.jac`) -> `ComplianceAlert` + `AlertAction` nodes -> page `/dashboard/compliance`

1. **Read.** With a model, `extract_notice` (a typed `by llm` call, `sem` rules, temperature 0) turns the notice into plain-English facts. In mock mode and when the model fails, the facts come from the reviewed snapshot labels (`integrations/regsnapshot.jac`); pasted text uses a modest keyword extractor.
2. **Check.** No word-for-word quoting is required. Hard facts (rates, dates, goods) are looked up in the source text by code and removed if absent; claims are judged by a second `by llm` pass (`verify_claims`, a different prompt that only sees the source and the claims) or, without a model, by a word-overlap rule. If the main change is unsupported, or the goods named are not in the source, the notice is dropped. The "From the source" passage shown to the wholesaler is picked by code, not written by the model.
3. **Match and quantify (code only).** Products match by category or by a keyword in the name or brand ("ALL" rules touch everything). 30-day sales come from approved-to-delivered orders. Severity: HIGH or MEDIUM only for law (enacted or in force; HIGH from 10% of sales, imports-only capped at MEDIUM), LOW for proposals, INFO when no product is touched.
4. **Plan actions (code only, `ai/actions.jac`).** A tax change with both rates stated as percentages gets a pass-through price per product (`price x (100 + after) / (100 + before)`, rounded up to KSh 10), a stock-up quantity before the date (30-day sales rate, capped at 30 days of cover) and a drafted message to each customer who bought the product (English, Swahili or Sheng, from their own messages). Changes without a usable rate get "check supplier prices"; standards get "check stock" and "pause products"; proposals are watch-only.
5. **Act.** Applying prices, sending messages and pausing products run only from their own endpoint after a confirm dialog, and are audited. Advice-only steps are marked done or skipped.

## Sources and the demo snapshot

The default and the demo use a reviewed snapshot of 10 real notices (KRA, Finance Acts 2025 and 2026 coverage, KEBS draft standard, plastic packaging rules) and one clearly labelled **sample** notice (an invented VAT rise on cooking oil) so the repricing, stock-up and customer-message flow can be shown. Each snapshot entry links to its source; the text is a short summary compiled from that report and checked by a person, not the official wording. Live fetching (`integrations/regwatch.jac`) is limited to https pages on KRA, Kenya Law, Parliament, KEBS, Treasury and NEMA hosts, with no IP addresses, no redirects off the list, 10 s and 2 MB limits; it is best effort and the snapshot is the fallback. The Kenya Law site refused automated requests when this was built.

## Limits

- Not legal advice, and the page says so. Coverage is a whitelist and a snapshot, not all Kenyan law.
- Suggested prices only pass the tax change through; the app holds no cost or margin data.
- Source reports sometimes disagree (for example the previous excise rate on imported sugar); the snapshot leaves such a rate UNKNOWN rather than guessing.
- Evaluation of the live extraction on the snapshot is not yet run.
