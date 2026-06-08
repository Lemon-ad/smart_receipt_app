import 'package:flutter/material.dart';
import 'package:flutter_edge_detection/flutter_edge_detection.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/section_header.dart';
import 'receipt_review_screen.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  bool _processing = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Capture',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
        children: [
          const Text(
            'Live edge detection for clean receipt scans',
            style: TextStyle(
              color: AppTheme.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          AppCard(
            padding: const EdgeInsets.all(20),
            child: AspectRatio(
              aspectRatio: .78,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.panel2,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.all(26),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.cyan, width: 1.6),
                    ),
                  ),
                  Align(
                    alignment: Alignment.topLeft,
                    child: Container(
                      margin: const EdgeInsets.all(14),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .35),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 16,
                            color: AppTheme.cyan,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Real-time edge detection',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 82,
                          height: 82,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.accent.withValues(alpha: .18),
                            border: Border.all(
                              color: AppTheme.accent.withValues(alpha: .35),
                            ),
                          ),
                          child: const Icon(
                            Icons.document_scanner,
                            size: 38,
                            color: AppTheme.text,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Open native scanner',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 18),
                          child: Text(
                            'Detect receipt edges, auto-crop the page, and send the cleaned image into OCR and LLM extraction.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.muted,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_processing)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .45),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppTheme.rose)),
          ],
          const SizedBox(height: 18),
          const SectionHeader('Scan actions'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _processing ? null : _scanWithEdgeDetection,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Live Scan'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _processing ? null : _scanFromGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery Scan'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'What this adds',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 10),
                _ScanBenefit(
                  icon: Icons.crop_free,
                  text: 'Live edge detection and auto-cropping',
                ),
                _ScanBenefit(
                  icon: Icons.tune,
                  text: 'Perspective correction before OCR',
                ),
                _ScanBenefit(
                  icon: Icons.description_outlined,
                  text: 'Cleaner scans for tax-ready archiving',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _scanWithEdgeDetection() async {
    final allowed = await _ensureCameraPermission();
    if (!allowed) return;
    await _runScan(
      (path) => FlutterEdgeDetection.detectEdge(
        path,
        canUseGallery: false,
        androidScanTitle: 'Scan Receipt',
        androidCropTitle: 'Use Scan',
        androidCropBlackWhiteTitle: 'High Contrast',
        androidCropReset: 'Reset',
      ),
    );
  }

  Future<void> _scanFromGallery() async {
    final allowed = await _ensurePhotoLibraryPermission();
    if (!allowed) return;
    await _runScan(
      (path) => FlutterEdgeDetection.detectEdgeFromGallery(
        path,
        androidCropTitle: 'Use Scan',
        androidCropBlackWhiteTitle: 'High Contrast',
        androidCropReset: 'Reset',
      ),
    );
  }

  Future<void> _runScan(Future<bool> Function(String path) scanner) async {
    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      final savePath = await _nextScanPath();
      debugPrint('[Capture] Starting scan. targetPath=$savePath');
      final success = await scanner(savePath);
      debugPrint('[Capture] Scan finished. success=$success path=$savePath');
      if (!mounted) return;
      if (success) {
        debugPrint('[Capture] Opening review screen for $savePath');
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ReceiptReviewScreen(imagePath: savePath),
          ),
        );
      } else {
        debugPrint('[Capture] Scan returned false; review screen not opened.');
      }
    } on EdgeDetectionException catch (error) {
      debugPrint('[Capture] EdgeDetectionException: ${error.message}');
      _error = error.message;
    } catch (error) {
      debugPrint('[Capture] Scanner error: $error');
      _error = 'Unable to start the document scanner.';
    }
    if (mounted) {
      setState(() => _processing = false);
    }
  }

  Future<bool> _ensureCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      debugPrint('[Capture] Camera permission already granted.');
      return true;
    }

    final requested = await Permission.camera.request();
    debugPrint('[Capture] Camera permission request result=$requested');
    if (requested.isGranted) return true;

    if (!mounted) return false;
    final message = requested.isPermanentlyDenied
        ? 'Camera permission is blocked. Open app settings and allow Camera to scan receipts.'
        : 'Camera permission is required for live receipt scanning.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));

    if (requested.isPermanentlyDenied) {
      await openAppSettings();
    }
    return false;
  }

  Future<bool> _ensurePhotoLibraryPermission() async {
    final status = await Permission.photos.status;
    if (status.isGranted || status.isLimited) {
      debugPrint('[Capture] Photo library permission already granted.');
      return true;
    }

    final requested = await Permission.photos.request();
    debugPrint('[Capture] Photo library permission request result=$requested');
    if (requested.isGranted || requested.isLimited) return true;

    if (!mounted) return false;
    final message = requested.isPermanentlyDenied
        ? 'Photo library permission is blocked. Open app settings and allow Photos to import receipt images.'
        : 'Photo library permission is required to import receipt images.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));

    if (requested.isPermanentlyDenied) {
      await openAppSettings();
    }
    return false;
  }

  Future<String> _nextScanPath() async {
    final dir = await getApplicationSupportDirectory();
    return p.join(
      dir.path,
      'receipt_scan_${DateTime.now().millisecondsSinceEpoch}.jpeg',
    );
  }
}

class _ScanBenefit extends StatelessWidget {
  const _ScanBenefit({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.cyan),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(color: AppTheme.muted)),
          ),
        ],
      ),
    );
  }
}
