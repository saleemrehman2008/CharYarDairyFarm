# Char Yar Dairy Farm

Android app for a four-partner dairy farm in Pakistan. It records sales,
purchases, expenses, receivables and payables, takes customer orders, closes
each month and splits the profit by investment ratio, keeps a full activity log,
and mirrors every record to a Google Sheet.

Built from the design handoff in
[`design_handoff_char_yar_dairy_farm/README.md`](design_handoff_char_yar_dairy_farm/README.md) —
that file is the spec; this one is how the code is put together.

**Setting the project up for the first time?** Follow
[SETUP.md](SETUP.md) (Roman Urdu, step by step).

## Stack

| Piece | Choice |
|---|---|
| App | Flutter 3.47.3, Android first |
| Sign-in | Firebase Auth with Google |
| Data | Cloud Firestore |
| Photos | Firebase Storage |
| Push | Firebase Cloud Messaging, topic `cofounders` |
| Sheets mirror, daily orders, notifications | Cloud Functions (TypeScript, Node 22) |
| Build & distribution | GitHub Actions → signed APK on a GitHub Release |

State is `provider`. There is no code generation step — models parse Firestore
maps by hand in `lib/models/`, so the build is just `flutter build apk`.

## Roles

New Google sign-ins land as `customer` / `pending`. They can browse the shop but
not order until the master approves them. The master promotes an account to
`investor` (co-founder), which also creates its `partners` record.

| | Master | Co-founder | Customer |
|---|---|---|---|
| Dashboard, accounts, orders | ✓ | ✓ | – |
| Approve orders & udhaar (any one of them) | ✓ | ✓ | – |
| Add entries, mark paid | ✓ | ✓ | – |
| Delete entries | ✓ | – | – |
| Products & rates | ✓ | ✓ | – |
| Add investment, close month, manage users | ✓ | – | – |
| Activity log | ✓ | – | – |
| Shop, cart, orders, udhaar | – | – | ✓ |

The same rules are enforced server-side in [`firestore.rules`](firestore.rules)
— the app never relies on hiding a button.

## Layout

```
lib/
  main.dart              Firebase init + AuthGate (role -> home screen)
  theme/                 tokens.dart is the single source for colour and type
  models/                Firestore documents as Dart classes
  services/              db.dart reads; *_repo.dart write; accounting.dart derives
  state/                 session, farm_store, customer_store, cart
  widgets/               RegCard, PrimaryButton, Segmented, app shell, order card
  screens/
    master/ cofounder/ customer/ shared/
functions/src/           Sheets mirror, push, daily subscription orders
firestore.rules          Role enforcement
storage.rules            Product photos
.github/workflows/       Signed APK on every push to main
```

### Where the numbers come from

Nothing financial is stored twice. [`accounting.dart`](lib/services/accounting.dart)
derives every figure from the ledger, so correcting one entry corrects every
card that shows it:

- **Profit MTD** = sales − purchases − expenses for the open month, paid or not
- **Cash** = opening cash + paid sales + receipts − paid purchases/expenses − payments
- **AR** = unpaid sales, **AP** = unpaid purchases and expenses, across all months
- **Share ratio** = (invested + reinvested) ÷ total capital, recomputed on read

Closing a month (`MonthRepo.close`) posts each partner's share — `reinvest`
raises their capital, `withdraw` also books a `payment` row — opens the next
month with the cash actually left, and bills each udhaar customer. Unpaid
entries are never touched: they carry forward.

## Running it

```bash
flutter pub get
flutter run
```

You need `android/app/google-services.json` from your own Firebase project
first; see [SETUP.md](SETUP.md). Android reads its Firebase configuration from
that file, so there is no generated `firebase_options.dart`. Run
`flutterfire configure` if you add iOS later.

Cloud Functions:

```bash
cd functions
npm install
npm run build
firebase deploy --only functions
```

Functions need the Blaze plan. The app works without them — you just lose the
Sheets mirror, push notifications and automatic daily orders.

## Deployment checklist

1. Firebase project with Google Auth, Firestore (`asia-south1`), Storage,
   Functions and Messaging; Android app registered as `com.charyar.dairyfarm`
   with the release SHA-1 added.
2. Repository secrets: `GOOGLE_SERVICES_JSON`, `KEYSTORE_BASE64`,
   `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`.
3. Functions secret `SHEETS_SA_KEY` (service-account JSON) and parameter
   `SHEET_ID`.
4. `firebase deploy --only firestore:rules,firestore:indexes,storage`.
5. Seed `settings/farm` and `products`, then set your own
   `users/{uid}.role = "master"` and `status = "active"` by hand in the console.

Every step above is spelled out with screenshots-worth of detail in
[SETUP.md](SETUP.md).

## Fonts

Barlow and Barlow Condensed are bundled in `assets/fonts/` under the SIL Open
Font License (see `assets/fonts/OFL.txt`), so the app needs no network on first
run to render correctly.
