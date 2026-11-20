# Vaccinators App v1 — Build, Host, Install, Update (FREE)

**No Play Store. No $25. No paid service.** Everything below is free: Flutter + GitHub Actions + GitHub Pages + Google Sheets + Apps Script.

## What is in this folder

| Path | What it is |
|---|---|
| `files/Vaccinators-App-v1-Design.md` | Screen-by-screen design — approve this first |
| `files/preview/index.html` | Clickable preview of the main screens (open in any browser, no install) |
| `flutter_app/` | Complete Flutter project (v1 source) — languages: Urdu (proper script) / English only, no Roman Urdu; Urdu font: Noori Nastaliq (Noto Nastaliq Urdu fallback — user supplies the Noori file, see `flutter_app/assets/fonts/README.md`). Calls entry wired: 📞 Calls card on Home → contacts list (roster + admin); placing a call still needs Firebase signalling — see GOAL.md V2 Calling |
| `files/forms.json` | The live list of Google Forms shown in the app — edit this file ONLY to publish a new form (Step 7), no APK update |
| `.github/workflows/build-apk.yml` | Free GitHub Actions workflow that builds the release APK |
| `GOAL.md` | Plan, backend, decisions, open items |

## Step 1 — Approve the design
1. Open `files/preview/index.html` in a browser (or read `files/Vaccinators-App-v1-Design.md`).
2. Tick the approval checklist at the end of the design doc. Tell Muse what to change, if anything.

## Step 2 — Push the code to GitHub (needs your approval first — nothing is pushed yet)
Recommended: a **new repo** `dhachakwal/vaccinators-app` (keeps the app separate from the website repo).

```bash
cd ~/workspace/goals/vaccinators-app-flutter-apk-v1/flutter_app
git init
git add .
git commit -m "Vaccinators App v1 — Flutter APK (Chakwal EPI)"
git branch -M main
git remote add origin https://github.com/dhachakwal/vaccinators-app.git
git push -u origin main
# Also copy .github/workflows/build-apk.yml to the repo root before pushing,
# or push the whole goal folder as the repo root.
```

The workflow file must be at `<repo>/.github/workflows/build-apk.yml` for Actions to find it.

## Step 3 — The free APK build (GitHub Actions)
1. On push to `main`, Actions runs `build-apk.yml`: installs Flutter (stable), runs `flutter pub get`, `flutter analyze`, `flutter build apk --release`.
2. Watch it at: repo → **Actions** tab → latest run. Green tick = APK built.
3. Download the APK: run → **Artifacts** → `vaccinators-app-v1-apk` (free, kept 30 days), or from the **Release** the workflow creates (`v1.0.0` etc.).
4. **No APK exists until this run is green.** If it is red, open the failed step log and tell Muse the error — do not share a half-built file.

### Verification done on this VM (19 Nov 2026)
- `flutter pub get` — PASS (103 dependencies).
- `flutter analyze` — **No issues found!**
- Local `flutter build apk` — **BLOCKED by this VM, not by the code:** Gradle's daemon IPC over localhost TCP fails here (proven: a trivial non-Flutter Gradle project fails identically, while `gradlew --version` works). GitHub Actions runners do not have this sandbox limitation, so the first push is the real build test. If Actions goes red, the failing step log will say why — most likely a dependency version drift, fixable by pinning the version in `pubspec.yaml`.

## Step 4 — Put the APK on the EPI site
1. In the website repo `dhachakwal/EPI-Chakwal`, add the built file as `vaccinators-app.apk` (repo root, next to `index.html`) and update `version.json`:
```json
{
  "versionCode": 1,
  "versionName": "1.0.0",
  "apkUrl": "https://dhachakwal.github.io/EPI-Chakwal/vaccinators-app.apk",
  "whatsNew": "Pehli version: login, live location, daily report, leave."
}
```
2. Commit + push. GitHub Pages serves the APK at that URL within a few minutes.
3. Add a download button/link on the EPI site (e.g. in the dashboard header or a new "Vaccinators App" card) pointing to `vaccinators-app.apk`.

