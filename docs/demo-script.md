# SmartSave MVP demo video script (about 4 minutes 30 seconds)

## Before recording

- Use the debug APK on an Android device/emulator when available; use an iOS simulator only after an Xcode build has been verified.
- Start with a fresh/demo state. Use a fictional address such as `demo@student.edu` and a throwaway password of at least eight characters. The app does not authenticate or securely store credentials.
- Keep the Settings → Profile → Reset demo data action available for a repeatable take.
- Do not describe the card as truly connected or the deposits/stocks as current offers. Rates, transactions, stock values and recommendations are explicitly local fictional samples.

## Timed narration and actions

### 0:00–0:25 — Problem and purpose

**Say:** “People often know how much they earn but not where smaller expenses accumulate or how those expenses affect a savings goal. SmartSave brings spending, category budgets, goals and financial information into one simple mobile view.”

**Show:** SmartSave welcome artwork and the tagline, “Know where your money goes. Know what to do next.”

### 0:25–0:55 — Demo onboarding

**Do:** Tap **Get started**, enter the fictional demo contact and password, accept the demo terms, and create the account. Skip through the onboarding or show the three pages. On the card step, choose **Skip, add transactions manually**; answer the five risk questions and continue from the illustrative risk profile.

**Say:** “This is a local demo account. The card step never contacts a bank; the risk result is illustrative, not investment advice.”

### 0:55–1:25 — Dashboard

**Show:** Total balance, current-month spending, the first goal’s progress, the daily sample advice, category bars and recent transactions.

**Say:** “These totals come from the local SQLite records, not unrelated screen mock values. The sample rows are fictional and carry no live bank connection.”

### 1:25–2:05 — Add and inspect a transaction

**Do:** From **Recent → See all**, tap **+**. Add an expense such as `2,500 ₸`, merchant `Demo lunch`, category **Food**, with today’s date, then Save. Show the row in the list and updated analytics. Open the row, edit the note or amount, save, and show the summary update. If time allows, delete the demo row and confirm the totals return.

**Say:** “Transactions support income or expense, category, date, merchant and an optional note. Editing and deleting a record recalculates the local summaries.”

### 2:05–2:40 — Spending and budget

**Do:** Open **Top spending this month → See all**. Show the donut and category totals. Tap **Food** to open category detail, edit the monthly budget, and open **Where to cut**. Select one suggestion and apply it to the plan.

**Say:** “Category budgets and spending insights are based on the saved sample entries. The cut suggestions save a planning choice only; they do not change a real purchase or transaction.”

### 2:40–3:20 — Savings goal

**Do:** Tap **Goals → New goal**. Create `Capstone laptop`, target `350,000 ₸`, select a deadline and purpose, then save. Open the goal, show percentage/remaining/monthly estimate, add a small local contribution, and verify the progress changes. Open the savings plan or the **Auto-save · coming later** state.

**Say:** “The amount remaining and monthly estimate are recalculated from the goal and its recorded contributions. A contribution is only a local demo record; SmartSave does not transfer funds.”

### 3:20–4:05 — Deposit comparison and investment information

**Do:** Tap **Deposits**, change the term/filter chips, select two products for comparison, open a product, enter a calculator amount, and open **Why this deposit?** Then tap **Invest** and show the watchlist and one stock detail.

**Say:** “This demonstrates comparison and transparent estimation from local sample rate cards. The stock quotes and recommendations are samples; the app does not place orders or provide financial advice.”

### 4:05–4:30 — Persistence and limitations

**Do:** Open **Profile → Reset demo data** only if you need to restore the original presentation state. For a persistence proof, add a different small transaction, close/reopen the app, and show that it remains before resetting.

**Say:** “Structured data is stored locally in SQLite, with a reset option for repeated demonstrations. This MVP has no secure backend, bank sync, live market feed, brokerage, billing or real money movement. Android build and automated checks are available; iOS/device testing needs a macOS/Xcode and device run.”
