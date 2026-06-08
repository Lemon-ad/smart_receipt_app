# Smart Receipt AI

A Flutter mobile application for AI-powered receipt scanning and Malaysian expense tracking.

## Features

- **Live edge-detection receipt scanning** with OCR (Google ML Kit)
- **LLM-powered receipt field extraction** (OpenRouter API) with local heuristic fallback
- **Manual receipt creation and editing** with image replacement support
- **Tax and service charge tracking** (SST/GST) with automatic breakdown
- **Bank statement import** from PDF/CSV (TNG eWallet, Maybank, CIMB, Public Bank)
- **Spending reports** with donut charts, bar charts, weekly/monthly aggregation, and personal/business splits
- **Multi-account local authentication** (password, PIN, biometric)
- **Encrypted local data storage** with per-account receipt ownership
- **Receipt archiving** with SHA-256 integrity verification and lock protection

## Technology Stack

- **Framework:** Flutter (Dart SDK ^3.11.4)
- **State Management:** flutter_riverpod
- **Local Database:** hive + hive_flutter with AES encryption
- **OCR:** google_mlkit_text_recognition
- **Camera / Scanning:** camera, flutter_edge_detection, image_picker
- **Charts:** fl_chart
- **Networking:** http (OpenRouter API)

## Getting Started

```bash
# Install dependencies
flutter pub get

# iOS: apply plugin patches (required for Xcode 15+ / iOS 13+)
cd ios && pod install && cd ..
./patches/apply_ios_patches.sh

# Run the app
flutter run
```

## iOS Plugin Patches

This project requires manual patches to two CocoaPods dependencies for compatibility with **Xcode 15+** and **SceneDelegate-based apps** (iOS 13+):

| Patch | Target | Issue |
|-------|--------|-------|
| `patches/ios/WeScan_ImageScannerController.swift` | `ios/Pods/WeScan/WeScan/ImageScannerController.swift` | `@available` on stored properties is invalid in Swift 6. Converted to computed properties. |
| `patches/ios/FlutterEdgeDetection_SwiftEdgeDetectionPlugin.swift` | `ios/.symlinks/plugins/flutter_edge_detection/ios/Classes/SwiftEdgeDetectionPlugin.swift` | Uses deprecated `UIApplication.shared.delegate?.window` which is nil in SceneDelegate apps. Fixed to use `connectedScenes`. |
| `patches/ios/FlutterEdgeDetection_HomeViewController.swift` | `ios/.symlinks/plugins/flutter_edge_detection/ios/Classes/HomeViewController.swift` | Same SceneDelegate window lookup issue in gallery picker and button overlay. |

### Applying patches

Run the helper script after every `flutter pub get` + `pod install`:

```bash
./patches/apply_ios_patches.sh
```

Or apply manually by copying the files from `patches/ios/` to the targets listed above.

> **Note:** These patches are not committed to `ios/Pods/` or `.pub-cache/` (both are generated). The patched files are stored in `patches/ios/` and copied via the script.

## Build Commands

```bash
# Run static analysis
flutter analyze

# Run tests
flutter test

# Build APK
flutter build apk

# Build iOS (macOS only)
flutter build ios
```

## Environment

Create a `.env` file in the project root:

```
OPENROUTER_API_KEY=your_key_here
OPENROUTER_MODEL=~google/gemini-flash-latest
```

## License

Coursework project.
