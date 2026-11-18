# SmartSave AI Demo Guide

**For the current Flutter MVP.** This guide describes what is implemented now, not a proposed production system. In particular, SmartSave currently has **no connected generative AI model and no live market-data provider**. The assistant added to the app is a local, rule-based helper; the investment review and scenario tools are deterministic calculations over user-entered data.

## 1. Presentation-ready introduction

> “SmartSave helps people understand everyday spending and plan savings. Its investment workspace adds a research habit: record why you own a security, state what could change your mind, and test liquidity and economic scenarios using transparent assumptions. Today’s assistant and investment calculations run locally on saved demo data and user inputs. They explain uncertainty rather than claiming to predict the market.”

The short version: **SmartSave connects financial tracking with a structured investment-research workflow; it does not execute trades or promise returns.**

## 2. What the assistant is—and is not

The assistant is designed to make existing SmartSave records and workflows easier to understand. It can summarize saved spending against category budgets, estimate monthly contributions for saved goals, list saved investment theses, and explain what the liquidity and economic-scenario tools do.

It differs from an unrestricted chatbot because its replies come from a small set of explicit local rules. For supported questions it reads saved SQLite records and performs simple calculations. Unsupported questions receive a scope explanation and example prompts. It does not send prompts or personal records to a model provider.

**It is not a generative AI model.** There is no OpenAI, Anthropic, Gemini, Ollama, or other model client, API key, environment variable, or network request in this assistant. The in-app label says “Local demo helper” and discloses that no generative AI is connected. Call it “the SmartSave financial assistant” or “local rules-based assistant” in a presentation; do not claim that an LLM generated its replies.

### Questions it can handle

- “How is my spending?” or “Am I within budget?” — category spending, saved limits and the recorded monthly total.
- “How are my goals progressing?” — saved goal progress and a monthly contribution estimate.
- “What can I review about investments?” — a list of saved theses and a reminder about evidence limits.
- “What does liquidity mean here?” — how the hypothetical historical-volume calculation is interpreted.
- “How does the oil / tenge / interest-rate scenario work?” — a description of the scenario tool, not a market forecast.
- “What is my balance?” — the local demo balance and recorded monthly spending.

The message router uses case-insensitive keyword checks. It does not understand arbitrary language, reason across an unrestricted conversation, or invent missing data. It does not currently include saved transactions in a prompt; there is no prompt sent anywhere.

## 3. How it is wired into the app

| Component | Role |
|---|---|
| [`main.dart`](../lib/main.dart) | Opens the existing `FinanceRepository`, starts the root `ProviderScope`, supplies the root `Navigator` key and wraps the app child in the assistant overlay. |
| [`app.dart`](../lib/features/app/app.dart) | Owns the five-tab signed-in `AppShell`. It marks the demo app session active after the first frame, so welcome, authentication and onboarding do not show the bubble. Leaving the app shell clears the in-memory assistant thread. |
| [`assistant_access_overlay.dart`](../lib/features/advice/assistant_access_overlay.dart) | Adds one reusable floating pill in a root `Stack`, instead of copying a button into each screen. It opens the assistant through the root navigator. It hides while the assistant route is active or the keyboard is open. |
| [`assistant_session.dart`](../lib/features/advice/assistant_session.dart) | Holds the root navigator key, app/assistant visibility signals and the Riverpod conversation provider. The conversation is in memory, not stored in SQLite. |
| [`financial_assistant_screen.dart`](../lib/features/advice/financial_assistant_screen.dart) | Renders the chat-style interface, starter questions, disclosure, send field, feature shortcuts and conversation bubbles. It retains messages while the root provider remains alive. |
| [`financial_assistant_service.dart`](../lib/features/advice/financial_assistant_service.dart) | Routes supported question keywords to deterministic SQLite reads/calculations and constructs the response text. It has no HTTP client or model call. |
| [`finance_repository.dart`](../lib/data/finance_repository.dart) | Stores and retrieves local transactions, budgets, goals, advice, theses, conditions, assessment history, holdings and scenario settings. Seed records are fictional demo data. |
| [`finance_controller.dart`](../lib/data/finance_controller.dart) / [`providers.dart`](../lib/data/providers.dart) | Loads shared finance state through Riverpod. The assistant service reads the repository directly for its answers. |
| [`financial_math.dart`](../lib/data/financial_math.dart) | Contains the integer arithmetic for goal contributions and simple deposit interest. |
| [`investment_models.dart`](../lib/data/investment_models.dart) / [`investment_analysis.dart`](../lib/data/investment_analysis.dart) | Defines persisted investment records and deterministic condition, liquidity and scenario calculations. |
| [`investment_intelligence_screen.dart`](../lib/features/invest/investment_intelligence_screen.dart) | Provides Thesis Autopsy, Liquidity and Economic Ripple screens from the existing Invest tab. |

