# Urdu font — Noori Nastaliq (how to supply the file)

## Rule (user order, 19 Nov 2026 — STANDING)

Urdu text in the app uses fontFamily **'Noori Nastaliq'**.
The code already asks for it first (`main.dart` theme), with
**'Noto Nastaliq Urdu'** as the fallback.

## Why there is no Noori file in this folder yet

No freely distributable Noori Nastaliq file exists:

- The original Noori Nastaliq (Ahmed Mirza Jamil / Monotype, 1980s)
  is a commercial font — no open licence.
- The TTF everyone downloads, "Jameel Noori Nastaleeq", is offered
  as **free for personal use only**, carries **no licence text in
  the file**, and its licence is **contested** (no authoritative
  release; Urdu Wikipedia calls it an unauthorised Noori
  derivative). It must NOT be bundled into a government district
  APK and distributed to 70 vaccinators on that basis.

So the file has to come from the user (their own licensed copy),
and **Noto Nastaliq Urdu (SIL Open Font License, Google Fonts)**
is bundled as the fallback ONLY — it is never the final font.

## What is bundled here (fallback only)

- `NotoNastaliqUrdu.ttf` — Noto Nastaliq Urdu, variable weight,
  downloaded from Google Fonts (`google/fonts`, OFL 1.1),
  19 Nov 2026. Declared in `pubspec.yaml` as family
  'Noto Nastaliq Urdu'. Until the Noori file is supplied, all Urdu
  text renders in this font — correct Nastaliq shaping, just not
  the Noori face.

## To enable Noori Nastaliq (one step, no code change)

1. Get a licensed copy of the font file (e.g. from the user's own
   InPage / licensed install) — file name:
   `JameelNooriNastaleeq.ttf` (or `NooriNastaliq.ttf`).
2. Put it in this folder: `flutter_app/assets/fonts/`.
3. In `flutter_app/pubspec.yaml`, uncomment the block under
   "TO ENABLE NOORI NASTALIQ" (keep the file name in sync).
4. Run `flutter pub get` and rebuild the APK (GitHub Actions).
   No Dart code change is needed — `main.dart` already uses
   fontFamily 'Noori Nastaliq' first when Urdu is chosen.

## How the fallback works in code

`main.dart` → `ThemeData`:
- Urdu chosen: `fontFamily: 'Noori Nastaliq'`,
  `fontFamilyFallback: ['Noto Nastaliq Urdu']`.
  With the Noori file bundled, Urdu renders in Noori Nastaliq.
  Without it, Flutter falls back to the bundled Noto Nastaliq
  Urdu — the app never shows broken / tofu Urdu text.
- English chosen: default system font (no Nastaliq applied).

Nastaliq needs tall line height: the theme sets the Urdu text
theme line height to 1.9 so the descending strokes are not
clipped. See `main.dart` (`_urduTextTheme`).