## Step 5 — Vaccinators install it (Android only)
Share this link on WhatsApp: `https://dhachakwal.github.io/EPI-Chakwal/vaccinators-app.apk`
On the phone:
1. Tap the link → Chrome downloads the APK → tap **Downloaded file / Open**.
2. Phone asks "Allow Chrome to install unknown apps?" → **Allow** (one-time setting; this is normal for apps outside the Play Store).
3. Tap **Install** → **Open** → choose your language (اردو / English) → Login (Tehsil → UC → Name → Mobile → PIN).
4. Allow **Location — all the time** when asked, otherwise background location will not work. Allow **Notifications**.

## Step 6 — New version (FORCED in-app update — user order, 19 Nov 2026)
1. Bump `versionName` / `versionCode` in `flutter_app/pubspec.yaml` (e.g. `1.0.1+2`).
2. Push → Actions builds the new APK → replace `vaccinators-app.apk` on the site + update `version.json`:
```json
{
  "versionCode": 2,
  "versionName": "1.0.1",
  "apkUrl": "https://dhachakwal.github.io/EPI-Chakwal/vaccinators-app.apk",
  "whatsNew": "Update screen fixed: the app now updates from inside the app.",
  "whatsNewUr": "اپ ڈیٹ اسکرین بہتر ہو گئی ہے: ایپ اب اندر سے ہی اپ ڈیٹ ہوگی۔",
  "optional": false
}
```
   `optional: false` (or absent) = **forced** — the vaccinator cannot use the old version. `optional: true` = the update screen shows a "Later" button. **Only publish `version.json` after the matching APK is actually on the site** — the `files/version.json` in this folder is a 1.0.1 EXAMPLE, not a live release.
3. What the vaccinator sees: on launch, a full-screen "Update Required" screen (Urdu script + English) with what is new and one big **Update Now** button. Tapping it downloads the APK inside the app (progress bar with MB) and opens the Android installer automatically — they tap **Install** and the new version opens straight in. No Play Store, no link to hunt for. If the download fails, a Retry button appears; the old version stays blocked. Login + pending queue survive (stored on the phone, never cleared).
4. **Server-down exception:** if `version.json` cannot be reached at all, the app opens normally with a small note — a site outage never locks vaccinators out.
5. Share the same APK link again on WhatsApp as a backup, in case anyone deleted the app.

## Step 7 — Publish a new Google Form (NO APK update — user order, 19 Nov 2026)
Sometimes the admin needs extra data and today uses Google Forms. The app shows those forms **inside the app**, and a new form reaches vaccinators **without an APK update and without a version bump**:
1. Create the Google Form as usual. In **Responses → Link to Sheets**, link it to a sheet so answers are collected (or keep them in Forms → Responses).
2. Copy the form link (ends in `/viewform`) and the responses-sheet link.
3. In the website repo `dhachakwal/EPI-Chakwal`, edit `forms.json` (same file as `files/forms.json` here): copy an existing entry and change `id` (unique, e.g. `feedback-dec-2026`), `title` / `titleUr`, `description` / `descriptionUr`, `formUrl`, `responsesUrl`, `openDate` / `closeDate` (`yyyy-MM-dd`; leave `closeDate` empty for no deadline), `required` (`true`/`false`). The two entries already in the file are EXAMPLES — replace their placeholder `formUrl` values with real form links before publishing.
4. Commit + push. GitHub Pages serves the new `forms.json` within minutes.
5. Done. The next time any vaccinator opens the app (or pulls to refresh on the Forms screen), the new form is listed — **old versions of the app get it too**, because the list is fetched from the server, not baked into the APK. No rebuild, no `version.json` change.
6. Answers: open the form's response sheet from the `responsesUrl` (or Google Forms → Responses). The app's "Submitted ✓" mark is only its own local record — the response sheet is the real record.
7. **Honest limit:** filling a Google Form needs internet. With no net, vaccinators can still SEE the cached form list, but the form itself will not open — the screen says so plainly.