The root overlay is present on the dashboard and all screens/routes while `AppShell` remains alive, including goals, transactions, nested transaction/goal screens and Investment Intelligence. It is absent from welcome/auth/onboarding. It sits at the bottom-right above the 80-pixel navigation bar with safe-area padding; it is hidden while the keyboard or assistant is open. From the assistant menu, opening Investment Intelligence or Recommendations shows the bubble on that feature screen and hides it again when returning to chat.

### Data, configuration and failure behavior

- User-entered and seeded finance data is stored in the app’s local SQLite database through `sqflite`; the demo session/profile flags use `shared_preferences`.
- The assistant conversation itself is held in a Riverpod `StateProvider` for the current app process. Closing and reopening the assistant preserves it. Leaving the signed-in app shell clears it. It is not a durable conversation archive.
- **No API key or environment setting is required.** There is no external AI request, network dependency, rate limit or provider quota to exhaust.
- If local repository access fails, the chat displays a local-records error message. No offline model fallback is needed because the assistant already operates locally.
- Demo authentication is simulated, SQLite data is not protected by production account authorization, and no backend isolates one person’s data from another. Do not store real account credentials or sensitive financial records in this capstone demo.

## 4. The three investment features

### 4.1 Investment Thesis Autopsy (screen label: “Thesis autopsy”)

An investment thesis is the user’s written explanation for why they are interested in a security and which observable facts might support or weaken that reasoning. SmartSave saves the security name, ticker, exchange, optional identifier, rationale, horizon, assumptions, risks and invalidation conditions. A name and ticker are required; other fields can be left blank and edited later.

A user can add a numeric condition or a qualitative one. The condition form accepts a description, optional metric, comparator (`at least` / `at most`), threshold, observed value, reporting period, source/reference and evidence note. The user enters the value and reference; SmartSave does not fetch the report or verify that the source is authentic.

When **Assess available evidence** is pressed, [`evaluateCondition`](../lib/data/investment_analysis.dart) applies this rule:

- Missing numeric threshold, observed value, source or period → **Insufficient evidence**.
- Qualitative condition → **Insufficient evidence**, because no issuer-disclosure review is integrated.
- A numeric value that meets the entered threshold → **Supported** by the entered value.
- A numeric value that misses the entered threshold → **Contradicted** by the entered value.

“Supported” and “Contradicted” describe the arithmetic comparison only. The app explicitly says it has not independently verified the user-entered observation. The current evaluator does **not** produce the “Weakening” classification, and it does not automatically review qualitative disclosures. “Not evaluated” is used before a condition has an assessment; once assessed, conditions without sufficient inputs are marked insufficient.

Each assessment stores its timestamp, condition statuses, entered evidence strings, and a structured bear-case prompt in SQLite. The bear-case summary is generated by deterministic code from the user’s own rationale, risks, assumptions and invalidation conditions. It is not LLM analysis or an issuer-specific fact check. A later assessment is appended; earlier snapshots are not overwritten. The detail screen can compare condition statuses with the previous assessment.

