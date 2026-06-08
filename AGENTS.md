# Smart Receipt AI — Agent Guide

This document describes the project structure, conventions, and commands that AI coding agents need to know when working on this codebase.

## Project Overview

**Smart Receipt AI** is a Flutter mobile application for AI-powered receipt scanning and Malaysian expense tracking. It supports:

- Live edge-detection receipt scanning with OCR (Google ML Kit)
- LLM-powered receipt field extraction (OpenRouter API) with a local heuristic fallback
- Manual receipt creation and editing
- Bank statement import from PDF/CSV (supports TNG eWallet, Maybank, CIMB, Public Bank)
- Spending reports with donut charts, bar charts, date-range filtering, and personal/business splits
- CSV and PDF export with system share sheet
- Multi-account local authentication (password, PIN, biometric)
- Encrypted local data storage with per-account receipt ownership
- Receipt archiving with SHA-256 integrity verification and lock protection

The app targets **Android** and **iOS**. Currency defaults to **MYR** and the UI is built around Malaysian financial context.

## Technology Stack

| Layer | Technology |
|-------|------------|
| Framework | Flutter (Dart SDK `^3.11.4`) |
| State Management | `flutter_riverpod` (NotifierProvider, Provider, ProviderFamily) |
| Local Database | `hive` + `hive_flutter` with AES encryption (`HiveAesCipher`) |
| Secure Storage | `flutter_secure_storage` (Android encrypted shared prefs, iOS keychain) |
| Biometrics | `local_auth` |
| OCR | `google_mlkit_text_recognition` |
| Camera / Scanning | `camera`, `flutter_edge_detection`, `image_picker` |
| PDF | `pdf` (export), `syncfusion_flutter_pdf` (import text extraction) |
| Charts | `fl_chart` |
| Networking | `http` (OpenRouter API) |
| Environment | `flutter_dotenv` (`.env` file loaded at startup) |

## Project Structure

```
lib/
├── main.dart                 # Entry point: init Hive, security, storage, Riverpod scope
├── models/                   # Immutable data classes with Hive TypeAdapters
│   ├── receipt.dart          # Receipt + ReceiptItem + Adapters (typeId 1, 2)
│   ├── imported_transaction.dart
│   ├── receipt_archive.dart
│   └── user_preferences.dart
├── services/                 # Pure business logic, no UI
│   ├── local_storage_service.dart   # Encrypted Hive boxes, image archival, hashing
│   ├── security_service.dart        # Accounts, passwords, biometrics, Hive key
│   ├── ocr_service.dart             # ML Kit text extraction
│   ├── llm_service.dart             # OpenRouter parsing + local fallback
│   ├── export_service.dart          # CSV/PDF export + share
│   └── pdf_import_service.dart      # Bank statement PDF/CSV parsing
├── providers/                # Riverpod notifiers and computed providers
│   ├── receipt_provider.dart
│   ├── archive_provider.dart
│   ├── report_provider.dart
│   ├── security_provider.dart
│   └── settings_provider.dart
├── screens/                  # Full-page widgets
│   ├── app_shell.dart        # Bottom navigation shell (4 tabs: Receipts, Capture, Reports, Settings)
│   ├── security_gate.dart    # Routes to login/setup/main based on auth state
│   ├── login_screen.dart
│   ├── setup_security_screen.dart
│   ├── capture_screen.dart   # Edge-detection scanner launcher
│   ├── receipt_review_screen.dart   # OCR -> LLM -> editable receipt; also manual entry
│   ├── receipts_screen.dart  # List with search, chips, summary card
│   ├── receipt_detail_screen.dart   # View, verify hash, seal archive, edit, delete
│   ├── reports_screen.dart   # Charts, trend comparison, CSV/PDF export
│   ├── settings_screen.dart
│   ├── edit_profile_screen.dart
│   ├── archive_screen.dart   # Bulk verify/lock for tax compliance
│   └── statement_import_screen.dart
├── widgets/                  # Reusable UI components
│   ├── app_card.dart
│   ├── receipt_tile.dart
│   └── section_header.dart   # Also contains SoftIconButton
├── theme/
│   └── app_theme.dart        # Dark-only Material 3 theme
└── utils/
    └── formatters.dart       # Date, money, and name-initial helpers
```

## Key Architectural Patterns

### State Management
- All global state lives in Riverpod `NotifierProvider`s under `lib/providers/`.
- `LocalStorageService` and `SecurityService` are injected via `ProviderScope.overrides` in `main.dart`.
- Providers read services via `ref.read()` and watch account changes via `ref.watch(securityProvider.select(...))` to scope data per-account.

### Security & Encryption
- `SecurityService` generates/stores a 32-byte AES key in `flutter_secure_storage`.
- All Hive boxes are opened with `HiveAesCipher`.
- A one-time migration path exists for moving unencrypted legacy boxes to encrypted boxes.
- User credentials (passwords, PINs) are hashed with SHA-256. No plaintext secrets are stored.
- Biometric auth is optional and per-account.

