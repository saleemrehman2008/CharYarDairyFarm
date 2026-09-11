# Handoff: Char Yar Dairy Farm — Android app

## Overview
An Android app for a 4-partner dairy farm in Pakistan. Three roles: **Master** (one account, full admin, also a co-founder), **Co-founder** (investors; dashboard, approvals, product rates, own share) and **Customer** (buys milk/dairy online, may register for monthly credit "udhaar"). The app records sales, purchases, expenses, receivables and payables, closes each month and splits profit by investment ratio, keeps a full activity log, and mirrors every record to a Google Sheet.

Target repo: `github.com/saleemrehman2008/CharYarDairyFarm` (currently empty).

## About the design files
`Char Yar Dairy Farm.dc.html` (+ `support.js`, `android-frame.jsx`, `image-slot.js`, `_ds/`) is a **design reference built in HTML** — an interactive prototype showing intended look and behaviour with in-memory sample data. It is not production code. Recreate the screens in the chosen mobile framework using its own component patterns. Open the HTML in a browser to click through every flow; the "Sign in as" buttons above the phone switch roles.

## Fidelity
**High-fidelity for layout, copy, colour and flow.** Recreate the screens as shown. Exact pixel values matter less than structure and behaviour on a real device; use the token table below.

## Recommended stack (no codebase exists yet)
- **Flutter** (single codebase, Android first; iOS later for free).
- **Firebase**: Authentication (Google sign-in), Cloud Firestore (data), Cloud Functions (Sheets sync, notifications, month close), Cloud Messaging (push).
- **Google Sheets API** via a service account, called only from Cloud Functions.
- **WhatsApp**: open `https://wa.me/<number>?text=…` deep links from the app for approval/delivery messages (no Business API needed initially).
- CI: GitHub Actions builds a signed release APK/AAB on every push to `main` and attaches it to a GitHub Release. (GitHub stores code and build artifacts; it does not "run" the app — users install the APK, or later from Google Play.)

## Roles & permissions
| Capability | Master | Co-founder | Customer |
|---|---|---|---|
| Google sign-in | ✓ | ✓ | ✓ |
| Dashboard (balance, sales, costs, AR, AP, profit MTD) | ✓ | ✓ (read) | – |
| Approve orders / udhaar registrations (any ONE co-founder approves; all notified) | ✓ | ✓ | – |
| Advance order status | ✓ | ✓ | – |
| Add transactions (sale/purchase/expense/receipt/payment), mark unpaid entries paid | ✓ | ✓ | – |
| Delete transactions | ✓ | – | – |
| Products & rates: edit rate, add, remove item, photo | ✓ | ✓ | – |
| View co-founders, ratios, closed months | ✓ | ✓ | – |
| Add investment for a co-founder | ✓ | – | – |
| Close month & choose AR treatment | ✓ | – | – |
| Users: assign role, approve sign-up, block/unblock, reset password | ✓ | – | – |
| Activity log | ✓ | – | – |
| Shop, cart, checkout, my orders | – | – | ✓ |
| Udhaar registration & balance | – | – | ✓ |

New Google sign-ins default to role `customer`, status `pending` until Master approves (customers may still browse the shop; ordering requires `active`). Master promotes an account to `investor` (co-founder) and links it to a Partner record. Blocked users are signed out on next token refresh.

## Screens

### 1. Login
Centered logo (`assets/logo.png`, 180 px wide), kicker "FRESH & NATURAL · QUALITY MILK", title "Char Yar Dairy Farm" (Barlow Condensed 600, 44 px), one-line description, primary button **Continue with Google** (48 px tall, full width), note "New accounts wait for approval by the master account."

### 2. App shell (all roles)
Top bar: 36 px logo (or back arrow on sub-screens), title (Barlow Condensed 600, 22 px) + subtitle (11 px: role + share %), "Sheets synced" tag (master/co-founder), "Sign out" ghost button. Bottom tab bar, 11 px labels, Lucide 1.5-stroke icons, badge count in accent square.
Tabs — Master: Home, Orders, Accounts, Co-founders, More. Co-founder: Home, Approvals, Accounts, Co-founders, Products. Customer: Shop, Cart, Orders, Udhaar.
Toast: dark bar above tab bar, 2.4 s.