**Works today:** create/edit/delete a thesis, add/edit conditions, perform numeric threshold comparisons, record history, and produce transparent research prompts. **Incomplete:** no issuer filings, financial statements, dividend records, company facts, document citations or automatic qualitative review are connected; condition evidence is manually supplied.

### 4.2 Liquidity Simulator (screen label: “Liquidity”)

Liquidity is how readily a position might be traded without assuming that the last displayed price is available for every share. The user can select a saved thesis, then manually enter an order size, average daily historical volume, observation date and source label. The UI lets the user choose a participation assumption from 1% to 50%.

[`analyzeLiquidity`](../lib/data/investment_analysis.dart) calculates:

- Order-to-volume multiple = `order size ÷ average daily volume`.
- Scenario trading days = `order size ÷ (average daily volume × participation percentage ÷ 100)`.
- Missing/zero volume or missing date → no calculation; observation more than 7 days old or in the future → stale.

Example: 1,000 shares ÷ 500 shares/day = 2× daily volume. At 10% participation, the arithmetic scenario is 1,000 ÷ (500 × 0.10) = 20 trading days. These are **illustrative user inputs**, not a live quote, forecast, or execution promise.

No real historical volume, current bid–ask spread, order book, depth or slippage feed is connected. The form’s source/date/volume values are not persisted between visits. The code never predicts an execution price. Historical volume is not current available liquidity.

### 4.3 Economic Ripple Simulator (screen label: “Economic ripple”)

This screen asks the user to add KZT-valued holdings and optional sensitivities, then choose one hypothetical shock: tenge depreciation, an oil-price decrease or an interest-rate increase. A sensitivity means the **assumed percentage return of that holding per unit of macro change**. These are user inputs, not verified issuer exposures.

For each holding, [`simulateRipple`](../lib/data/investment_analysis.dart) calculates:

- Estimated holding return percentage = sensitivity × scenario magnitude × direction. Oil-price decline uses a negative direction; FX and rate direction use the sign the user entered in the sensitivity.
- Change in KZT = `round(market value in KZT × estimated return percentage ÷ 100)`.
- “After” value is the sum of before-values and calculated changes only when every holding has a sensitivity for the selected scenario. Otherwise, the portfolio total is “Not estimated”; unknown exposure is not treated as zero.

Example assumptions: a KZT 100,000 holding with FX sensitivity 0.5% return per 1% tenge depreciation, under a hypothetical 10% depreciation, produces a scenario return of +5% and a +KZT 5,000 change. This is **not a prediction about any security**. An oil sensitivity of 0.2 with a 20% oil-price decrease produces −4% under the code’s direction rule; a rate sensitivity of −1 with a 2 percentage-point increase produces −2%.

Portfolio holdings and scenario type/magnitude are saved locally. There is no imported portfolio, exchange rate, oil series, interest-rate series or company sensitivity. Results are transparent scenarios, not verified forecasts or empirically estimated impacts. Currency is explicitly KZT in the model; the app does not reconcile foreign-currency holdings.

## 5. What data sources actually connect

**None of the market-data websites below are called by the app.** There is no KASE, AIX, National Bank, bank, brokerage or company-disclosure API configured. Stock cards, deposit product examples, advice records and seeded transactions are explicitly fictional/local samples. The investment screens use user-entered evidence, volume and holdings assumptions only.

