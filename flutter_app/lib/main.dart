import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/db/database.dart';
import 'core/services/key_service.dart';
import 'core/services/ledger_service.dart';
import 'core/services/ots_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database
  final db = AppDatabase();

  // Initialize services
  final keyService = KeyService();
  await keyService.init();

  final ledgerService = LedgerService(db: db, keyService: keyService);
  final otsService = OtsService();

  runApp(
    MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: db),
        Provider<KeyService>.value(value: keyService),
        Provider<LedgerService>.value(value: ledgerService),
        Provider<OtsService>.value(value: otsService),
      ],
      child: const LedgerLiteApp(),
    ),
  );
}