### 3. Home (Master)
- Card "Current balance · {Month}" + tag "Open"; balance (36 px); note.
- 2×2 KPI cards: Sales MTD, Purchases & expenses, Accounts receivable, Accounts payable (each taps into Accounts with filter preset).
- Card "Month to date": profit (28 px), "Sales X − Costs Y", 6 px bar = profit/sales, primary button **Close {Month} & share profit**.
- List "Needs attention": pending orders, pending udhaar registrations, pending users, payables due. Each row: tag, text, meta, tap → target screen.

### 4. Close month (Master, sub-screen)
- Summary lines: Sales, − Purchases, − Expenses, ± Receivables. "Profit to share" (26 px).
- Card "Uncollected receivables · Rs X": two radios — *Count as this month's income (share on paper)* / *Roll into next month (share cash only)*.
- Per co-founder row: name, ratio tag, share amount, segmented **Withdraw | Add to investment**.
- Primary **Close month & post shares**; footnote about Sheets/log/notifications.
- Confirm dialog before posting (not in prototype; add).

### 5. Orders / Approvals (Master, Co-founder)
Segmented filter All | Open | New. Order card: "#id · Customer", status tag, items text ("4 L Fresh milk, 1 kg Yogurt · daily"), mode · slot · payment · total, 4-segment progress bar (New → Preparing → Out for delivery → Delivered), approval text ("Awaiting approval · all co-founders notified" / "Approved by Name"), buttons **Approve** (status New) or **Mark preparing/out for delivery/delivered**.
Marking Delivered on an udhaar order posts a `sale` transaction (unpaid) to the customer's receivable.

### 6. Accounts (Master, Co-founder)
3 mini cards: Receivable, Payable, Cash. Segmented filter All | Sales | Expenses | Receivable | Payable + **+ Add**. Intro line: "All farm money in one place: milk & product sales, cattle, feed, bills, rent, food, salaries. Anything sold or bought on credit stays unpaid until you mark it paid." Table: Date | Entry (party; type · category · "240 L × Rs 200"; "unpaid" + **Mark paid** button) | Amount (accent-700 + for sale/receipt, − for others; master sees ✕ delete). Mark paid sets paid=true, posts a receipt (sale) or payment (purchase/expense) row, logs it.

### 7. New entry (Master, Co-founder; sub-screen)
Type segmented: Sale | Purchase | Expense | Receipt | Payment. Fields: Party, Category (per type), **Qty · Unit (L, kg, maund, bag, pc, head, month) · Rate per unit** (hidden for receipt/payment), **Total amount (Rs)** — qty×rate fills total; editing total recalculates rate (bulk pricing). Paid now | Not received yet (udhaar / AR) / Not paid yet (AP) for sale/purchase/expense. Note. Primary **Save & sync to Sheets**. Validation: party and amount required.
Categories — Sale: Milk, Dahi, Butter, Ghee, Lassi, Paneer, Cream, Khoya, Cattle sale, Dung / manure, Other sale. Purchase: Fodder / feed, Cattle purchase, Equipment, Vet & medicine, Food & kitchen, Other purchase. Expense: Salaries, Rent, Utilities (bijli, gas, pani), Food & kitchen, Transport, Vet & medicine, Repairs, Equipment, Fodder / feed, Other expense. Receipt: Udhaar receipt, Advance, Other receipt. Payment: supplier/rent/utility/salary categories, Other payment.

### 8. Co-founders (Master, Co-founder)
Card "Total capital · N co-founders", stacked ratio bar (accent-700/500/400/300), note "Share ratio follows investment. Reinvested profit raises a partner's ratio automatically." Per co-founder card: colour dot, name, ratio tag, "You" tag, Invested / Reinvested / Withdrawn; Master only: number input + **Add** (adds investment). List "Closed months": month, "AR counted/rolled", profit.

### 9. Products & rates (Co-founder tab; Master via More)
Row per item: 88 px photo, name, "Rs [input] / unit", **Remove**. Card "Add item": Name, Rate, Unit (L/kg/pc/dozen), **Add to shop**. Every change is logged and synced.

### 10. More (Master)
Rows: Products & rates, Users & roles, Udhaar registrations, Activity log, Google Sheets (opens sheet URL). Footer "Signed in as …".

### 11. Users (Master)
Card per user (blocked at 55% opacity): name, email, status tag (Active/Pending/Blocked), role select (Co-founder/Customer), **Approve** (pending) or **Block/Unblock**, **Reset** (sends password-reset / re-auth link).