## Step 8 — My Data: only my own UC (PRIVACY RULE — user order, 19 Nov 2026)
Each vaccinator sees the site's data for **their own UC only** — never another UC's, never another vaccinator's. Open the app → Home → **📊 My Data** card (the Home-card entry is the last integration step — see GOAL.md; the screen itself is built and verified). Sections, for the selected month (current + previous 2 months):
- **My Attendance** — check-in/out times per day + days present (Attendance sheet, Chek-In/Check-Out tabs).
- **My Doses by Antigen** — month-to-date, 7 app antigens + all 21 HMIS antigens (Summary sheet, Outreach row for my UC).
- **My UC Summary** — outreach + fixed doses for my UC, with the fixed facilities listed (Summary Outreach + Fixed; facilities linked to UC by the site's own SV_FAC_UC map).
- **My Service Record** — Explanation / Show Cause / Warning / Notice / Appreciation rows (Vaccinator Records sheet, Records tab).
- **My Leave** — this month's leaves + balance (Leave tab + profile balance).
**Privacy enforcement:** the UC comes only from the login — there is NO UC picker, NO search, NO 'all UCs' view. Summary + Attendance are asked from the server with a UC filter (`select * where upper(...) = 'MY UC'`), so other UCs' rows never leave the server; Records / Leave / Fixed are filtered in memory immediately and the rest dropped, never cached. The offline cache stores only the filtered own-UC bundle.
**Admin setup:** the Summary, Attendance and Vaccinator Records sheets must be shared "Anyone with the link can view" like the master sheet, or that section shows "could not load" instead of pretending. No sheet structure changes, no new write endpoint. The EMR sheet is not used (per-child rows, no vaccinator column).

## Step 9 — Message Parents, FREE (user question, 19 Nov 2026)
Home → **💬 Message Parents** card. The screen lists the children of the vaccinator's **own UC only** (from the EMR sheet — the same sheet the site's Verification Calls module reads; no new parent database, no UC picker). Tap **Message** on a child → pick a template (next vaccine due / missed vaccine / could not reach you / write your own), check the preview, then tap **Send via WhatsApp (free)** — the parent's chat opens in the vaccinator's **own** WhatsApp, prefilled; the vaccinator taps Send there. The message is free beyond mobile data and goes from the vaccinator's own number. If WhatsApp is not installed, **Send via SMS** opens the phone's SMS composer instead (that SMS costs whatever the vaccinator's own mobile package charges).
**Rules:** one message at a time — **no bulk sending** (WhatsApp bans bulk automation and can ban the number). First name only in the text — no address, no MR number. The app never claims delivery; it only reports that WhatsApp/SMS opened.
**Admin setup:** the EMR sheet (`13ZSu5fZQFarP4bXLQhJVETtGuYOEb8C9jrrdcvK1TAo`, month tabs like 'Nov-2026') must be shared "Anyone with the link can view" like the master sheet, or the list shows "could not load". No sheet structure changes, no new write endpoint.

## Step 10 — Daily Reports in-app (user order, 19 Nov 2026)
The same 11 reports the nightly pipeline sends on WhatsApp at 3:00 AM PKT also arrive in the app every morning. Home → **📋 Daily Reports** card. Today's reports first, previous days below; each row shows whether it is a district report or your own UC's. Tap a picture (PNG) → it opens **inside the app** (pinch to zoom). Tap a PDF → it downloads and opens in the phone's PDF viewer. The download icon (**Save offline**) keeps a copy on the phone — saved reports open with no internet. With no net the last list + saved files show with an offline note.
**Privacy rule (same as My Data):** each vaccinator sees ONLY their own UC's reports + district-wide ones. No UC picker, no other UC's reports.
**The pipeline step — STILL TO BE BUILT (the app cannot do this alone):** the nightly bundle job must ALSO do two things after building the 11 reports:
1. Upload each report file to the site under `reports/YYYY-MM-DD/` (e.g. `reports/2026-11-19/emr-tab4.png`, `reports/2026-11-19/uc-antigen-baigal.pdf`).
2. Write `reports.json` at the site root (`https://dhachakwal.github.io/EPI-Chakwal/reports.json`) — the manifest the app reads. Exact format + a full sample: `files/reports.json` in this goal. Each entry: `id` (unique, e.g. `emr-tab4-20261119`), `title` / `titleUr`, `kind` (`png` or `pdf`), `uc` (a UC name, or `"all"` for district-wide), `url` (the full file URL). Days are grouped by `date` (`yyyy-MM-dd`), newest first; keep at least the last 7 days in the file.
3. Set `uc` per report: `"all"` ONLY for reports that name no individual vaccinator (the 5 EMR Outreach PNGs, Community Coverage Map, Fixed+Outreach Compiled PDF). Reports that name individual vaccinators or one UC's data (UC Antigen PDF, Attendance PDF, Field Location PDF, Zero-Entry PNG) must be written **per UC** — one entry per UC (e.g. `uc-antigen-baigal.pdf` with `"uc": "BAIGAL"`), or omitted for UCs they do not concern. A per-UC file that does not exist yet is simply not listed for that UC.
4. Until this step exists, the app's Daily Reports screen honestly shows "No reports for today yet" — the app never generates a report itself.
**Honest limits:** a PDF needs a PDF viewer app on the phone (the screen says so if none is installed); a picture needs internet on first open — only saved copies open offline.

## Step 11 — My Microplan in My Data (user order, 19 Nov 2026; files received + audited 20 Nov 2026)
Every vaccinator's UC microplan (RED/REC 2026) is in the app — but each vaccinator gets **ONLY their own UC's file**. The 83 workbooks (58 MB total, 81 × .xlsx + 2 × .xls) are at `microplans/extracted/` (tehsil folders); the audit is at `hidden_files/microplan-audit-2026-11-20.md` (coverage 83/83 UCs — the 9 apparent gaps were spelling variants only).
Home → **📊 My Data** → the **🗺️ My Microplan** card at the top shows UC · Tehsil · 2026, vaccinator, population, villages, plan areas, sessions, sheets, file size. Tap **Download Microplan** → ONLY that UC's file downloads (~700 KB on average — never the whole 58 MB), saves on the phone, and opens in the phone's spreadsheet viewer (Excel / Google Sheets). Afterwards the button is **Open Microplan** and the saved copy opens with no internet.
**Privacy rule (same as My Data):** the UC comes only from the login — no UC picker, no way to open another UC's file. UCs are matched by normalised comparison against the manifest entry's `uc` + `aliases` (the files, the roster and the site spell the UCs differently — e.g. file "Talagang-1" = roster "TALAGANG URBAN I", file "Jand Awan" = roster "JAND").
**Hosting — STILL PENDING (GitHub is not connected yet, so nothing is published):** upload the 83 workbooks to the site repo under `microplans/<Tehsil>/` (same tehsil folder names, same file names) and `files/microplans.json` to the site root (`https://dhachakwal.github.io/EPI-Chakwal/microplans.json`). The manifest was generated by `hidden_files/generate-microplans-manifest.py` (reads every workbook with openpyxl; re-run it after any file change). **Convert the 2 old .xls files FIRST** — Maingon (Chakwal) and Dhermond (Talagang) — to .xlsx, replace them in `microplans/extracted/`, and re-run the generator, or those two UCs stay on 'being converted' in the app. Until the upload happens, the My Microplan card honestly says "Your UC's microplan is not in the app yet".
**Honest limits:** a spreadsheet viewer app must be installed on the phone to open the file; the app never parses the workbook on the phone (the summary numbers come from the manifest); 13 UCs have no vaccinator in the roster (Chakwal 4, Choa Ganj Ali Shah, Dhab Khushal, Karyala, Mangwal, Mureed, Saigolabad, Ara, Dandot, Saloi, Saghar, T.M.Khan-2, Talagang-3) — their entries work by UC as soon as a vaccinator is assigned; the audit's data-quality flags (Niraghi, Dulmial, Khairpur, Bherpur, Chakwal 3, Mogla/Mulhal counts) still need the user's confirmation.

## Before sharing with all 70 vaccinators
- [ ] Actions build green, APK installs on a real phone (not just an emulator).
- [ ] Login works with a real roster name; location posts and appears in the `Location` sheet (verify-before-success shows green only after the row is in the sheet).
- [ ] Leave submits with a photo and appears in the `Leave` tab.
- [ ] Background location sends at least twice while the app is closed.
- [ ] Forced update blocks the app on launch when `version.json` is bumped (test with a dummy bump) — no back button, no "Later", download + installer open from the same screen.
- [ ] Server-down exception: with no net / version.json unreachable, the app still opens normally with a small note.
- [ ] Dynamic Forms: add a real form to `forms.json` on the site and confirm it appears in the app with NO APK update; fill it in the app and confirm the answer lands in the form's response sheet.
- [ ] Calls entry: tap the 📞 Calls card on Home — the contacts list opens (Admin row + roster vaccinators, search works); tapping any call button shows 'Calling Not Set Up Yet' and does NOT crash or pretend to call. (Signalling code is done 19 Nov 2026 — a real call still needs the user's 4 Firebase setup steps in `files/Calling-v2-Design.md` §10 + the two-phone test. See GOAL.md.)
- [ ] My Data: tap the 📊 My Data card on Home — only the logged-in vaccinator's OWN UC appears (attendance, doses, UC summary, service record, leave); the month selector switches months; there is NO UC picker or search; with no net the cached own-UC data shows with an offline note.
- [ ] Message Parents: tap the 💬 Message Parents card on Home — only the logged-in vaccinator's OWN UC children appear (from the EMR sheet); tap Message on a child, pick a template, and confirm WhatsApp opens with the message prefilled (tap Send in WhatsApp — the app itself never claims delivery); confirm there is NO bulk-send button anywhere.
- [ ] Daily Reports: tap the 📋 Daily Reports card on Home — today's reports for the logged-in UC only (+ district reports) appear; a PNG opens inside the app, a PDF opens in the phone's viewer, 'Save offline' opens with no net; another UC's reports never appear. (Needs the pipeline step in Step 10 first — files uploaded + `reports.json` written — or the screen honestly shows 'no reports yet'.)
- [ ] My Microplan: tap the 📊 My Data card on Home — the 🗺️ My Microplan card at the top shows ONLY the logged-in vaccinator's OWN UC file (population, villages, areas, sessions, sheets, size); tap Download → the file downloads (~700 KB), opens in the phone's spreadsheet app, and the saved copy opens with no net; another UC's file never appears. (Needs the hosting step in Step 11 first — 83 files + `microplans.json` uploaded — or the card honestly says 'not in the app yet'. Maingon + Dhermond stay on 'being converted' until their .xls files are converted to .xlsx.)

## Costs
| Item | Cost |
|---|---|
| Flutter / Android Studio | $0 |
| GitHub Actions (public repo) | $0 |
| GitHub Pages hosting | $0 |
| Google Sheets + Apps Script | $0 |
| Play Store | $0 — not used |
| **Total** | **$0** |

## Known limits (honest)
- The existing Apps Script endpoint today only handles `location` + `leave`. Daily Report, Zero Entry, Mock Location reports and Announcements need the script additions listed in `GOAL.md` ("What is NEW") before those screens can sync live — the app queues them safely until then, it does not fake success. Fake-location blocking itself does NOT need the script: a mocked fix is refused on the phone even with no server.
- Dynamic Google Forms need NO Apps Script at all: the list is a static `forms.json` on the site and answers go to each form's own response sheet. Filling a form needs internet — offline fill is not possible with embedded Google Forms.
- APK does not run on iPhone. If any vaccinator uses an iPhone, they keep using the web form (`location.html`) on the dashboard.
- Calling: the Calls entry and contacts list are wired and the Firebase signalling code is implemented (19 Nov 2026), but placing a call does NOT work yet — the user's Firebase project is not set up (no `google-services.json`), so tapping a call button honestly says 'Calling Not Set Up Yet'. The 4 setup steps are in `files/Calling-v2-Design.md` §10. Supervisors have no contact row until the admin adds the supervisor list (they are not in the `All Vaccinators Profile` roster). Do not tell vaccinators calling works until the two-phone test in GOAL.md passes.
- My Data: the screen, service and strings are built and `flutter analyze` is clean, but the 📊 My Data card on Home is NOT added yet (another agent owns home_screen.dart/main.dart right now — the exact 5 lines are in GOAL.md). Until that card is added, My Data cannot be opened from the app. The Summary / Attendance / Records sheets must also be link-viewable, or those sections show "could not load".
- Background location on some phones (Xiaomi, Vivo, Oppo) needs "Battery optimisation OFF / Autostart ON" for the app — the app shows this instruction if background sends stop.