- [KASE market prices](https://kase.kz/en/information/market-prices/) advertises an API, but the page states copying KASE materials requires written permission.
- [KASE delayed trading information](https://kase.kz/en/information/delayed-trade-information/) describes a subscription and standard agreement.
- [AIX](https://www.aixkz.com/) links market-watch and issuer-disclosure pages; the reviewed public pages did not establish a free API or redistribution right.
- The [National Bank open-data repository](https://data.nationalbank.kz/) exists, but this project does not fetch its records.

No subscription or data service was purchased or activated. Do not describe sample content as live KASE data.

## 6. Step-by-step demo and test preparation

### Launch the app

From the SmartSave project folder in Android Studio Terminal or PowerShell:

```powershell
flutter pub get
```

Start the existing emulator in Android Studio Device Manager, then launch SmartSave:

```powershell
flutter run -d emulator-5554
```

If the device serial differs, check it first:

```powershell
flutter devices
```

No API key, `.env` file or AI configuration is required. The account/onboarding flow is simulated. Complete or skip onboarding to reach the five-tab app shell. The floating **Ask SmartSave** pill appears above the bottom navigation on signed-in screens; tap it to open the assistant. Type “Am I within budget?” or use a starter chip. You should see a monthly local spending summary and category-versus-budget lines. Values depend on the records currently stored; unchanged demo seed data has a repository test total of KZT 312,400, but edited records change the response.

The bubble should disappear while the assistant is open or while the keyboard is visible. Close the assistant with Android Back. Its messages remain when reopened. The assistant menu also opens Investment Intelligence and Recommendations.

### Test Investment Intelligence

Open **Invest → Investment Intelligence → Thesis autopsy**.

1. Tap **Create your first thesis**. Use `Example issuer` and `EX` as a fictional security name/ticker. Optionally enter a rationale, `3–5 years`, assumptions, risks and reconsideration conditions. Save it.
2. Open the thesis and add a numeric condition: description `Revenue growth stays above 5%`; metric `Revenue growth (%)`; comparator `At least`; threshold `5`; observed value `7`; reporting period `FY2025`; source/reference `User-provided demo report reference`.
3. Select **Assess available evidence**. Expected: **Supported**, because the entered 7 is greater than or equal to the entered 5. It is not independently verified; the source text is just user input. Reopen history to see the timestamped snapshot.
4. Edit the condition observation to `4` and reassess. Expected: **Contradicted** by that threshold comparison, with the newer snapshot preserved.
5. Add a qualitative condition such as `Dividend remains supported by reported earnings`, with no numeric threshold. Expected: **Insufficient evidence**. No company disclosure is retrieved.

These values are teaching fixtures only. Do not present them as financial statements for a real issuer.

### Test Liquidity

Open the **Liquidity** tab and choose the saved thesis if desired. Enter order size `1000`, average daily volume `500`, today’s date and source label `User-entered practice value`; leave participation at `10%`.

Expected scenario: `2.0×` the entered average daily volume and about `20.0` trading days at that participation. The app should state that this is not an executable-liquidity or price prediction. Change the date to more than seven days ago to see **Stale observation**; clear volume or enter zero to see **Insufficient evidence**. These are manual inputs, not supported market data.

### Test Economic Ripple

Open **Economic ripple**, add a fictional holding with name `Example issuer`, ticker `EX`, market value `100000` KZT, and FX sensitivity `0.5`. Leave other sensitivities blank. Select tenge depreciation and magnitude `10%`.

Expected scenario arithmetic: +5% and +KZT 5,000 for that holding, with a total only if every selected holding has a sensitivity. Add another holding with unknown FX sensitivity to see its output remain unestimated and the portfolio after-total become unavailable. Then use the oil and rate sliders with corresponding user-entered sensitivities. None is a verified forecast.

### Reset and troubleshoot demo data

- **Profile → Reset demo data** restores the existing sample transaction, goals, budgets, advice and deposit records. Investment theses and holdings are separate user-created records and are not cleared by that existing reset action; delete them in the relevant feature if you want a clean research demo.
- If SmartSave shows loading/error, confirm `flutter devices` lists the emulator, then reopen the app. `flutter analyze` checks code; `flutter test --no-pub test/financial_assistant_service_test.dart` checks assistant calculations; `flutter test --no-pub test/assistant_bubble_widget_test.dart` checks bubble/navigation/conversation state.
- If you ask for a current quote or unsupported question, the assistant will state its scope instead of inventing a value. If local DB access fails, it returns an error; there is no network/API retry or API key to troubleshoot.

## 7. Five-minute presentation plan

### 0:00–0:40 — The problem

Explain that ordinary budgeting tells people where money went, but does not help them articulate what they believe about an investment or what evidence would change their mind.

### 0:40–1:15 — What is distinctive

Show the **Invest** tab and the Investment Intelligence entry. Say: “SmartSave links a user’s own thesis to explicit conditions and scenario assumptions. It shows what the data can and cannot support.” Clarify that this MVP has a local rule-based helper, not a connected LLM or live exchange feed.

### 1:15–2:30 — Thesis Autopsy

Create `Example issuer` / `EX`; add the 5% threshold with a user-entered 7, source label and FY2025 period; assess. Explain: “Supported means 7 meets the threshold I entered; SmartSave has not checked the underlying report.” Add or point out a qualitative condition to show insufficient evidence and inspect assessment history.

### 2:30–3:15 — Liquidity

Enter order 1,000 shares, average volume 500, participation 10%. Explain the 2× and 20-day arithmetic; emphasize that it is a hypothetical volume scenario, not an order-book or price prediction.

### 3:15–4:10 — Economic Ripple

Use the KZT 100,000 / 0.5 FX sensitivity / 10% depreciation example. Show the +KZT 5,000 scenario and explain that 0.5 is your assumption, not an issuer statistic.

### 4:10–5:00 — Close and questions

End with: “The current value is a disciplined local research workflow—write down the thesis, inspect assumptions and preserve evidence history. Live disclosures, market data and a true LLM are future integrations, not capabilities I claim today.”

### Likely evaluator questions

**“Is this real AI or just predefined responses?”**  
The chat screen is a small local, keyword-routed, rule-based helper with fixed response templates and calculations over saved SQLite data. It is not generative AI. Investment analyses also use deterministic comparisons and formulae, not an LLM.

**“Where does the financial data come from?”**  
Everyday finance data is local SQLite content, including fictional seeded demo rows and user entries. Market observations in the investment tools are entered by the user. There is no live KASE/AIX, bank, broker or disclosure feed.

**“How do you know the conclusions are correct?”**  
The assistant is not a general factual authority. Budget/goal answers can be checked against saved records and arithmetic. A thesis result only verifies whether the user-entered number meets the user-entered threshold. The app does not verify source documents, and scenario inputs remain assumptions.

**“Does it actually work with Kazakhstan’s stock market?”**  
The UI is aimed at Kazakhstan-listed securities and defaults the exchange field to KASE, but no Kazakhstan exchange data is connected. A ticker or KASE label entered by a user is not proof of coverage.

**“Can it predict whether a stock price will rise?”**  
No. It neither predicts share prices nor recommends a buy/sell decision. Ripple is a transparent assumption-based sensitivity scenario; Liquidity does not predict an execution price.

**“What happens when market data or an AI API is unavailable?”**  
There is no market-data or AI API configured, so there is no API key, quota, or network outage path. Missing user evidence produces an insufficient/stale state or a limitation message.

**“What makes this different from an ordinary budgeting app?”**  
It adds a saved thesis, testable conditions, dated assessment history, a volume-based liquidity scenario and macro-exposure scenarios, so a user can revisit why they own a security and what assumptions to challenge. Those tools are still local MVPs with no live market verification.

## 8. Quick-reference checklist

- [ ] Say **local rule-based assistant**, not generative AI.
- [ ] Say sample transaction/market content is not live data.
- [ ] Show the Ask SmartSave bubble and a budget question.
- [ ] Create the fictional `EX` thesis and 5% / 7 user-entered comparison.
- [ ] Explain that **Supported** is threshold arithmetic, not report verification.
- [ ] Show qualitative **Insufficient evidence** and assessment history.
- [ ] Demonstrate liquidity with user-entered volume; never call it order-book depth.
- [ ] Demonstrate Ripple with explicitly hypothetical sensitivity; never call it a forecast.
- [ ] Mention no trades, bank connection, AI key, or paid service are used.
- [ ] Close with the real next steps: licensed disclosures/market data and a privacy-reviewed AI provider.