### 12. Activity log (Master)
Row: time, "Who what", kind tag (Login, Order, Transaction, Month close, Investment, User, Udhaar, Products). Newest first, infinite scroll.

### 13. Udhaar registrations (Master via More; Co-founder via Approvals list)
Card: name, status tag, address, mobile · slot · litres/day · limit, approval text, **Approve udhaar**.

### 14. Co-founder Home
Card "Your share · X%": projected share (36 px) "from Rs P profit to date". 2 cards: Your capital (incl. reinvested), Farm balance (AR/AP). List "Awaiting approval" (orders + registrations). List "Your profit history": month, Reinvested/Withdrawn tag, amount.

### 15. Shop (Customer)
Banner card: udhaar state (Not registered / Pending approval / Approved with due amount & limit). 2-column product grid: 4:3 photo, name (17 px), "Rs price / unit", − qty + stepper (32 px buttons).

### 16. Checkout (Customer)
Lines + total; Fulfilment: Home delivery | Farm pickup; Time slot: Morning 6–9 | Evening 5–8; Repeat: One-off | Daily; Payment radios: Cash on delivery, Bank transfer (show account), JazzCash / EasyPaisa (show number), Monthly udhaar (disabled unless approved; blocked if it would exceed limit). Primary **Place order · Rs X**. Placing → status New, all co-founders notified, customer sees My orders.

### 17. My orders (Customer)
Same order card without action buttons.

### 18. Udhaar account (Customer)
Card: status tag; if approved: balance due (30 px), "limit Rs L · billed when the farm closes the month". If not registered: form — Full name, Complete address (multiline), Mobile number, Delivery timing (Morning/Evening), Milk per day (litres), estimate "litres × milk rate × 30", primary **Request udhaar account**. Pending: confirmation text.

## Business rules
- **Share ratio** = (invested + reinvested) / Σ(invested + reinvested) across partners. Recompute on every investment add and month close.
- **Profit MTD** = Σ sales − Σ purchases − Σ expenses for the open month (paid or not). **Cash** = opening cash + paid sales + receipts − paid purchases/expenses − payments. **AR** = unpaid sales. **AP** = unpaid purchases + expenses.
- **Month close** (Master): profitToShare = arIncluded ? profit : profit − AR. For each partner share = round(profitToShare × ratio). choice `reinvest` → partner.reinvested += share; `withdraw` → partner.withdrawn += share and a `payment` transaction "Profit share – Name" is posted. Write `month_closes` record, mark month closed, open next month; unpaid items carry forward. Log + Sheets + notify all co-founders. Customer udhaar bills are generated at close (sum of their unpaid udhaar sales that month).
- **Approvals**: order or registration is approved by the first co-founder/master who taps Approve; record `approvedBy`, `approvedAt`; notify all co-founders (push + in-app; WhatsApp deep link offered to the approver).
- **Udhaar limit**: suggested default = litres × milk rate × 30 × 1.2 rounded to Rs 1,000; master may edit. Order on udhaar rejected if balance + total > limit.
- **Daily orders**: repeat = Daily creates a subscription; a scheduled Cloud Function creates the day's order at 04:00 PKT for the chosen slot.
- Currency PKR, format `Rs 1,23,456` (en-PK grouping). Timezone Asia/Karachi.

## Data model (Firestore)
```
users/{uid}            {name, email, photoUrl, role: master|investor|customer, status: pending|active|blocked, partnerId?, fcmTokens[], createdAt}
partners/{id}          {userId, name, invested, reinvested, withdrawn, createdAt}
products/{id}          {name, unit, price, photoUrl, active, sortOrder, updatedBy, updatedAt}
transactions/{id}      {date, monthId, type: sale|purchase|expense|receipt|payment, party, customerId?, category, qty?, unit?, rate?, amount, paid, paidAt?, note, orderId?, createdBy, createdAt, deletedAt?}
orders/{id}            {number, customerId, customerName, items:{productId:{qty,price,name,unit}}, total, mode: delivery|pickup, slot: morning|evening, repeat: once|daily, pay: cod|bank|jazzcash|udhaar, status: new|preparing|out|delivered|cancelled, approvedBy?, approvedAt?, deliveredAt?, createdAt}
subscriptions/{id}     {customerId, items, slot, mode, pay, active}
udhaar_accounts/{uid}  {name, address, mobile, slot, litresPerDay, limit, balance, status: pending|approved|rejected, approvedBy?, approvedAt?}
months/{id YYYY-MM}    {status: open|closed, openingCash, closedAt?, arIncluded?, profit?, shares:[{partnerId, ratio, share, choice}]}
settings/farm          {name, milkPriceCache, bankAccount, jazzcashNumber, sheetId, whatsappNumbers[]}
logs/{id}              {at, uid, who, kind, what, refType?, refId?}
```
Security rules: role read from `users/{uid}.role`; master-only: transaction delete, partners, months, users; co-founder + master: transaction create/update (mark paid), products, order status, approvals; customers write only their own orders/udhaar registration.

