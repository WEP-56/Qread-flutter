# Qread Flutter

Flutter client for Qread (轻阅读), targeting Windows and Android.

## Scope

- Rebuild the original client from the open web client and backend API.
- Keep backend behavior unchanged.
- Deliver a Flutter desktop/mobile client with the same core reading flow.

## Repository Layout

- `lib/`: Flutter application code
- `doc/API.md`: backend API reference
- `doc/FEATURE_TODO.md`: feature checklist mapped to pages
- `doc/HANDOVER.md`: handover and project context
- `doc/DEVELOPMENT_BASELINE.md`: current engineering baseline and next milestones
- `Qread-source/`: reference web client/backend materials

## Current Baseline

- Login flow is connected.
- Bookshelf, discover, RSS, profile, search, and reader flows have partial implementation.
- Discover result page and source management page now have initial Flutter-side scaffolding.
- Flutter static analysis passes.

## Run

```bash
flutter pub get
flutter run -d windows
```

For Android:

```bash
flutter run -d android
```
