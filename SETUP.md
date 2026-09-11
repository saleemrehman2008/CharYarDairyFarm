# Setup — Char Yar Dairy Farm (Roman Urdu)

Yeh file shuru se aakhir tak ka rasta hai. Har step ke baad jo cheez banti hai,
uska naam likha hua hai — wahi agle step mein chahiye hoti hai.

Jo cheezein sirf aap kar sakte hain (browser/console wala kaam) wo yahan hain.
Code pehle se repo mein mojood hai.

---

## Step 1 — Firebase project

1. [console.firebase.google.com](https://console.firebase.google.com) kholein →
   **Add project** → naam: `Char Yar Dairy Farm` → Continue → Google Analytics
   off kar dein (zarurat nahi) → **Create project**.

2. **Build → Authentication → Get started → Sign-in method → Google → Enable.**
   - "Project support email" mein apna email chunein.
   - Save.

3. **Build → Firestore Database → Create database**
   - **Production mode** chunein.
   - Location: **asia-south1 (Mumbai)**.
   - Create. (Location baad mein nahi badalti — dhyan se chunein.)

4. **Build → Storage → Get started** → Production mode → wahi region →
   Done. (Product ki photos yahan jaati hain.)

5. **Project settings (gear) → General → Your apps → Add app → Android**
   - Android package name: `com.charyar.dairyfarm` ← bilkul yehi, spelling
     important hai.
   - App nickname: `Char Yar Dairy Farm`
   - **Register app** → **google-services.json** download karein.

**Banta hai:** `google-services.json` file.

### google-services.json kahan rakhein

Do jagah:

- **Local** (apni machine par app chalane ke liye):
  file ko `android/app/google-services.json` par copy karein.
  Yeh `.gitignore` mein hai, GitHub par nahi jayegi — theek hai, repo public hai.

- **GitHub** (CI ko APK banane ke liye) — Step 4 mein secret ke tor par.

---

## Step 2 — SHA-1 (Google sign-in ke liye)

Google sign-in ke liye Firebase ko aapki app ki signing fingerprint chahiye.

### Pehle keystore banayein (ek hi dafa)

Apne terminal mein:

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

- Password pooche to ek mazboot password dein aur **likh kar rakh lein** —
  yeh kho gaya to aap kabhi is app ko update nahi kar sakenge.
- Naam, sheher waghera kuch bhi chalega.

**Banta hai:** `upload-keystore.jks` + store password + key password + alias
(`upload`).

> ⚠️ Yeh file kisi ko na bhejein aur GitHub par commit na karein. Ek backup
> Google Drive par rakh lein.

### SHA-1 nikalein

```bash
keytool -list -v -keystore upload-keystore.jks -alias upload
```

Output mein `SHA1:` aur `SHA256:` dikhenge. Dono copy karein.

Debug (apni machine par test karne wali) fingerprint ke liye:

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

Windows par path `%USERPROFILE%\.android\debug.keystore` hota hai.

### Firebase mein daalein

**Project settings → General → Your apps → Android app → Add fingerprint** —
release SHA-1, release SHA-256, aur debug SHA-1, teeno add karein.

Uske baad **google-services.json dobara download karein** (ab us mein OAuth
client shamil hoga). Purani file replace kar dein.

---

## Step 3 — Google Sheet connect

1. Firebase console mein project ke saath hi Google Cloud project banta hai.
   [console.cloud.google.com](https://console.cloud.google.com) kholein, upar
   se wahi project chunein (`Char Yar Dairy Farm`).

2. **APIs & Services → Library → "Google Sheets API" search → Enable.**

3. **IAM & Admin → Service Accounts → Create service account**
   - Name: `charyar-sheets`
   - Create and continue → role ki zarurat nahi → Done.
   - Ab us service account par click → **Keys → Add key → Create new key →
     JSON → Create.** File download ho jayegi.

**Banta hai:** service account ki JSON key, aur uska email jo aisa dikhta hai:
`charyar-sheets@<project-id>.iam.gserviceaccount.com`

4. Apni Google Sheet kholein →
   [sheet link](https://docs.google.com/spreadsheets/d/1LYzuttkPAwP5CyqBOAQle5qd6uMp1zbHrUzei8m53Ws)
   → **Share** → upar wala service account email paste karein → role **Editor**
   → Send. (Notification ka checkbox hata dein.)

5. Sheet ke tabs khud ban jate hain — Cloud Function pehli dafa likhte waqt
   `Transactions`, `Orders`, `Partners`, `MonthClose`, `Udhaar`, `Users`, `Log`
   tabs apne aap bana kar header row daal deti hai. Haath se banane ki zarurat
   nahi.

6. Sheet ka ID URL ke beech wala lamba hissa hai:
   `https://docs.google.com/spreadsheets/d/` **`1LYzutt...53Ws`** `/edit`

---

## Step 4 — GitHub secrets

Repo kholein → **Settings → Secrets and variables → Actions → New repository
secret**. Yeh paanch banayein:

| Secret | Kya daalna hai |
|---|---|
| `GOOGLE_SERVICES_JSON` | `google-services.json` ka **base64** |
| `KEYSTORE_BASE64` | `upload-keystore.jks` ka **base64** |
| `KEYSTORE_PASSWORD` | keystore ka store password |
| `KEY_PASSWORD` | key ka password |
| `KEY_ALIAS` | `upload` |

base64 banane ka tareeqa —

**Windows (PowerShell):**

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("google-services.json")) | Set-Clipboard
```

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks")) | Set-Clipboard
```

**Mac / Linux:**

```bash
base64 -w0 google-services.json | pbcopy
```

Clipboard se secret ke box mein paste kar dein.

Ab `main` par jo bhi push hoga, GitHub Actions khud signed APK bana kar
**Releases** page par laga dega.

---

## Step 5 — Firebase rules aur Cloud Functions deploy

Apni machine par ek dafa:

```bash
npm install -g firebase-tools
firebase login
```

Repo ke folder mein:

```bash
firebase use --add
```

(apna project chunein, alias `default` likh dein)

### Rules aur indexes

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage
```

### Cloud Functions

Functions ke liye project **Blaze (pay as you go)** plan par hona chahiye —
Firebase console mein neeche **Upgrade** se. Dairy farm ke traffic par kharcha
taqreeban zero rehta hai, lekin card add karna zaroori hai.

> Functions na hon to app phir bhi poora kaam karti hai — sirf Google Sheet
> mirror, push notifications aur roz khud-ba-khud banne wale daily orders nahi
> chalenge.

Service account key ko secret banayein (Step 3 wali JSON file):

```bash
firebase functions:secrets:set SHEETS_SA_KEY
```

Command poocheygi to us JSON file ka **poora content** paste karein, phir
`Ctrl+D` (Windows par `Ctrl+Z` phir Enter).

Sheet ID bhi batayein — `functions/.env` file banayein:

```
SHEET_ID=1LYzuttkPAwP5CyqBOAQle5qd6uMp1zbHrUzei8m53Ws
```

Phir:

```bash
cd functions && npm install && cd ..
firebase deploy --only functions
```

---

## Step 6 — Pehla login aur master banna

1. APK install karein — GitHub → **Releases** → sab se upar wali release →
   `.apk` file download → phone par install ("Unknown sources" allow karna
   padega).

2. App kholein → **Continue with Google** → **Saleemrehman2008@gmail.com** se
   sign in karein.

   App kahegi "account approval ka intezar hai" — yeh normal hai.

3. **Firestore console → Data → `users` collection → apna document kholein**
   (document ka naam aapka uid hai, email se pehchan lein). Do field badlein:

   - `role` → `master`
   - `status` → `active`

   Save. App khud refresh ho kar master dashboard dikha degi — dobara sign in
   karne ki zarurat nahi.

4. **Shop mein items daalein:** More → Products & rates → "Add item" se
   `Fresh milk` (Rs rate, unit `L`), `Dahi` (`kg`) waghera add karein. Har item
   par photo lagane ke liye khali photo box par tap karein.

5. **Bank details daalein** (customer ko checkout par dikhti hain) — Firestore
   console → `settings` collection → `farm` document (na ho to banayein) →
   yeh fields add karein:

   | Field | Type | Value |
   |---|---|---|
   | `name` | string | `Char Yar Dairy Farm` |
   | `sheetId` | string | sheet ka ID |
   | `bankAccount` | string | `Meezan — 0123456789 (Saleem Rehman)` |
   | `jazzcashNumber` | string | `0300 1234567` |
   | `whatsappNumbers` | array of string | co-founders ke number, `03001234567` |
   | `milkPriceCache` | number | `200` |

6. **Co-founders add karein:**
   - Teeno co-founders ko app install kara kar Google se sign in karwayein.
   - Aap: **More → Users & roles** → har ek ka role **Co-founder** kar dein aur
     **Approve** dabayein. Role badalne par unka partner record khud ban jata
     hai.
   - Phir **Co-founders** tab → har ek ke card par "Add investment" mein unki
     raqam daal kar **Add** dabayein. Share ratio khud calculate ho jata hai.

---

## Step 7 — Test plan (co-founders ke sath)

Ek-ek kar ke yeh chalayein. Har step ke baad Google Sheet mein row check
karein.

1. **Order ka poora safar**
   - Kisi customer account se shop se 4 L milk order karein (Cash on delivery).
   - Co-founder ke phone par notification aani chahiye.
   - Co-founder **Approvals** tab se **Approve** dabaye.
   - Phir **Mark preparing → Mark out for delivery → Mark delivered.**
   - Delivered hone par `Accounts` mein ek **sale** entry khud aa jani chahiye,
     aur Sheet ke `Orders` + `Transactions` tabs mein rows.

2. **Udhaar sale aur unpaid rent**
   - Accounts → **Add** → type **Sale**, party "Ahmed", amount 5,000,
     "Not received yet (udhaar / AR)" → Save.
   - Ek aur: type **Expense**, category **Rent**, amount 15,000,
     "Not paid yet (AP)" → Save.
   - Home par **Accounts receivable** 5,000 aur **Accounts payable** 15,000
     dikhna chahiye.
   - Sheet ke `Transactions` tab mein dono rows, `paid` column `FALSE`.
   - Ab dono par **Mark paid** dabayein → har ek ke saamne ek naya
     receipt/payment row bane ga aur `paid` `TRUE` ho jayega.

3. **Rate change**
   - Products & rates mein milk ka rate badlein.
   - Customer ke phone par shop mein naya rate foran dikhna chahiye.

4. **Month close**
   - Home → **Close <month> & share profit**.
   - "Uncollected receivables" mein dono option aazma kar dekhein ke
     "Profit to share" kaise badalta hai.
   - Ek co-founder ko **Withdraw**, doosre ko **Add to investment** dein →
     **Close month & post shares** → confirm.
   - Check karein: Co-founders tab mein ratios badle (reinvest wale ka barha),
     "Closed months" list mein naya row, Sheet ke `MonthClose` tab mein row,
     aur Withdraw wale ke liye `Transactions` mein ek payment row
     "Profit share – <naam>".
   - Unpaid entries agle month mein carry forward honi chahiye.

5. **Blocked user**
   - Users mein kisi test account ko **Block** karein → us phone par app
     agle refresh par sign out ho jani chahiye.

---

## Kuch ghalat ho jaye to

| Masla | Wajah / Hal |
|---|---|
| Sign-in par "Could not sign in" | SHA-1 Firebase mein add nahi hua, ya `google-services.json` purana hai. Step 2 dohrayein, naya file lein, phir `GOOGLE_SERVICES_JSON` secret update karein. |
| App khulte hi crash | `android/app/google-services.json` maujood nahi. |
| "Missing or insufficient permissions" | Rules deploy nahi hue (Step 5), ya aapka `users` document mein `status` `active` nahi hai. |
| Sheet mein kuch nahi aa raha | Functions deploy nahi hue, ya `SHEETS_SA_KEY` galat hai, ya sheet service-account email ke sath Editor ke tor par share nahi ki. Top bar par "Sync pending" tag dikhega. `firebase functions:log` se error dekhein. |
| GitHub Actions red | Actions tab → failed run → log dekhein. Aksar koi secret missing hota hai; error message secret ka naam bata deta hai. |
| APK install nahi ho raha | Phone par "Install unknown apps" us browser/file manager ke liye allow karein. |
| Month close ke baad ratios nahi badle | Reinvest chuna tha? Withdraw se ratio nahi badalta, sirf reinvest se barhta hai. |

---

## Rozana ka kaam

- **Har sale/kharcha** — Accounts → Add. Udhaar wali cheez "Not received yet"
  par chhor dein; paisa aane par **Mark paid**.
- **Orders** — jo co-founder pehle Approve dabaye, wohi record ho jata hai;
  baaqi sab ko notification chala jata hai.
- **Mahine ke aakhir** — Home se month close karein. Ek hi dafa hota hai, so
  pehle Accounts mein dekh lein ke sab entries daal di hain.
- **Activity log** (More mein) har cheez ka record rakhta hai — kis ne kya kiya.