## Google Sheets sync
Sheet: `https://docs.google.com/spreadsheets/d/1LYzuttkPAwP5CyqBOAQle5qd6uMp1zbHrUzei8m53Ws`
Setup: enable Google Sheets API in the Firebase project's Google Cloud console → create a service account → share the sheet with its email as Editor → store the key in Cloud Functions secrets. Firestore `onWrite` triggers append/update rows (one tab per collection, first column = document id, upsert by id):
- **Transactions**: id, date, month, type, party, category, qty, unit, rate, amount, paid, paidAt, note, orderId, createdBy, createdAt, deleted
- **Orders**: id, number, date, customer, items (text), total, mode, slot, repeat, payment, status, approvedBy, deliveredAt
- **Partners**: id, name, invested, reinvested, withdrawn, ratio%
- **MonthClose**: month, sales, purchases, expenses, AR, arIncluded, profitShared, partner1..4 share, partner1..4 choice, closedBy, closedAt
- **Udhaar**: uid, name, mobile, address, slot, litres, limit, balance, status, approvedBy
- **Users**: uid, name, email, role, status, createdAt
- **Log**: at, who, kind, what
Show "Sheets synced" tag when the last sync succeeded; retry with backoff on failure and surface "Sync pending".

## Notifications
FCM topic `cofounders` for: new order, new udhaar registration, order approved, month closed, investment added, new user sign-up (master only). Customer gets: order approved, out for delivery, delivered, udhaar approved, monthly bill.

## Design tokens (from logo)
Fonts: headings Barlow Condensed 600, body Barlow 400/500 (Google Fonts).
Colours: bg #f6f2ec · surface #ece5db · text #221b15 · accent #9a6a3f (bronze) · accent-2 #b98a4d (gold) · divider rgba(34,27,21,.16)
Accent ramp 100→900: #f9f1e6 #f0dfc8 #e2c5a0 #cba475 #ad8351 #8f683c #6e4f2c #4d371e #2f2214
Neutral ramp 100→900: #f8f5f1 #ebe6df #d8d1c8 #bab2a8 #9a9187 #7a7168 #5c554d #413b35 #2a2521
Shape: square corners (radius 0–4 px), hairline 1 px borders, "+" registration marks at card/primary-button corners, transparent cards, solid accent primary button with light text, thin-stroke Lucide icons (1.5). Photos: warm duotone.
Type scale: title 44, screen title 22, card number 36/30/28/22, card title 17, body 14, meta 12, kicker 11 uppercase 0.12em.
Min tap target 44 px (prototype uses 32 px steppers — enlarge to 44).

## Assets
- `assets/logo.png` — farm logo (user supplied).
- Product photos: to be supplied by the farm; upload via Products screen to Firebase Storage.

## Deployment checklist
1. Firebase project → enable Google Auth, Firestore, Storage, Functions, Messaging; add Android app with the release SHA-1.
2. Flutter project in repo root; `flutterfire configure`.
3. GitHub Actions: `flutter build apk --release` (keystore + passwords as repo secrets) → upload to Release. Co-founders install from the Release page; later publish to Google Play (internal testing → production).
4. Seed `settings/farm`, `products`, `partners`, and set the first user's role to `master` manually in Firestore.

## Files
- `Char Yar Dairy Farm.dc.html` — the clickable prototype (open in a browser).
- `support.js`, `android-frame.jsx`, `image-slot.js`, `_ds/` — prototype runtime and design-system stylesheet.
- `assets/logo.png`