### Multi-Account Data Isolation
- `_ownerships` Hive box maps `receiptId -> accountId`.
- `LocalStorageService` filters all receipts/archives by the current account ID.
- On first account creation, unowned receipts are claimed automatically.
- New accounts receive seeded demo receipts if they have no data.

### Receipt Archival & Integrity
- Every saved receipt gets a `ReceiptArchive` entry with:
  - `archivedImagePath`: copied into app documents under `receipt_archive/`
  - `sha256Hash`: computed from receipt fields + archived image bytes
  - `isLocked`: prevents edits/deletion when true
- `verifyReceipt` recomputes the hash and compares it to the stored value.

### Logging Convention
- Use `debugPrint` with a bracketed tag prefix, e.g.:
  ```dart
  debugPrint('[Capture] Starting scan. targetPath=$savePath');
  debugPrint('[Storage] upsertReceipt success id=${receipt.id}');
  debugPrint('[LLM] OpenRouter response status=${response.statusCode}');
  ```
- This makes it easy to grep logs by subsystem.

## Build & Run Commands

```bash
# Install dependencies
flutter pub get

# Run the app on a connected device / emulator
flutter run

# Run in release mode
flutter run --release

# Run static analysis
flutter analyze

# Run tests
flutter test

# Build APK
flutter build apk

# Build app bundle
flutter build appbundle

# Build iOS (macOS only)
flutter build ios
```

## Code Style Guidelines

- **Dart SDK**: `^3.11.4`. Use modern Dart features (pattern matching, switch expressions, records where appropriate).
- **Linting**: `analysis_options.yaml` includes `package:flutter_lints/flutter.yaml`. Do not disable lints project-wide unless necessary; prefer `// ignore: name_of_lint` for single-line exceptions.
- **Immutability**: Model classes are immutable with `final` fields and `copyWith` methods.
- **Hive Adapters**: Each model has a companion `TypeAdapter` with a hardcoded `typeId`. Do **not** change existing `typeId`s; adding new ones is safe.
- **Theme**: The app is **dark-only**. All colors come from `AppTheme` constants. Do not introduce light-theme assumptions.
- **Currency Formatting**: Use `utils/formatters.dart` (`money(...)`, `shortDate(...)`) rather than inline `NumberFormat`/`DateFormat` to stay consistent.
- **Error Handling**: Services should catch exceptions and return safe fallback values or throw descriptive `StateError`s with user-facing messages. Screens catch service errors and show `SnackBar`s.

## Testing

- The project has unit/widget tests under `test/`:
  - `widget_test.dart` — basic Flutter harness smoke test
  - `export_service_test.dart` — CSV/PDF export validation
  - `hash_verification_test.dart` — receipt hash consistency checks
  - `pdf_import_service_test.dart` — amount parsing and transaction extraction tests
- When adding features, prefer widget tests for screen flows and unit tests for service logic.
- Run tests with `flutter test`.

## Environment & Secrets

- The app loads `.env` at startup via `flutter_dotenv`. It is listed as a Flutter asset in `pubspec.yaml`.
- Expected variables:
  - `OPENROUTER_API_KEY` — API key for LLM receipt parsing
  - `OPENROUTER_MODEL` — model slug (defaults to `~google/gemini-flash-latest`)
- `.env` is blocked from version control by `.gitignore`. Never commit secrets.
- `flutter_secure_storage` is used for all sensitive persisted data (keys, password hashes, account metadata).

## Platform Notes

### Android
- `android/app/build.gradle.kts` uses `compileSdk`, `minSdk`, and `targetSdk` from the Flutter plugin.
- Java 17 compatibility is required (`sourceCompatibility = JavaVersion.VERSION_17`).
- The release build currently signs with the debug keystore. Replace before production distribution.

### iOS
- Standard Flutter iOS project under `ios/`.
- `local_auth` and `flutter_secure_storage` require proper `Info.plist` permissions and keychain entitlements.

## Adding New Features

- **New model?** Add it under `lib/models/`, create a `TypeAdapter` with a unique `typeId`, register it in `main.dart`, and update `LocalStorageService` if it needs persistence.
- **New screen?** Add it under `lib/screens/`. If it belongs in the main navigation, wire it into `AppShell`.
- **New service?** Add it under `lib/services/`. Keep it free of Flutter UI imports. If it needs to be overridden in tests, expose a `Provider`.
- **New provider?** Add it under `lib/providers/`. Follow the existing pattern of `NotifierProvider` for mutable state and `Provider` for derived/computed state.
- **New dependency?** Add it to `pubspec.yaml`, run `flutter pub get`, and document why it is needed in commit messages.

## Security Checklist for Agents

- Never log API keys, encryption keys, or password hashes.
- Never store credentials in plain Hive boxes — use `flutter_secure_storage`.
- When modifying `SecurityService`, preserve backward compatibility for legacy account migration paths.
- When modifying receipt/archive logic, ensure ownership checks (`_belongsToCurrentAccountId`) and locked-receipt guards remain intact.
- SHA-256 is used for integrity and local password hashing — do not mistake it for a slow hash suitable for server-side use.
