import 'package:flutter/material.dart';

/// Language rule (user order, 19 Nov 2026 — STANDING):
/// NO Roman Urdu anywhere in this app. Exactly two languages:
/// English, or Urdu in proper Urdu script (e.g. لاگ ان کریں).
/// Every user-facing string lives in [_values] below, in both
/// languages. Code must never hard-code a user-facing string in
/// Roman Urdu (or any other language); use [AppLanguage.t].
enum AppLanguage { english, urdu }

extension AppLanguageInfo on AppLanguage {
  String get code => this == AppLanguage.urdu ? 'ur' : 'en';
  String get label => this == AppLanguage.urdu ? 'اردو' : 'English';
  Locale get locale =>
      this == AppLanguage.urdu ? const Locale('ur') : const Locale('en');

  static AppLanguage fromCode(String? code) =>
      code == 'ur' ? AppLanguage.urdu : AppLanguage.english;

  /// Translate [key]; `{name}`, `{n}`, `{m}`, `{max}`, `{remaining}`
  /// placeholders are replaced from [params]. Falls back to English,
  /// then to the key itself — never crashes on a missing key.
  String t(String key, [Map<String, String>? params]) {
    var s = AppStrings.get(this, key);
    params?.forEach((k, v) => s = s.replaceAll('{$k}', v));
    return s;
  }
}

/// Full string table — every user-facing string in all 9 screens
/// (login, home, location, daily report, zero entry, leave,
/// notifications, profile, admin map, admin late list), the update
/// dialog, bottom navigation, and all errors / success messages.
/// Data values (tehsil / UC / vaccinator names, antigen codes,
/// dates, numbers) are NOT translated — they come from the sheet.
class AppStrings {
  AppStrings._();

