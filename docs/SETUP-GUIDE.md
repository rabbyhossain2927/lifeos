# LifeOS — setup guide, step by step

You don't need a computer program, Flutter or Android Studio. GitHub builds the app in the cloud. Do the parts in order. The first time takes about 40 minutes. After that, an update takes 2 minutes of your time.

**What lives where**

| Thing | Where | Cost |
|---|---|---|
| Sign in / sign up | Google, through Firebase | Free |
| Your data (goals, habits, journal…) | Your own hosting (cPanel), in a MySQL database | Your hosting |
| The app code and the APK files | GitHub repo `rabbyhossain2927/lifeos` | Free |
| Pro license keys | Your shop, shop.rabbyhossain.com | — |

**Two private things you received from Claude. Never share them, never upload them:**

- `LifeOS-signing-secrets.txt`: the **signing password** and the **SHA fingerprints**.
- `lifeos-upload-keystore.jks`: a backup of the app's signing key. Save it in your Google Drive. If you lose it, phones can't install updates.

---

## Part 1 — Make the Firebase project (Google sign-in only, 10 min)

1. Open **console.firebase.google.com** and sign in with your Google account.
2. Tap **Create a project**. Name: `LifeOS`. Turn **Google Analytics off**. Tap **Create project**, then **Continue**.
3. In the left menu: **Build → Authentication → Get started**.
   - Tap **Google** → turn on **Enable** → pick your email as support email → **Save**.
   - Tap **Google** again, open **Web SDK configuration**, and copy the **Web client ID** (it ends with `.apps.googleusercontent.com`). Keep it for Part 3.
4. You do **not** need Firestore or Realtime Database. Your data goes to your own server (Part 2).
5. Go to the project home (house icon) and tap the **Android** icon (**Add app**):
   - **Android package name:** `com.rabby.lifeos` (exactly this)
   - **App nickname:** LifeOS
   - **Debug signing certificate SHA-1:** paste the **SHA-1** from `LifeOS-signing-secrets.txt`
   - Tap **Register app**. **Skip** the download of google-services.json and **skip** the next steps (tap Next, Next, Continue to console).
6. Tap the **gear icon → Project settings**. Scroll to **Your apps → LifeOS**, tap **Add fingerprint**, paste the **SHA-256** from the secrets file, **Save**.
7. On the same **General** page, copy these 4 values:
   - **Web API Key**
   - **Project ID**
   - **Project number**
   - **App ID** (under Your apps, starts with `1:` and has `android` in it)

## Part 2 — Put the sync server on your hosting (15 min)

1. **Create the database.** cPanel → **MySQL Databases**.
   - New database: `lifeos` (cPanel shows the full name, like `rabbyhos_lifeos`).
   - New user with a strong password (save it).
   - **Add user to database** → tick **ALL PRIVILEGES** → **Make changes**.
2. **Get the server files.** On your phone/PC open `github.com/rabbyhossain2927/lifeos` → green **Code** button → **Download ZIP**.
3. **The subdomain.** cPanel → **Domains** (or **Subdomains**) → make sure **lifeos.rabbyhossain.com** exists and note its **Document Root** folder (for example `lifeos.rabbyhossain.com` or `public_html/lifeos`). Then cPanel → **SSL/TLS Status** → tick it → **Run AutoSSL**, so it opens with `https://`.
4. **Upload.** cPanel → **File Manager** → open the subdomain's Document Root folder → **Upload** the ZIP → right-click it → **Extract**.
   Open `lifeos-main/server/lifeos-api`, **Select all** (turn on **Settings → Show hidden files** first, so `.htaccess` and `.user.ini` are included) → **Move** them into the Document Root folder itself. Delete the empty `lifeos-main` folder and the ZIP.
   The Document Root should now hold `sync.php`, `lib.php`, `.htaccess`, the `cache` folder and the rest.
5. **Settings file.** In the Document Root, copy `config.sample.php` and name the copy `config.php`. Edit it:
   - `db_name` and `db_user`: the FULL names from step 1
   - `db_pass`: the password from step 1
   - `firebase_project_id`: the **Project ID** from Part 1, step 7
   - Save.
6. **Create the table.** Open `https://lifeos.rabbyhossain.com/install.php` in your browser. It must say `"ok":true`. Then **delete `install.php`** in File Manager.
7. **Check it.** Open `https://lifeos.rabbyhossain.com/health.php`. The last line must say `"all_good":true`.
   - `google_keys` false → ask hosting support to allow outgoing HTTPS to `www.googleapis.com`.
   - `cache_writable` false → set folder `cache` permission to 755.

The server keeps itself up to date from GitHub automatically (every 6 hours). You never upload server files again.

## Part 3 — Give Claude your 5 values

Send these in the chat and Claude puts them in the code and builds the app:

1. Web API Key
2. Project ID
3. Project number
4. App ID
5. Web client ID

