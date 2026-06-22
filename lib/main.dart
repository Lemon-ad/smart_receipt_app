import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/imported_transaction.dart';
import 'models/receipt_archive.dart';
import 'models/receipt.dart';
import 'models/user_preferences.dart';
import 'services/local_storage_service.dart';
import 'services/security_service.dart';
import 'screens/security_gate.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load environment config before any API-backed service starts up.
  await dotenv.load(fileName: '.env');
  await Hive.initFlutter();
  // Hive adapters tell Hive how to serialize our custom models safely.
  Hive
    ..registerAdapter(ReceiptItemAdapter())
    ..registerAdapter(ReceiptAdapter())
    ..registerAdapter(ImportedTransactionAdapter())
    ..registerAdapter(ReceiptArchiveAdapter())
    ..registerAdapter(UserPreferencesAdapter());
  final securityService = SecurityService();
  // The Hive encryption key is created once and stored in secure storage so
  // the local database can stay encrypted across app launches.
  final encryptionKey = await securityService.getOrCreateHiveKey();
  final storage = LocalStorageService();
  await storage.init(
    encryptionKey: encryptionKey,
    migrateLegacy: !(await securityService.isHiveMigrationComplete()),
  );
  await securityService.markHiveMigrationComplete();
  await storage.seedIfEmpty();

  runApp(
    ProviderScope(
      // Riverpod gets its concrete service instances here, which keeps the
      // rest of the app decoupled from manual object wiring.
      overrides: [
        localStorageProvider.overrideWithValue(storage),
        securityServiceProvider.overrideWithValue(securityService),
      ],
      child: const SmartReceiptApp(),
    ),
  );
}

class SmartReceiptApp extends StatelessWidget {
  const SmartReceiptApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Receipt AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      // SecurityGate chooses whether the user sees setup, login, or the main
      // shell, so auth routing stays centralized at the root.
      home: const SecurityGate(),
    );
  }
}