  static const Map<String, Map<AppLanguage, String>> _values = {
    // --- App / language picker ---
    'appTitle': {
      AppLanguage.english: 'Vaccinators App',
      AppLanguage.urdu: 'ویکسینیٹرز ایپ',
    },
    'appSubtitle': {
      AppLanguage.english: 'EPI District Chakwal',
      AppLanguage.urdu: 'ای پی آئی ضلع چکوال',
    },
    'chooseLanguage': {
      AppLanguage.english: 'Choose your language',
      AppLanguage.urdu: 'اپنی زبان منتخب کریں',
    },
    'chooseLanguageSub': {
      AppLanguage.english:
          'You can change this later from your Profile.',
      AppLanguage.urdu: 'آپ اسے بعد میں اپنی پروفائل سے بدل سکتے ہیں۔',
    },
    'continueBtn': {
      AppLanguage.english: 'Continue',
      AppLanguage.urdu: 'جاری رکھیں',
    },
    'loading': {
      AppLanguage.english: 'Loading…',
      AppLanguage.urdu: 'لوڈ ہو رہا ہے…',
    },

    // --- Bottom navigation ---
    'navHome': {
      AppLanguage.english: 'Home',
      AppLanguage.urdu: 'ہوم',
    },
    'navLocation': {
      AppLanguage.english: 'Location',
      AppLanguage.urdu: 'لوکیشن',
    },
    'navReport': {
      AppLanguage.english: 'Report',
      AppLanguage.urdu: 'رپورٹ',
    },
    'navLeave': {
      AppLanguage.english: 'Leave',
      AppLanguage.urdu: 'چھٹی',
    },
    'navProfile': {
      AppLanguage.english: 'Profile',
      AppLanguage.urdu: 'پروفائل',
    },

    // --- Login ---
    'loginTitle': {
      AppLanguage.english: 'Log In',
      AppLanguage.urdu: 'لاگ ان کریں',
    },
    'loginInfo': {
      AppLanguage.english:
          'Choose your tehsil, union council and name. You only log in once — you will not need to log in every day.',
      AppLanguage.urdu:
          'اپنی تحصیل، یونین کونسل اور نام منتخب کریں۔ لاگ ان صرف ایک بار ہوگا — روزانہ لاگ ان کرنے کی ضرورت نہیں ہوگی۔',
    },
    'tehsil': {
      AppLanguage.english: 'Tehsil',
      AppLanguage.urdu: 'تحصیل',
    },
    'uc': {
      AppLanguage.english: 'Union Council (UC)',
      AppLanguage.urdu: 'یونین کونسل',
    },
    'yourName': {
      AppLanguage.english: 'Your Name',
      AppLanguage.urdu: 'آپ کا نام',
    },
    'mobile': {
      AppLanguage.english: 'Mobile Number',
      AppLanguage.urdu: 'موبائل نمبر',
    },
    'pin': {
      AppLanguage.english: 'PIN (4 digits)',
      AppLanguage.urdu: 'پن (4 ہندسے)',
    },
    'loginButton': {
      AppLanguage.english: 'Log In',
      AppLanguage.urdu: 'لاگ ان کریں',
    },
    'loginSelectError': {
      AppLanguage.english: 'First choose your tehsil, UC and name.',
      AppLanguage.urdu: 'پہلے اپنی تحصیل، یونین کونسل اور نام منتخب کریں۔',
    },
    'loginPinError': {
      AppLanguage.english: 'The PIN must be 4 digits.',
      AppLanguage.urdu: 'پن 4 ہندسوں کا ہونا چاہیے۔',
    },
    'rosterEmpty': {
      AppLanguage.english:
          'The vaccinator list did not load. Check the internet and open the app again.',
      AppLanguage.urdu:
          'ویکسینیٹرز کی فہرست لوڈ نہیں ہوئی۔ انٹرنیٹ چیک کریں اور ایپ دوبارہ کھولیں۔',
    },
    'pinPendingNote': {
      AppLanguage.english:
          'The PIN still has to be confirmed by the admin — on first login any 4-digit PIN will be set.',
      AppLanguage.urdu:
          'پن کی تصدیق ابھی ایڈمن سے ہونا باقی ہے — پہلی لاگ ان پر کوئی بھی 4 ہندسوں والا پن سیٹ ہو جائے گا۔',
    },

    // --- Home ---
    'greeting': {
      AppLanguage.english: 'Hello, {name}',
      AppLanguage.urdu: 'السلام علیکم، {name}',
    },
    'locationNotSent': {
      AppLanguage.english: "Today's location has not been sent",
      AppLanguage.urdu: 'آج کی لوکیشن نہیں بھیجی گئی',
    },
    'locationSent': {
      AppLanguage.english: 'Location sent',
      AppLanguage.urdu: 'لوکیشن بھیج دی گئی',
    },
    'syncPending': {
      AppLanguage.english: '{n} items waiting to sync',
      AppLanguage.urdu: '{n} آئٹم سنک ہونے کے منتظر ہیں',
    },
    'cardLocationTitle': {
      AppLanguage.english: 'Send Live Location',
      AppLanguage.urdu: 'لائیو لوکیشن بھیجیں',
    },
    'cardLocationSub': {
      AppLanguage.english: "Send today's location to the sheet",
      AppLanguage.urdu: 'آج کی لوکیشن شیٹ پر بھیجیں',
    },
    'cardReportTitle': {
      AppLanguage.english: 'Daily Report',
      AppLanguage.urdu: 'روزانہ رپورٹ',
    },
    'cardReportSub': {
      AppLanguage.english:
          'How many children received which vaccine today',
      AppLanguage.urdu: 'آج کتنے بچوں کو کون سی ویکسین لگی',
    },
    'cardZeroTitle': {
      AppLanguage.english: 'Zero Entry',
      AppLanguage.urdu: 'زیرو انٹری',
    },
    'cardZeroSub': {
      AppLanguage.english: 'The UC where no vaccination took place',
      AppLanguage.urdu: 'جس یونین کونسل میں ویکسینیشن نہیں ہوئی',
    },
    'cardLeaveTitle': {
      AppLanguage.english: 'Leave',
      AppLanguage.urdu: 'چھٹی',
    },
    'cardLeaveSub': {
      AppLanguage.english: "Today's leave and balance",
      AppLanguage.urdu: 'آج کی چھٹی اور بیلنس دیکھیں',
    },
    'cardNotifTitle': {
      AppLanguage.english: 'Announcements',
      AppLanguage.urdu: 'اعلانات',
    },
    'cardNotifSub': {
      AppLanguage.english: 'Instructions from the office',
      AppLanguage.urdu: 'دفتر کی طرف سے ہدایات',
    },
    'homeBgNote': {
      AppLanguage.english:
          'As soon as you send your first location, background location starts by itself every 30 minutes — even if the app is closed.',
      AppLanguage.urdu:
          'جیسے ہی آپ پہلی لوکیشن بھیجیں گے، بیک گراؤنڈ لوکیشن ہر 30 منٹ بعد خود چلنے لگے گی — چاہے ایپ بند ہو۔',
    },

    // --- Live Location ---
    'locTitle': {
      AppLanguage.english: 'Live Location',
      AppLanguage.urdu: 'لائیو لوکیشن',
    },
    'kitStation': {
      AppLanguage.english: 'Kit Station Name',
      AppLanguage.urdu: 'کٹ اسٹیشن کا نام',
    },
    'kitHint': {
      AppLanguage.english: 'e.g. H.H Nazia, Bethak Noor Khan',
      AppLanguage.urdu: 'مثلاً ایچ ایچ نازیہ، بیٹھک نور خان',
    },
    'getLocation': {
      AppLanguage.english: 'Get My Location',
      AppLanguage.urdu: 'میری لوکیشن حاصل کریں',
    },
    'locationReady': {
      AppLanguage.english: 'Location ready',
      AppLanguage.urdu: 'لوکیشن تیار ہے',
    },
    'sendLocation': {
      AppLanguage.english: 'Send Location',
      AppLanguage.urdu: 'لوکیشن بھیجیں',
    },
    'locPermError': {
      AppLanguage.english:
          'Location permission was not given. Allow Location in Settings.',
      AppLanguage.urdu:
          'لوکیشن کی اجازت نہیں ملی۔ سیٹنگز میں لوکیشن کی اجازت دیں۔',
    },
    'locNotFound': {
      AppLanguage.english:
          'Location was not found. Go outside and try again.',
      AppLanguage.urdu: 'لوکیشن نہیں ملی۔ باہر جا کر دوبارہ کوشش کریں۔',
    },
    'locFirstGet': {
      AppLanguage.english: 'First press "Get My Location".',
      AppLanguage.urdu: 'پہلے "میری لوکیشن حاصل کریں" دبائیں۔',
    },
    'locKitEmpty': {
      AppLanguage.english: 'Write the Kit Station Name.',
      AppLanguage.urdu: 'کٹ اسٹیشن کا نام لکھیں۔',
    },
    'locSuccess': {
      AppLanguage.english: 'Location received — thank you, {name}!',
      AppLanguage.urdu: 'لوکیشن مل گئی — شکریہ، {name}!',
    },
    'locQueued': {
      AppLanguage.english:
          'Not confirmed yet — it is saved on the phone and will be sent by itself when the internet returns. No need to send it again.',
      AppLanguage.urdu:
          'ابھی تصدیق نہیں ہوئی — یہ فون میں محفوظ ہے، انٹرنیٹ آتے ہی خود بھیج دی جائے گی۔ دوبارہ بھیجنے کی ضرورت نہیں۔',
    },
    'locNote': {
      AppLanguage.english:
          'As soon as you send your first location, background location starts by itself every 30 minutes. "Submitted" is only shown when the row is confirmed in the sheet.',
      AppLanguage.urdu:
          'جیسے ہی آپ پہلی لوکیشن بھیجیں گے، بیک گراؤنڈ لوکیشن ہر 30 منٹ بعد خود چلنے لگے گی۔ "جمع شدہ" صرف تب دکھایا جائے گا جب شیٹ میں قطار کی تصدیق ہو جائے۔',
    },
    'accuracy': {
      AppLanguage.english: 'Accuracy: ~{n} m',
      AppLanguage.urdu: 'درستگی: تقریباً {n} میٹر',
    },

    // --- Daily Report / Zero Entry ---
    'reportTitle': {
      AppLanguage.english: 'Daily Report',
      AppLanguage.urdu: 'روزانہ رپورٹ',
    },
    'todayVacc': {
      AppLanguage.english: "Today's Vaccination",
      AppLanguage.urdu: 'آج کی ویکسینیشن',
    },
    'totalChildren': {
      AppLanguage.english: 'Total children: {n}',
      AppLanguage.urdu: 'کل بچے: {n}',
    },
    'sendReport': {
      AppLanguage.english: 'Send Report',
      AppLanguage.urdu: 'رپورٹ بھیجیں',
    },
    'reportVerified': {
      AppLanguage.english: 'Report received — thank you!',
      AppLanguage.urdu: 'رپورٹ مل گئی — شکریہ!',
    },
    'reportQueued': {
      AppLanguage.english:
          'The report is saved on the phone — it will be sent by itself as soon as the server is ready. (The new Daily Report tab still has to be added in Apps Script.)',
      AppLanguage.urdu:
          'رپورٹ فون میں محفوظ ہے — سرور تیار ہوتے ہی خود بھیج دی جائے گی۔ (روزانہ رپورٹ کا نیا ٹیب ابھی ایپس اسکرپٹ میں شامل ہونا باقی ہے۔)',
    },
    'zeroTitle': {
      AppLanguage.english: 'Zero Entry',
      AppLanguage.urdu: 'زیرو انٹری',
    },
    'zeroDesc': {
      AppLanguage.english:
          'For the UC where no vaccination took place today, tell us the reason.',
      AppLanguage.urdu:
          'جس یونین کونسل میں آج کوئی ویکسینیشن نہیں ہوئی، اس کی وجہ بتائیں۔',
    },
    'zeroReasonLabel': {
      AppLanguage.english: 'Reason',
      AppLanguage.urdu: 'وجہ',
    },
    'zeroReasonLeave': {
      AppLanguage.english: 'I was on leave',
      AppLanguage.urdu: 'میں چھٹی پر تھا',
    },
    'zeroReasonNotLeave': {
      AppLanguage.english: 'I was not on leave — write the reason below',
      AppLanguage.urdu: 'میں چھٹی پر نہیں تھا — وجہ نیچے لکھیں',
    },
    'zeroNoteLabel': {
      AppLanguage.english: 'Reason / Note (if any)',
      AppLanguage.urdu: 'وجہ / نوٹ (اگر کوئی ہو)',
    },
    'sendZero': {
      AppLanguage.english: 'Send Zero Entry',
      AppLanguage.urdu: 'زیرو انٹری بھیجیں',
    },
    'zeroVerified': {
      AppLanguage.english: 'Zero Entry received — thank you!',
      AppLanguage.urdu: 'زیرو انٹری مل گئی — شکریہ!',
    },
    'zeroQueued': {
      AppLanguage.english:
          'Zero Entry is saved on the phone — it will be sent by itself as soon as the server is ready.',
      AppLanguage.urdu:
          'زیرو انٹری فون میں محفوظ ہے — سرور تیار ہوتے ہی خود بھیج دی جائے گی۔',
    },
    'zeroChooseReason': {
      AppLanguage.english: 'Choose the reason for the Zero Entry.',
      AppLanguage.urdu: 'زیرو انٹری کی وجہ منتخب کریں۔',
    },

    // --- Leave ---
    'leaveTitle': {
      AppLanguage.english: 'Leave',
      AppLanguage.urdu: 'چھٹی',
    },
    'balanceLoading': {
      AppLanguage.english: 'Balance is loading…',
      AppLanguage.urdu: 'بیلنس لوڈ ہو رہا ہے…',
    },
    'balanceText': {
      AppLanguage.english:
          'This month: {m} / {max}  ·  Remaining this year: {remaining}\nMax 2 / month, 24 / year. Half day is not allowed.',
      AppLanguage.urdu:
          'اس مہینے: {m} / {max}  ·  اس سال باقی: {remaining}\nزیادہ سے زیادہ 2 / مہینہ، 24 / سال۔ آدھا دن کی اجازت نہیں۔',
    },
    'leaveDateLabel': {
      AppLanguage.english: "Leave Date (today's date)",
      AppLanguage.urdu: 'چھٹی کی تاریخ (آج کی تاریخ)',
    },
    'takePhoto': {
      AppLanguage.english: 'Take a Photo of the Application',
      AppLanguage.urdu: 'درخواست کی تصویر لیں',
    },
    'retakePhoto': {
      AppLanguage.english: 'Photo attached — take it again',
      AppLanguage.urdu: 'تصویر لگ گئی — دوبارہ لیں',
    },
    'sendLeave': {
      AppLanguage.english: 'Send Leave',
      AppLanguage.urdu: 'چھٹی بھیجیں',
    },
    'leavePhotoRequired': {
      AppLanguage.english:
          'Attaching a photo of the leave application is compulsory.',
      AppLanguage.urdu: 'چھٹی کی درخواست کی تصویر لگانا ضروری ہے۔',
    },
    'leaveLimitReached': {
      AppLanguage.english:
          "This month's limit is complete (max {max} leaves).",
      AppLanguage.urdu: 'اس مہینے کی حد مکمل ہو گئی (زیادہ سے زیادہ {max} چھٹیاں)۔',
    },
    'leaveVerified': {
      AppLanguage.english: 'Your leave has been submitted successfully.',
      AppLanguage.urdu: 'آپ کی چھٹی کامیابی سے جمع ہو گئی ہے۔',
    },
    'leaveQueued': {
      AppLanguage.english:
          'The leave is saved on the phone — it will be sent when the internet returns, and you will be told when it is confirmed.',
      AppLanguage.urdu:
          'چھٹی فون میں محفوظ ہے — انٹرنیٹ آتے ہی بھیج دی جائے گی، تصدیق ہونے پر بتا دیا جائے گا۔',
    },

    // --- Notifications ---
    'notifTitle': {
      AppLanguage.english: 'Announcements',
      AppLanguage.urdu: 'اعلانات',
    },
    'notifSub': {
      AppLanguage.english: 'Instructions from the office',
      AppLanguage.urdu: 'دفتر کی طرف سے ہدایات',
    },
    'noNotif': {
      AppLanguage.english: 'There is no announcement right now.',
      AppLanguage.urdu: 'ابھی کوئی اعلان نہیں ہے۔',
    },

    // --- Dynamic Google Forms (user order, 19 Nov 2026) ---
    // The form LIST is fetched from forms.json on the EPI site —
    // never hard-coded — so a new form reaches vaccinators with
    // NO APK update. Each form opens inside the app (WebView).
    // Urdu in proper Urdu script, no Roman Urdu.
    'formsTitle': {
      AppLanguage.english: 'Forms',
      AppLanguage.urdu: 'فارم',
    },
    'formsSub': {
      AppLanguage.english: 'Forms from the office — fill them here',
      AppLanguage.urdu: 'دفتر کے فارم — یہیں بھریں',
    },
    'cardFormsTitle': {
      AppLanguage.english: 'Forms',
      AppLanguage.urdu: 'فارم',
    },
    'cardFormsSub': {
      AppLanguage.english: 'Forms from the office — fill them here',
      AppLanguage.urdu: 'دفتر کے فارم — یہیں بھریں',
    },
    'formsEmpty': {
      AppLanguage.english: 'There is no form right now.',
      AppLanguage.urdu: 'ابھی کوئی فارم نہیں ہے۔',
    },
    'formsOffline': {
      AppLanguage.english:
          'No internet — showing the last saved list. Pull to refresh when the internet returns.',
      AppLanguage.urdu:
          'انٹرنیٹ نہیں ہے — آخری محفوظ فہرست دکھائی جا رہی ہے۔ انٹرنیٹ آتے ہی ریفریش کریں۔',
    },
    'formsRequired': {
      AppLanguage.english: 'Required',
      AppLanguage.urdu: 'لازمی',
    },
    'formsSubmitted': {
      AppLanguage.english: 'Submitted ✓',
      AppLanguage.urdu: 'جمع شدہ ✓',
    },
    'formsClosed': {
      AppLanguage.english: 'Closed',
      AppLanguage.urdu: 'بند',
    },
    'formsNotYetOpen': {
      AppLanguage.english: 'Not open yet',
      AppLanguage.urdu: 'ابھی نہیں کھلا',
    },
    'formsDeadline': {
      AppLanguage.english: 'Last date: {date}',
      AppLanguage.urdu: 'آخری تاریخ: {date}',
    },
    'formsFillNote': {
      AppLanguage.english:
          'Fill the form and press Submit at the end. Filling a form needs internet — it cannot be filled offline.',
      AppLanguage.urdu:
          'فارم بھریں اور آخر میں جمع کریں دبائیں۔ فارم بھرنے کے لیے انٹرنیٹ ضروری ہے — آف لائن فارم نہیں بھرا جا سکتا۔',
    },
    'formsNeedsNet': {
      AppLanguage.english:
          'The form did not open. Check the internet and try again — a form cannot be filled offline.',
      AppLanguage.urdu:
          'فارم نہیں کھلا۔ انٹرنیٹ چیک کریں اور دوبارہ کوشش کریں — آف لائن فارم نہیں بھرا جا سکتا۔',
    },
    'formsMarkSubmitted': {
      AppLanguage.english: 'Mark as Submitted',
      AppLanguage.urdu: 'جمع شدہ نشان زد کریں',
    },
    'formsSubmittedThanks': {
      AppLanguage.english: 'Thank you — marked as submitted.',
      AppLanguage.urdu: 'شکریہ — جمع شدہ نشان زد کر دیا گیا۔',
    },
    'formsOpenBrowser': {
      AppLanguage.english: 'Open in Browser',
      AppLanguage.urdu: 'براؤزر میں کھولیں',
    },

    // --- Profile ---
    'profileTitle': {
      AppLanguage.english: 'My Profile',
      AppLanguage.urdu: 'میری پروفائل',
    },
    'lastLocation': {
      AppLanguage.english: 'Last location',
      AppLanguage.urdu: 'آخری لوکیشن',
    },
    'syncRemaining': {
      AppLanguage.english: 'Waiting to sync',
      AppLanguage.urdu: 'سنک ہونا باقی',
    },
    'leaveBalanceOpening': {
      AppLanguage.english: 'Leave balance (opening)',
      AppLanguage.urdu: 'چھٹی کا بیلنس (ابتدائی)',
    },
    'remainingYear': {
      AppLanguage.english: 'remaining (for the year)',
      AppLanguage.urdu: 'باقی (سال کے حساب سے)',
    },
    'syncNow': {
      AppLanguage.english: 'Sync Now ({n} remaining)',
      AppLanguage.urdu: 'ابھی سنک کریں ({n} باقی)',
    },
    'syncResult': {
      AppLanguage.english: '{sent} sent, {pending} remaining.',
      AppLanguage.urdu: '{sent} بھیجے گئے، {pending} باقی ہیں۔',
    },
    'updateCheck': {
      AppLanguage.english: 'Check for Update',
      AppLanguage.urdu: 'اپ ڈیٹ چیک کریں',
    },
    'updateAvailable': {
      AppLanguage.english: 'New version {v} is available!',
      AppLanguage.urdu: 'نیا ورژن {v} آ گیا ہے!',
    },
    'updateLatest': {
      AppLanguage.english: 'The app is on the latest version.',
      AppLanguage.urdu: 'ایپ تازہ ترین ورژن پر ہے۔',
    },
    'logout': {
      AppLanguage.english: 'Log Out',
      AppLanguage.urdu: 'لاگ آؤٹ',
    },
    'appVersion': {
      AppLanguage.english: 'App version {v} · EPI District Chakwal',
      AppLanguage.urdu: 'ایپ ورژن {v} · ای پی آئی ضلع چکوال',
    },
    'language': {
      AppLanguage.english: 'Language',
      AppLanguage.urdu: 'زبان',
    },
    'ucLabel': {
      AppLanguage.english: 'UC',
      AppLanguage.urdu: 'یونین کونسل',
    },
    'usernameMobile': {
      AppLanguage.english: 'Username / Mobile',
      AppLanguage.urdu: 'یوزر نیم / موبائل',
    },
    'languageNote': {
      AppLanguage.english:
          'Choose Urdu or English. The whole app will switch to that language.',
      AppLanguage.urdu:
          'اردو یا انگریزی منتخب کریں۔ پوری ایپ اسی زبان میں بدل جائے گی۔',
    },

    // --- Admin Live Map ---
    'adminMapTitle': {
      AppLanguage.english: 'Live Map — Admin',
      AppLanguage.urdu: 'لائیو نقشہ — ایڈمن',
    },
    'submittedToday': {
      AppLanguage.english: 'Submitted today: {n} / 70',
      AppLanguage.urdu: 'آج جمع شدہ: {n} / 70',
    },
    'refresh': {
      AppLanguage.english: 'Refresh',
      AppLanguage.urdu: 'ریفریش کریں',
    },
    'showList': {
      AppLanguage.english: 'Show List',
      AppLanguage.urdu: 'فہرست دیکھیں',
    },
    'showMap': {
      AppLanguage.english: 'Show Map',
      AppLanguage.urdu: 'نقشہ دیکھیں',
    },
    'legend': {
      AppLanguage.english:
          'Green = on time, Amber = after 10 AM. The map is from OpenStreetMap — free, no API key.',
      AppLanguage.urdu:
          'سبز = وقت پر، زرد = صبح 10 بجے کے بعد۔ نقشہ اوپن اسٹریٹ میپ سے ہے — مفت، کوئی اے پی آئی کی نہیں۔',
    },
    'adminTitle': {
      AppLanguage.english: 'Admin — EPI Chakwal',
      AppLanguage.urdu: 'ایڈمن — ای پی آئی چکوال',
    },
    'adminMap': {
      AppLanguage.english: 'Admin Map',
      AppLanguage.urdu: 'ایڈمن نقشہ',
    },
    'liveMap': {
      AppLanguage.english: 'Live Map',
      AppLanguage.urdu: 'لائیو نقشہ',
    },

    // --- Admin Late / Missing List ---
    'lateTitle': {
      AppLanguage.english: 'Late / Missing — Admin',
      AppLanguage.urdu: 'تاخیر / غیر حاضر — ایڈمن',
    },
    'lateSub': {
      AppLanguage.english: 'No location sent by 10:00 AM — {date}',
      AppLanguage.urdu: 'صبح 10:00 بجے تک لوکیشن نہیں بھیجی گئی — {date}',
    },
    'filterAll': {
      AppLanguage.english: 'All',
      AppLanguage.urdu: 'سب',
    },
    'filterMissing': {
      AppLanguage.english: 'Missing',
      AppLanguage.urdu: 'غیر حاضر',
    },
    'filterOnLeave': {
      AppLanguage.english: 'On Leave',
      AppLanguage.urdu: 'چھٹی پر',
    },
    'missingSummary': {
      AppLanguage.english:
          'Missing: {m}  ·  On Leave: {l}  ·  Total roster: 70',
      AppLanguage.urdu: 'غیر حاضر: {m}  ·  چھٹی پر: {l}  ·  کل تعداد: 70',
    },
    'shareWhatsApp': {
      AppLanguage.english: 'Share on WhatsApp',
      AppLanguage.urdu: 'واٹس ایپ پر شیئر کریں',
    },
    'allSent': {
      AppLanguage.english: 'Everyone has sent their location.',
      AppLanguage.urdu: 'سب نے اپنی لوکیشن بھیج دی ہے۔',
    },


    // --- Fake / mock location (MUST-HAVE, user order 19 Nov 2026) ---
    // Blocking warning shown instead of the submit button while a
    // mocked fix is active. Urdu in proper Urdu script, no Roman Urdu.
    'mockTitle': {
      AppLanguage.english: 'Fake Location Is On',
      AppLanguage.urdu: 'جعلی لوکیشن آن ہے',
    },
    'mockBody': {
      AppLanguage.english:
          'This location is not real — a fake-location app is on. Turn off fake location, then press "Check Again". No location will be sent until the fake location is off.',
      AppLanguage.urdu:
          'یہ لوکیشن اصلی نہیں ہے — جعلی لوکیشن والی ایپ آن ہے۔ جعلی لوکیشن بند کریں، پھر "دوبارہ چیک کریں" دبائیں۔ جعلی لوکیشن بند ہونے تک کوئی لوکیشن نہیں بھیجی جائے گی۔',
    },
    'mockOpenSettings': {
      AppLanguage.english: 'Open Location Settings',
      AppLanguage.urdu: 'لوکیشن سیٹنگز کھولیں',
    },
    'mockCheckAgain': {
      AppLanguage.english: 'Check Again',
      AppLanguage.urdu: 'دوبارہ چیک کریں',
    },
    'mockReported': {
      AppLanguage.english:
          'This attempt has been reported to the admin.',
      AppLanguage.urdu: 'یہ کوشش ایڈمن کو رپورٹ کر دی گئی ہے۔',
    },
    'mockReasonMockedFlag': {
      AppLanguage.english: 'the phone reports this location as mocked',
      AppLanguage.urdu: 'فون بتا رہا ہے کہ یہ لوکیشن جعلی ہے',
    },
    'mockReasonImpossibleSpeed': {
      AppLanguage.english: 'the speed is impossible for travel here',
      AppLanguage.urdu: 'رفتار یہاں سفر کے لیے ناممکن ہے',
    },
    'mockReasonStaleTimestamp': {
      AppLanguage.english: 'the location is old or from the future',
      AppLanguage.urdu: 'لوکیشن پرانی ہے یا مستقبل کی ہے',
    },
    'mockReasonOutsideDistrict': {
      AppLanguage.english: 'the location is outside District Chakwal',
      AppLanguage.urdu: 'لوکیشن ضلع چکوال سے باہر ہے',
    },
    'mockReasonBadAccuracy': {
      AppLanguage.english: 'the location accuracy is not believable',
      AppLanguage.urdu: 'لوکیشن کی درستگی قابلِ یقین نہیں',
    },
    'mockDetectedWhy': {
      AppLanguage.english: 'Why it was detected: {reasons}',
      AppLanguage.urdu: 'پتہ کیسے چلا: {reasons}',
    },
    'filterFake': {
      AppLanguage.english: 'Fake Location',
      AppLanguage.urdu: 'جعلی لوکیشن',
    },
    'fakeSummary': {
      AppLanguage.english:
          'Fake location attempts today: {n}',
      AppLanguage.urdu: 'آج جعلی لوکیشن کی کوششیں: {n}',
    },
    'fakeListEmpty': {
      AppLanguage.english: 'No fake location attempt today.',
      AppLanguage.urdu: 'آج جعلی لوکیشن کی کوئی کوشش نہیں ہوئی۔',
    },

    // --- Update dialog ---
    'newVersionTitle': {
      AppLanguage.english: 'A new version is available — v{v}',
      AppLanguage.urdu: 'نیا ورژن آ گیا ہے — v{v}',
    },
    'newVersionBody': {
      AppLanguage.english: 'Download the new version.',
      AppLanguage.urdu: 'نیا ورژن ڈاؤن لوڈ کریں۔',
    },
    'later': {
      AppLanguage.english: 'Later',
      AppLanguage.urdu: 'بعد میں',
    },
    'downloadNow': {
      AppLanguage.english: 'Download Now',
      AppLanguage.urdu: 'ابھی ڈاؤن لوڈ کریں',
    },
    'download': {
      AppLanguage.english: 'Download',
      AppLanguage.urdu: 'ڈاؤن لوڈ',
    },

    // --- Forced in-app update (user order, 19 Nov 2026 — STANDING) ---
    // The update screen blocks the whole app until the new version
    // is installed. Urdu in proper Urdu script, no Roman Urdu.
    'updateTitle': {
      AppLanguage.english: 'Update Required',
      AppLanguage.urdu: 'اپ ڈیٹ ضروری ہے',
    },
    'updateFirstBody': {
      AppLanguage.english:
          'First update the app, then it will run. The old version will not open until the update is installed.',
      AppLanguage.urdu:
          'پہلے ایپ اپ ڈیٹ کریں، پھر ایپ چلے گی۔ اپ ڈیٹ انسٹال ہونے تک پرانی ورژن نہیں کھلے گی۔',
    },
    'updateNow': {
      AppLanguage.english: 'Update Now',
      AppLanguage.urdu: 'ابھی اپ ڈیٹ کریں',
    },
    'updateWhatsNew': {
      AppLanguage.english: 'What is new',
      AppLanguage.urdu: 'نیا کیا ہے',
    },
    'updateDownloading': {
      AppLanguage.english: 'Downloading update…',
      AppLanguage.urdu: 'اپ ڈیٹ ڈاؤن لوڈ ہو رہی ہے…',
    },
    'updateDownloaded': {
      AppLanguage.english: 'Download complete — opening installer…',
      AppLanguage.urdu: 'ڈاؤن لوڈ مکمل — انسٹالر کھل رہا ہے…',
    },
    'updateSize': {
      AppLanguage.english: '{received} MB of {total} MB',
      AppLanguage.urdu: '{received} ایم بی از {total} ایم بی',
    },
    'updateFailed': {
      AppLanguage.english:
          'Download failed. Check the internet and try again.',
      AppLanguage.urdu:
          'ڈاؤن لوڈ ناکام ہوا۔ انٹرنیٹ چیک کریں اور دوبارہ کوشش کریں۔',
    },
    'updateRetry': {
      AppLanguage.english: 'Try Again',
      AppLanguage.urdu: 'دوبارہ کوشش کریں',
    },
    'updateCheckFailed': {
      AppLanguage.english:
          'Update check could not be done. The app is opening with the current version.',
      AppLanguage.urdu:
          'اپ ڈیٹ چیک نہیں ہو سکا۔ ایپ موجودہ ورژن کے ساتھ کھل رہی ہے۔',
    },
    'updateInstallNote': {
      AppLanguage.english:
          'When asked, tap Install. If the phone asks, allow this app to install apps — a one-time setting.',
      AppLanguage.urdu:
          'جب پوچھا جائے تو انسٹال دبائیں۔ اگر فون پوچھے تو اس ایپ کو ایپس انسٹال کرنے کی اجازت دیں — یہ ایک بار کی سیٹنگ ہے۔',
    },
    'updateOpenInstallerFailed': {
      AppLanguage.english:
          'Installer did not open. Allow this app to install apps in Settings, then press Try Again.',
      AppLanguage.urdu:
          'انسٹالر نہیں کھلا۔ سیٹنگز میں اس ایپ کو ایپس انسٹال کرنے کی اجازت دیں، پھر دوبارہ کوشش کریں۔',
    },

    // --- Calling (V2) — merged from call_strings.dart, 19 Nov 2026 ---
    // All call strings (in-call screen + contacts) live here now;
    // call_strings.dart is deleted. English + Urdu script only.

    'calls': {
      AppLanguage.english: 'Calls',
      AppLanguage.urdu: 'کالز',
    },
    'callContacts': {
      AppLanguage.english: 'Call a vaccinator or supervisor',
      AppLanguage.urdu: 'کسی ویکسینیٹر یا سپروائزر کو کال کریں',
    },
    'online': {
      AppLanguage.english: 'Online',
      AppLanguage.urdu: 'آن لائن',
    },
    'offline': {
      AppLanguage.english: 'Offline',
      AppLanguage.urdu: 'آف لائن',
    },
    'audioCall': {
      AppLanguage.english: 'Audio Call',
      AppLanguage.urdu: 'آڈیو کال',
    },
    'videoCall': {
      AppLanguage.english: 'Video Call',
      AppLanguage.urdu: 'ویڈیو کال',
    },
    'incomingCall': {
      AppLanguage.english: 'Incoming call',
      AppLanguage.urdu: 'آنے والی کال',
    },
    'calling': {
      AppLanguage.english: 'Calling…',
      AppLanguage.urdu: 'کال کی جا رہی ہے…',
    },
    'connecting': {
      AppLanguage.english: 'Connecting…',
      AppLanguage.urdu: 'رابطہ ہو رہا ہے…',
    },
    'accept': {
      AppLanguage.english: 'Accept',
      AppLanguage.urdu: 'قبول کریں',
    },
    'decline': {
      AppLanguage.english: 'Decline',
      AppLanguage.urdu: 'مسترد کریں',
    },
    'endCall': {
      AppLanguage.english: 'End Call',
      AppLanguage.urdu: 'کال ختم کریں',
    },
    'mute': {
      AppLanguage.english: 'Mute',
      AppLanguage.urdu: 'خاموش',
    },
    'unmute': {
      AppLanguage.english: 'Unmute',
      AppLanguage.urdu: 'آواز کھولیں',
    },
    'speaker': {
      AppLanguage.english: 'Speaker',
      AppLanguage.urdu: 'اسپیکر',
    },
    'cameraOff': {
      AppLanguage.english: 'Camera Off',
      AppLanguage.urdu: 'کیمرہ بند',
    },
    'cameraOn': {
      AppLanguage.english: 'Camera On',
      AppLanguage.urdu: 'کیمرہ کھولیں',
    },
    'shareScreen': {
      AppLanguage.english: 'Share Screen',
      AppLanguage.urdu: 'اسکرین شیئر کریں',
    },
    'stopSharing': {
      AppLanguage.english: 'Stop Sharing',
      AppLanguage.urdu: 'شیئرنگ روکیں',
    },
    'sharingScreen': {
      AppLanguage.english: 'Sharing your screen',
      AppLanguage.urdu: 'آپ اپنی اسکرین شیئر کر رہے ہیں',
    },
    'viewingScreen': {
      AppLanguage.english: 'Viewing shared screen',
      AppLanguage.urdu: 'مشترکہ اسکرین دیکھی جا رہی ہے',
    },
    'screenShareHelp': {
      AppLanguage.english:
          'Share your screen to explain something, or watch the other person’s screen to understand it.',
      AppLanguage.urdu:
          'کچھ سمجھانے کے لیے اپنی اسکرین شیئر کریں، یا سمجھنے کے لیے دوسرے شخص کی اسکرین دیکھیں۔',
    },
    'noAnswer': {
      AppLanguage.english: 'No answer — the other person did not pick up.',
      AppLanguage.urdu: 'جواب نہیں ملا — دوسرے شخص نے کال نہیں اٹھائی۔',
    },
    'callEnded': {
      AppLanguage.english: 'Call ended',
      AppLanguage.urdu: 'کال ختم ہو گئی',
    },
    'callFailed': {
      AppLanguage.english: 'Call could not connect. Check your internet and try again.',
      AppLanguage.urdu:
          'کال نہیں مل سکی۔ اپنا انٹرنیٹ چیک کریں اور دوبارہ کوشش کریں۔',
    },
    'callNeedsInternet': {
      AppLanguage.english:
          'Calls need the internet. Both people must have the app and be online.',
      AppLanguage.urdu:
          'کال کے لیے انٹرنیٹ ضروری ہے۔ دونوں افراد کے پاس ایپ ہونی چاہیے اور وہ آن لائن ہوں۔',
    },
    'screenSharePrompt': {
      AppLanguage.english:
          'Your phone will ask permission to share the screen. Allow it to start sharing.',
      AppLanguage.urdu:
          'آپ کا فون اسکرین شیئر کرنے کی اجازت مانگے گا۔ شیئرنگ شروع کرنے کے لیے اجازت دیں۔',
    },
    // --- Calling (V2) — contacts list, wired 19 Nov 2026 ---
    // Tapping a call button shows the setup-pending message until
    // Firebase signalling is connected (see call_service.dart).
    // Supervisors are not in the All Vaccinators Profile roster
    // yet, so they have no contact row until the admin adds the
    // supervisor list — the empty note below says so honestly.
    'cardCallsTitle': {
      AppLanguage.english: 'Calls',
      AppLanguage.urdu: 'کالز',
    },
    'cardCallsSub': {
      AppLanguage.english:
          'Call the admin, a supervisor or a vaccinator',
      AppLanguage.urdu: 'ایڈمن، سپروائزر یا ویکسینیٹر کو کال کریں',
    },
    'callsSearch': {
      AppLanguage.english: 'Search by name or UC',
      AppLanguage.urdu: 'نام یا یونین کونسل سے تلاش کریں',
    },
    'callsAdminSection': {
      AppLanguage.english: 'Admin',
      AppLanguage.urdu: 'ایڈمن',
    },
    'callsVaccinatorsSection': {
      AppLanguage.english: 'Vaccinators',
      AppLanguage.urdu: 'ویکسینیٹرز',
    },
    'callsSupervisorsSection': {
      AppLanguage.english: 'Supervisors',
      AppLanguage.urdu: 'سپروائزرز',
    },
    'callsSupervisorsEmpty': {
      AppLanguage.english:
          'Supervisor contacts are not in the app yet. The admin will add the supervisor list, then supervisors will appear here.',
      AppLanguage.urdu:
          'سپروائزرز کے رابطے ابھی ایپ میں نہیں ہیں۔ ایڈمن سپروائزرز کی فہرست شامل کرے گا، پھر سپروائزر یہاں نظر آئیں گے۔',
    },
    'roleAdmin': {
      AppLanguage.english: 'Admin',
      AppLanguage.urdu: 'ایڈمن',
    },
    'roleVaccinator': {
      AppLanguage.english: 'Vaccinator',
      AppLanguage.urdu: 'ویکسینیٹر',
    },
    'roleSupervisor': {
      AppLanguage.english: 'Supervisor',
      AppLanguage.urdu: 'سپروائزر',
    },
    'callsOfflineList': {
      AppLanguage.english:
          'No internet — showing the saved list.',
      AppLanguage.urdu:
          'انٹرنیٹ نہیں ہے — محفوظ شدہ فہرست دکھائی جا رہی ہے۔',
    },
    'callsRosterEmpty': {
      AppLanguage.english:
          'No contacts found. Check the internet and try again.',
      AppLanguage.urdu:
          'کوئی رابطہ نہیں ملا۔ انٹرنیٹ چیک کریں اور دوبارہ کوشش کریں۔',
    },
    'callsNoMatch': {
      AppLanguage.english: 'No one matches this search.',
      AppLanguage.urdu: 'اس تلاش سے کوئی نہیں ملا۔',
    },
    'callSetupPendingTitle': {
      AppLanguage.english: 'Calling Not Set Up Yet',
      AppLanguage.urdu: 'کالنگ ابھی سیٹ اپ نہیں ہوئی',
    },
    'callSetupPending': {
      AppLanguage.english:
          'Calling setup is still pending — the call server (Firebase signalling) still has to be connected. No call can be placed yet.',
      AppLanguage.urdu:
          'کالنگ کی سیٹ اپ ابھی باقی ہے — کال سرور (فائر بیس سگنلنگ) ابھی جوڑنا باقی ہے۔ ابھی کال نہیں ہو سکتی۔',
    },
    // --- Calling (V2) — Firebase signalling, implemented 19 Nov 2026 ---
    // Shown when a call is attempted but the call server itself
    // is not connected (no google-services.json yet, or no net).
    'callServerError': {
      AppLanguage.english:
          'Call server is not connected yet. The admin still has to connect Firebase (google-services.json).',
      AppLanguage.urdu:
          'کال سرور ابھی جڑا نہیں ہے۔ ایڈمن کو ابھی فائر بیس جوڑنا باقی ہے (google-services.json)۔',
    },
    'okButton': {
      AppLanguage.english: 'OK',
      AppLanguage.urdu: 'ٹھیک ہے',
    },

    // --- My Data (user order, 19 Nov 2026 — PRIVACY RULE) ---
    // Each vaccinator sees ONLY their own UC's data. The UC comes
    // from the login only — there is no UC picker, no search and no
    // "all UCs" view. English + Urdu script only, no Roman Urdu.
    'myDataTitle': {
      AppLanguage.english: 'My Data',
      AppLanguage.urdu: 'میرا ڈیٹا',
    },
    'cardMyDataTitle': {
      AppLanguage.english: 'My Data',
      AppLanguage.urdu: 'میرا ڈیٹا',
    },
    'cardMyDataSub': {
      AppLanguage.english: 'Your own UC — attendance, doses, record',
      AppLanguage.urdu: 'اپنی یونین کونسل — حاضری، خوراکیں، ریکارڈ',
    },
    'myDataPrivacy': {
      AppLanguage.english:
          'This is only YOUR data — your own union council. You cannot see any other UC or vaccinator here.',
      AppLanguage.urdu:
          'یہ صرف آپ کا ڈیٹا ہے — آپ کی اپنی یونین کونسل۔ آپ یہاں کسی دوسری یونین کونسل یا ویکسینیٹر کا ڈیٹا نہیں دیکھ سکتے۔',
    },
    'myDataMonth': {
      AppLanguage.english: 'Month',
      AppLanguage.urdu: 'مہینہ',
    },
    'myDataOffline': {
      AppLanguage.english:
          'No internet — showing the last saved data for your UC. Pull to refresh when the internet returns.',
      AppLanguage.urdu:
          'انٹرنیٹ نہیں ہے — آپ کی یونین کونسل کا آخری محفوظ ڈیٹا دکھایا جا رہا ہے۔ انٹرنیٹ آتے ہی ریفریش کریں۔',
    },
    'myDataLoadFailed': {
      AppLanguage.english:
          'Your data could not be loaded. Check the internet and press Refresh — no other UC’s data is ever shown here.',
      AppLanguage.urdu:
          'آپ کا ڈیٹا لوڈ نہیں ہو سکا۔ انٹرنیٹ چیک کریں اور ریفریش دبائیں — یہاں کسی دوسری یونین کونسل کا ڈیٹا کبھی نہیں دکھایا جاتا۔',
    },
    'myDataAttendance': {
      AppLanguage.english: 'My Attendance',
      AppLanguage.urdu: 'میری حاضری',
    },
    'myDataPresentDays': {
      AppLanguage.english: 'Present: {n} days this month',
      AppLanguage.urdu: 'حاضری: اس مہینے {n} دن',
    },
    'myDataCheckIn': {
      AppLanguage.english: 'In:',
      AppLanguage.urdu: 'آمد:',
    },
    'myDataCheckOut': {
      AppLanguage.english: 'Out:',
      AppLanguage.urdu: 'روانگی:',
    },
    'myDataNoAttendance': {
      AppLanguage.english: 'No attendance record for this month yet.',
      AppLanguage.urdu: 'اس مہینے کی حاضری کا ابھی کوئی ریکارڈ نہیں ہے۔',
    },
    'myDataDoses': {
      AppLanguage.english: 'My Doses by Antigen',
      AppLanguage.urdu: 'میری خوراکیں بلحاظ ویکسین',
    },
    'myDataTotal': {
      AppLanguage.english: 'Total doses (outreach): {n}',
      AppLanguage.urdu: 'کل خوراکیں (آؤٹ ریچ): {n}',
    },
    'myDataAllAntigens': {
      AppLanguage.english: 'All 21 antigens (outreach)',
      AppLanguage.urdu: 'تمام 21 ویکسینز (آؤٹ ریچ)',
    },
    'myDataNoDoses': {
      AppLanguage.english: 'No doses recorded for your UC this month yet.',
      AppLanguage.urdu: 'اس مہینے آپ کی یونین کونسل کی ابھی کوئی خوراک درج نہیں ہوئی۔',
    },
    'myDataDailyReportNote': {
      AppLanguage.english:
          'These are the official month-to-date figures from the Summary sheet. Reports you send from this app will appear here too once the Daily Report tab is added on the server.',
      AppLanguage.urdu:
          'یہ سمری شیٹ کے مہینے کے سرکاری اعداد ہیں۔ اس ایپ سے بھیجی گئی رپورٹس بھی یہاں نظر آئیں گی جب سرور پر ڈیلی رپورٹ ٹیب شامل ہو جائے گا۔',
    },
    'myDataUcSummary': {
      AppLanguage.english: 'My UC Summary',
      AppLanguage.urdu: 'میری یونین کونسل کا خلاصہ',
    },
    'myDataOutreach': {
      AppLanguage.english: 'Outreach',
      AppLanguage.urdu: 'آؤٹ ریچ',
    },
    'myDataFixed': {
      AppLanguage.english: 'Fixed',
      AppLanguage.urdu: 'فکسڈ',
    },
    'myDataCombined': {
      AppLanguage.english: 'Total',
      AppLanguage.urdu: 'کل',
    },
    'myDataNoFixed': {
      AppLanguage.english: 'No fixed-site doses for your UC this month yet.',
      AppLanguage.urdu: 'اس مہینے آپ کی یونین کونسل کی فکسڈ سائٹ کی ابھی کوئی خوراک نہیں ہے۔',
    },
    'myDataRecord': {
      AppLanguage.english: 'My Service Record',
      AppLanguage.urdu: 'میرا سروس ریکارڈ',
    },
    'myDataNoRecord': {
      AppLanguage.english: 'No letter on your record.',
      AppLanguage.urdu: 'آپ کے ریکارڈ پر کوئی خط نہیں ہے۔',
    },
    'myDataLeave': {
      AppLanguage.english: 'My Leave',
      AppLanguage.urdu: 'میری چھٹی',
    },
    'myDataBalance': {
      AppLanguage.english:
          'This month: {m} / {max}  ·  Remaining this year: {remaining}',
      AppLanguage.urdu:
          'اس مہینے: {m} / {max}  ·  اس سال باقی: {remaining}',
    },
    'myDataNoLeave': {
      AppLanguage.english: 'No leave this month.',
      AppLanguage.urdu: 'اس مہینے کوئی چھٹی نہیں ہے۔',
    },
    'myDataRefresh': {
      AppLanguage.english: 'Refresh',
      AppLanguage.urdu: 'ریفریش کریں',
    },
    // --- My Microplan in My Data (user order, 19 Nov 2026;
    // files received + audited 20 Nov 2026) ---
    // Only the logged-in vaccinator's OWN UC file, downloaded on
    // demand — never the whole 58 MB, never another UC's file.
    // English + Urdu script only, no Roman Urdu.
    'microplanTitle': {
      AppLanguage.english: 'My Microplan',
      AppLanguage.urdu: 'میرا مائیکروپلان',
    },
    'microplanSub': {
      AppLanguage.english: '{uc} · {tehsil} · {year}',
      AppLanguage.urdu: '{uc} · {tehsil} · {year}',
    },
    'microplanVaccinator': {
      AppLanguage.english: 'Vaccinator',
      AppLanguage.urdu: 'ویکسینیٹر',
    },
    'microplanPopulation': {
      AppLanguage.english: 'Population',
      AppLanguage.urdu: 'آبادی',
    },
    'microplanVillages': {
      AppLanguage.english: 'Villages',
      AppLanguage.urdu: 'گاؤں / محلے',
    },
    'microplanAreas': {
      AppLanguage.english: 'Plan areas',
      AppLanguage.urdu: 'منصوبے کے علاقے',
    },
    'microplanSessions': {
      AppLanguage.english: 'Sessions',
      AppLanguage.urdu: 'سیشنز',
    },
    'microplanSheets': {
      AppLanguage.english: 'Sheets',
      AppLanguage.urdu: 'شیٹس',
    },
    'microplanFileSize': {
      AppLanguage.english: 'File size',
      AppLanguage.urdu: 'فائل کا سائز',
    },
    'microplanDownload': {
      AppLanguage.english: 'Download Microplan ({size})',
      AppLanguage.urdu: 'مائیکروپلان ڈاؤن لوڈ کریں ({size})',
    },
    'microplanOpen': {
      AppLanguage.english: 'Open Microplan',
      AppLanguage.urdu: 'مائیکروپلان کھولیں',
    },
    'microplanSaved': {
      AppLanguage.english: 'Saved on this phone ✓',
      AppLanguage.urdu: 'اس فون پر محفوظ ہے ✓',
    },
    'microplanDownloading': {
      AppLanguage.english: 'Downloading… {pct}%',
      AppLanguage.urdu: 'ڈاؤن لوڈ ہو رہا ہے… {pct}٪',
    },
    'microplanDownloadFailed': {
      AppLanguage.english:
          'Download failed — check the internet and try again.',
      AppLanguage.urdu:
          'ڈاؤن لوڈ ناکام — انٹرنیٹ چیک کریں اور دوبارہ کوشش کریں۔',
    },
    'microplanOpenFailed': {
      AppLanguage.english:
          'Could not open the file — install a spreadsheet app (Excel / Google Sheets) and try again.',
      AppLanguage.urdu:
          'فائل نہیں کھل سکی — سپریڈشیٹ ایپ (ایکسل / گوگل شیٹس) انسٹال کریں اور دوبارہ کوشش کریں۔',
    },
    'microplanNotFound': {
      AppLanguage.english:
          'Your UC’s microplan is not in the app yet. It will appear here when the microplan files are published on the site.',
      AppLanguage.urdu:
          'آپ کی یونین کونسل کا مائیکروپلان ابھی ایپ میں نہیں ہے۔ جب مائیکروپلان فائلیں سائٹ پر شائع ہوں گی تو یہ یہاں نظر آئے گا۔',
    },
    'microplanConverting': {
      AppLanguage.english:
          'This file is an old .xls file and is being converted to .xlsx — it will be available here soon.',
      AppLanguage.urdu:
          'یہ فائل پرانی .xls فائل ہے اور .xlsx میں تبدیل کی جا رہی ہے — جلد یہاں دستیاب ہوگی۔',
    },
    'microplanNeedInternet': {
      AppLanguage.english:
          'Internet is needed to download the microplan the first time. After that it opens offline.',
      AppLanguage.urdu:
          'مائیکروپلان پہلی بار ڈاؤن لوڈ کرنے کے لیے انٹرنیٹ ضروری ہے۔ اس کے بعد یہ آف لائن کھل جائے گا۔',
    },
    // --- Message Parents (free, user question, 19 Nov 2026) ---
    'cardMsgTitle': {
      AppLanguage.english: 'Message Parents',
      AppLanguage.urdu: 'والدین کو پیغام',
    },
    'cardMsgSub': {
      AppLanguage.english: 'Free message to parents via WhatsApp',
      AppLanguage.urdu: 'واٹس ایپ کے ذریعے والدین کو مفت پیغام',
    },
    'msgTitle': {
      AppLanguage.english: 'Message Parents',
      AppLanguage.urdu: 'والدین کو پیغام',
    },
    'msgSearch': {
      AppLanguage.english: 'Search by child or father name…',
      AppLanguage.urdu: 'بچے یا والد کے نام سے تلاش کریں…',
    },
    'msgNoChildren': {
      AppLanguage.english: 'No children found for your UC this month.',
      AppLanguage.urdu: 'اس مہینے آپ کی یو سی میں کوئی بچہ نہیں ملا۔',
    },
    'msgLoadFail': {
      AppLanguage.english:
          'Could not load the children list. Check the internet — the EMR sheet must be shared for viewing.',
      AppLanguage.urdu:
          'بچوں کی فہرست نہیں کھل سکی۔ انٹرنیٹ چیک کریں — ای ایم آر شیٹ دیکھنے کے لیے شیئر ہونی چاہیے۔',
    },
    'msgOffline': {
      AppLanguage.english:
          'No internet — showing the last saved list for your UC.',
      AppLanguage.urdu:
          'انٹرنیٹ نہیں ہے — آپ کی یو سی کی آخری محفوظ شدہ فہرست دکھائی جا رہی ہے۔',
    },
    'msgNoPhone': {
      AppLanguage.english: 'No number',
      AppLanguage.urdu: 'نمبر نہیں ہے',
    },
    'msgNextDue': {
      AppLanguage.english: 'Next vaccine due',
      AppLanguage.urdu: 'اگلی ویکسین',
    },
    'msgAllDone': {
      AppLanguage.english: 'All vaccines done',
      AppLanguage.urdu: 'تمام ویکسین مکمل ہیں',
    },
    'msgMessage': {
      AppLanguage.english: 'Message',
      AppLanguage.urdu: 'پیغام بھیجیں',
    },
    'msgChildOf': {
      AppLanguage.english: 'S/O',
      AppLanguage.urdu: 'ولد',
    },
    'msgPhone': {
      AppLanguage.english: 'Parent mobile number',
      AppLanguage.urdu: 'والدین کا موبائل نمبر',
    },
    'msgTemplate': {
      AppLanguage.english: 'Message type',
      AppLanguage.urdu: 'پیغام کی قسم',
    },
    'msgTpl_due': {
      AppLanguage.english: 'Next vaccine due',
      AppLanguage.urdu: 'اگلی ویکسین کی یاد دہانی',
    },
    'msgTpl_missed': {
      AppLanguage.english: 'Missed vaccine',
      AppLanguage.urdu: 'رہ گئی ویکسین',
    },
    'msgTpl_verification': {
      AppLanguage.english: 'Could not reach you',
      AppLanguage.urdu: 'رابطہ نہیں ہو سکا',
    },
    'msgTpl_custom': {
      AppLanguage.english: 'Write your own',
      AppLanguage.urdu: 'اپنا پیغام لکھیں',
    },
    'msgVaccine': {
      AppLanguage.english: 'Vaccine',
      AppLanguage.urdu: 'ویکسین',
    },
    'msgDate': {
      AppLanguage.english: 'Date (DD-MM-YYYY)',
      AppLanguage.urdu: 'تاریخ (DD-MM-YYYY)',
    },
    'msgCustomHint': {
      AppLanguage.english: 'Write your message',
      AppLanguage.urdu: 'اپنا پیغام لکھیں',
    },
    'msgPreview': {
      AppLanguage.english: 'Preview',
      AppLanguage.urdu: 'جائزہ',
    },
    'msgSendWhatsApp': {
      AppLanguage.english: 'Send via WhatsApp (free)',
      AppLanguage.urdu: 'واٹس ایپ سے بھیجیں (مفت)',
    },
    'msgSendSms': {
      AppLanguage.english: 'Send via SMS',
      AppLanguage.urdu: 'ایس ایم ایس سے بھیجیں',
    },
    'msgOpenedWhatsApp': {
      AppLanguage.english:
          'WhatsApp opened — press Send there. The message goes from your own WhatsApp number.',
      AppLanguage.urdu:
          'واٹس ایپ کھل گیا — وہاں Send دبائیں۔ پیغام آپ کے اپنے واٹس ایپ نمبر سے جائے گا۔',
    },
    'msgWhatsAppMissing': {
      AppLanguage.english: 'WhatsApp is not installed — try SMS instead.',
      AppLanguage.urdu: 'واٹس ایپ انسٹال نہیں ہے — ایس ایم ایس سے بھیجیں۔',
    },
    'msgOpenedSms': {
      AppLanguage.english: 'SMS composer opened — press Send there.',
      AppLanguage.urdu: 'ایس ایم ایس کھل گیا — وہاں Send دبائیں۔',
    },
    'msgSendFailed': {
      AppLanguage.english:
          'Could not open WhatsApp or SMS. Check the number and try again.',
      AppLanguage.urdu:
          'واٹس ایپ یا ایس ایم ایس نہیں کھل سکا۔ نمبر چیک کر کے دوبارہ کوشش کریں۔',
    },
    'msgFreeNote': {
      AppLanguage.english:
          'Free: WhatsApp uses only mobile data and sends from your own WhatsApp number. SMS costs what your own mobile package charges. One message at a time — no bulk sending.',
      AppLanguage.urdu:
          'مفت: واٹس ایپ صرف موبائل ڈیٹا استعمال کرتا ہے اور پیغام آپ کے اپنے واٹس ایپ نمبر سے جاتا ہے۔ ایس ایم ایس پر آپ کے اپنے موبائل پیکیج کے چارجز لگتے ہیں۔ ایک وقت میں ایک پیغام — اجتماعی پیغام نہیں بھیجے جا سکتے۔',
    },
    'msgCount': {
      AppLanguage.english: '{n} children in your UC',
      AppLanguage.urdu: 'آپ کی یو سی میں {n} بچے',
    },
    // --- Daily Reports in-app (user order, 19 Nov 2026) ---
    'cardReportsTitle': {
      AppLanguage.english: 'Daily Reports',
      AppLanguage.urdu: 'روزانہ رپورٹس',
    },
    'cardReportsSub': {
      AppLanguage.english: "Today's reports for your UC",
      AppLanguage.urdu: 'آج کی رپورٹس — آپ کی یونین کونسل',
    },
    'reportsTitle': {
      AppLanguage.english: 'Daily Reports',
      AppLanguage.urdu: 'روزانہ رپورٹس',
    },
    'reportsToday': {
      AppLanguage.english: "Today's reports",
      AppLanguage.urdu: 'آج کی رپورٹس',
    },
    'reportsPast': {
      AppLanguage.english: 'Previous days',
      AppLanguage.urdu: 'پچھلے دن',
    },
    'reportsPrivacy': {
      AppLanguage.english:
          'Only your UC’s reports are shown here — plus district reports. You cannot see another UC’s reports.',
      AppLanguage.urdu:
          'یہاں صرف آپ کی یونین کونسل کی رپورٹس دکھائی جاتی ہیں — اور ضلع کی رپورٹس۔ آپ کسی دوسری یونین کونسل کی رپورٹ نہیں دیکھ سکتے۔',
    },
    'reportsOffline': {
      AppLanguage.english:
          'No internet — showing the last saved reports.',
      AppLanguage.urdu:
          'انٹرنیٹ نہیں ہے — آخری محفوظ رپورٹس دکھائی جا رہی ہیں۔',
    },
    'reportsEmpty': {
      AppLanguage.english:
          'No reports for today yet — they arrive every morning after 3:00 AM.',
      AppLanguage.urdu:
          'آج کی رپورٹس ابھی نہیں آئیں — وہ ہر صبح 3 بجے کے بعد آتی ہیں۔',
    },
    'reportsLoadFailed': {
      AppLanguage.english:
          'Reports could not be loaded. Check the internet and pull to refresh.',
      AppLanguage.urdu:
          'رپورٹس لوڈ نہیں ہو سکیں۔ انٹرنیٹ چیک کریں اور نیچے کھینچ کر ریفریش کریں۔',
    },
    'reportsDownload': {
      AppLanguage.english: 'Save offline',
      AppLanguage.urdu: 'آف لائن محفوظ کریں',
    },
    'reportsSaved': {
      AppLanguage.english: 'Saved on the phone — you can open it offline.',
      AppLanguage.urdu: 'فون میں محفوظ ہو گئی — آف لائن بھی کھل جائے گی۔',
    },
    'reportsDistrict': {
      AppLanguage.english: 'District report',
      AppLanguage.urdu: 'ضلع کی رپورٹ',
    },
    'reportsMyUc': {
      AppLanguage.english: 'Your UC: {uc}',
      AppLanguage.urdu: 'آپ کی یونین کونسل: {uc}',
    },
    'reportsOpenFailed': {
      AppLanguage.english:
          'Could not open this file. Check the internet and try again.',
      AppLanguage.urdu:
          'یہ فائل نہیں کھل سکی۔ انٹرنیٹ چیک کریں اور دوبارہ کوشش کریں۔',
    },
    'reportsNoViewer': {
      AppLanguage.english:
          'Could not open this PDF — no app on the phone can open it. Install a PDF viewer and try again.',
      AppLanguage.urdu:
          'یہ پی ڈی ایف نہیں کھل سکی — فون میں کوئی ایپ اسے نہیں کھول سکتی۔ پی ڈی ایف دیکھنے والی ایپ انسٹال کریں اور دوبارہ کوشش کریں۔',
    },
    'reportsPipelineNote': {
      AppLanguage.english:
          'Reports are published every morning by the district pipeline, after 3:00 AM.',
      AppLanguage.urdu:
          'رپورٹس ہر صبح 3 بجے کے بعد ضلع کی پائپ لائن سے شائع ہوتی ہیں۔',
    },
  };

  static String get(AppLanguage lang, String key) =>
      _values[key]?[lang] ??
      _values[key]?[AppLanguage.english] ??
      key;

  /// All keys, for tests / verification that every key has both
  /// languages. Every key must have an 'en' and a 'ur' value.
  static Iterable<String> get keys => _values.keys;

  static bool get isComplete => _values.values.every(
      (m) => m.containsKey(AppLanguage.english) && m.containsKey(AppLanguage.urdu));
}
