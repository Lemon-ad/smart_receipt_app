import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/imported_transaction.dart';
import 'models/receipt_archive.dart';
import 'models/receipt.dart';
import 'models/user_preferences.dart';
import 'screens/app_shell.dart';
import 'services/local_storage_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive
    ..registerAdapter(ReceiptItemAdapter())
    ..registerAdapter(ReceiptAdapter())
    ..registerAdapter(ImportedTransactionAdapter())
    ..registerAdapter(ReceiptArchiveAdapter())
    ..registerAdapter(UserPreferencesAdapter());
  final storage = LocalStorageService();
  await storage.init();
  await storage.seedIfEmpty();

  runApp(
    ProviderScope(
      overrides: [localStorageProvider.overrideWithValue(storage)],
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
      home: const AppShell(),
    );
  }
}
