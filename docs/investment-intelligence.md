# SmartSave Investment Intelligence (local MVP)

## Current implementation

Investment theses, user-entered conditions, immutable assessment snapshots, and KZT portfolio holdings are stored in the existing local SQLite database. The analysis service is deterministic: numeric conditions compare entered observations against thresholds; qualitative conditions remain **Insufficient evidence** because no issuer-disclosure provider is connected. Results distinguish user statements from rule-based comparisons and do not create buy/sell recommendations.

The liquidity tool compares a hypothetical order with a dated, user-entered historical average volume. It reports a volume multiple and a participation-rate scenario in trading days, but never estimates an execution price. Observations older than seven days are marked stale; missing or zero volume cannot produce a result. Historical trading volume is not current order-book depth.

The economic ripple simulator supports tenge depreciation, an oil-price decline, and higher interest rates. Users enter KZT market values and per-unit sensitivities. The output is a transparent scenario calculation, not an empirical forecast. Every sensitivity is hypothetical/user-provided; missing issuer sensitivities cannot be inferred from market or company data in this app.

## Market data, licensing, and AI

No live, delayed, or historical market-data provider is connected. KASE's market-prices page advertises an API but says copying KASE materials requires written permission. KASE delayed trade information is described as a subscription requiring a standard agreement. AIX's public site links market-watch and issuer-disclosure pages but the reviewed material did not establish a free API or redistribution permission. The National Bank maintains official exchange-rate and open-data pages, but this MVP does not retrieve those records. Users should provide only data they have permission to use and retain its source and reporting period.

No AI provider or model is configured. No API keys, paid services, or external services are used. The structured thesis review is local and rule-based, not generative AI. A provider can be added later behind the same evidence boundary after its price, privacy, and terms are assessed.

The local demo authentication is not production authentication, and local SQLite data has no per-user backend authorization. Do not use the app to store sensitive real financial data. Nothing in the module places orders or connects to a brokerage.

## Candidate repository review

`gsaini/financial-research-analyst-agent` is MIT-licensed, but its described stack is a separate Python/LangChain/LangGraph/FastAPI/Streamlit application with multiple external data and model integrations. Yahoo Finance is described as the primary provider; no KASE/AIX coverage is established. It was not integrated because it does not solve the Kazakhstan data/licensing constraint and would add a backend and services absent from this Flutter MVP.

## Suggested five-minute demonstration

1. Open **Invest → Investment Intelligence** and note the explicit no-live-data status.
2. Create a thesis for a security, recording the rationale, horizon, assumptions, risks, and invalidation conditions.
3. Add a numeric condition, enter an observation with source and period, assess it, then inspect the saved bear-case review and assessment history. Add a qualitative condition to show the honest insufficient-evidence state.
4. Enter an order size and dated average volume in Liquidity, then change the participation assumption; highlight that the result is a scenario and not an execution-price prediction.
5. Add a holding in Ripple, enter clearly hypothetical sensitivities, run each of the three scenarios, and inspect the calculation assumptions and KZT before/after values.