(If you want to do it yourself: on GitHub open `lib/firebase_options.dart` and `lib/config.dart`, tap the ✏️ pencil, replace each `PASTE-...` text, and **Commit changes**.)

## Part 4 — Add the signing password to GitHub (one time, 2 min)

The app's signing key is in the repo, locked with a password. GitHub needs the password to sign each new version.

1. Open `github.com/rabbyhossain2927/lifeos` → **Settings** → **Secrets and variables** → **Actions**.
2. Tap **New repository secret**.
   - **Name:** `SIGNING_PASSWORD`
   - **Secret:** the signing password from `LifeOS-signing-secrets.txt`
3. Tap **Add secret**.

## Part 5 — Create the Pro product in your shop (5 min)

1. In your shop admin, add a new product: **LifeOS Pro**.
2. Set the product link (slug) to exactly **`lifeos`**, so the page is `shop.rabbyhossain.com/p/lifeos`.
3. Turn on **license keys** for it, like your plugins. Choose how many phones one key allows (2 is a good number).
4. Set your price and publish.

The app calls your License API (`/api/license/activate`, `/check`, `/deactivate`) with `product=lifeos`.

**What Pro unlocks** (change the list in `lib/services/license_service.dart`): Weekly report, Rewards, Memory, Travel, Voice notes. Everything else is free.

## Part 6 — Build and install the first version (15 min, mostly waiting)

1. On GitHub open **Actions** → **Build & release LifeOS** → **Run workflow**.
2. Version: `1.0.0`. Leave **Publish** ticked. Tap **Run workflow**.
3. Wait 10–15 minutes for the green tick. (Red ✗? Tell Claude, Claude fixes it.)
4. On your phone open `github.com/rabbyhossain2927/lifeos/releases` → tap **LifeOS-v1.0.0.apk**.
5. Open the download → Android asks to **allow installs from this source** → **Settings → Allow** → back → **Install**.
6. Open LifeOS → **Continue with Google**. The first time, this creates your account. 🎉

On another phone, install the same APK and sign in with the same Google account: all your data appears.

## Part 7 — Send an update to every phone (the auto update system)

1. Ask Claude for the fix or feature, or edit the code on GitHub yourself.
2. Write what changed in `RELEASE_NOTES.md`:

   ```markdown
   ## New
   - Something new

   ## Fixed
   - Something fixed
   ```

3. **Actions → Build & release LifeOS → Run workflow** → type a **higher** version (`1.0.1`, `1.0.2` … for fixes, `1.1.0` for features).
4. About 10 minutes later every phone with LifeOS:
   - checks when the app opens (at most every 3 hours),
   - shows a notification **"LifeOS 1.0.1 is ready"** and an **Update ready** popup,
   - downloads and opens the installer when you tap **Update now**.
   Data is never lost: it lives on your server and on the phone, not in the APK.
   You can also check by hand: **Profile → App updates → Check**.

## Part 8 — How to use the license (for your buyers)

1. Buyer pays in your shop and gets a key.
2. In LifeOS: **Explore → any 🔒 item**, or **Profile → Unlock LifeOS Pro** → enter the key → **Activate**.
3. The key is saved to their Google account, so every phone they sign in on is unlocked.
4. To move to a new phone limit: **Profile → LifeOS Pro is on → Remove key from this account**.
5. If you refund or block a key in the shop, the app locks Pro again on its next check.

## Troubleshooting

- **"Almost ready" page in the app:** Part 3 values are missing. Send them to Claude.
- **Google sign-in error 10 / DEVELOPER_ERROR:** the SHA-1 or SHA-256 in Firebase is wrong or missing (Part 1, steps 5–6), or the app was built without the `SIGNING_PASSWORD` secret (Part 4).
- **Profile → Sync says "Token is for another Firebase project":** `firebase_project_id` in `config.php` must be your Project ID.
- **Sync says "Database connection failed":** check `db_name`, `db_user`, `db_pass` in `config.php` (use the full cPanel names).
- **Server replies with a web page instead of data:** your hosting firewall (Imunify360 / Cloudflare) blocks it. Ask support to whitelist `lifeos.rabbyhossain.com`.
- **Update downloads but "App not installed":** a build was signed with a different key. Always keep the same `SIGNING_PASSWORD` secret and never change the `.enc` file.
- **Build has a red ✗ with "Add the SIGNING_PASSWORD secret":** do Part 4.
- **License says it can't reach the shop:** check `shop.rabbyhossain.com/api/license/check?key=TEST` opens in a browser.

## What is not in this first version

- **Do not disturb, app blocker and screen time** (Focus page): need special Android permissions. For now the page tells you to turn on Do Not Disturb yourself.
- **AI task breakdown:** steps are added by hand for now (no AI key in the app).
- **Home screen widgets:** planned for a later version.
- **Google Drive backup:** not needed for now, because your data is already on your own server and your phone.
- **Photos** (photo of the day): stay on the phone where you took them. They don't sync yet.
- **Steps and weight:** typed in by hand (no step counter yet).
