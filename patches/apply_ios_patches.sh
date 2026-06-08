#!/bin/bash
# Apply iOS plugin patches after `flutter pub get` and `pod install`.
# These patches fix compatibility issues with newer Swift/Xcode and
# SceneDelegate-based apps on iOS 13+.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "[Patches] Applying iOS plugin patches..."

# Patch 1: WeScan - Fix @available on stored properties (Swift 6+ / Xcode 15+)
WESCAN_TARGET="$PROJECT_DIR/ios/Pods/WeScan/WeScan/ImageScannerController.swift"
if [ -f "$WESCAN_TARGET" ]; then
    cp "$SCRIPT_DIR/ios/WeScan_ImageScannerController.swift" "$WESCAN_TARGET"
    echo "[Patches] WeScan patched."
else
    echo "[Patches] Warning: WeScan target not found at $WESCAN_TARGET"
    echo "[Patches]          Run 'cd ios && pod install' first."
fi

# Patch 2: flutter_edge_detection - Fix SceneDelegate window lookup
PLUGIN_DIR="$PROJECT_DIR/ios/.symlinks/plugins/flutter_edge_detection/ios/Classes"

if [ -d "$PLUGIN_DIR" ]; then
    cp "$SCRIPT_DIR/ios/FlutterEdgeDetection_SwiftEdgeDetectionPlugin.swift" "$PLUGIN_DIR/SwiftEdgeDetectionPlugin.swift"
    cp "$SCRIPT_DIR/ios/FlutterEdgeDetection_HomeViewController.swift" "$PLUGIN_DIR/HomeViewController.swift"
    echo "[Patches] flutter_edge_detection patched."
else
    echo "[Patches] Warning: flutter_edge_detection target not found at $PLUGIN_DIR"
    echo "[Patches]          Run 'flutter pub get' first."
fi

echo "[Patches] Done."
