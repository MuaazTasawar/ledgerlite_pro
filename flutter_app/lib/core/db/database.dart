import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

// ─────────────────────────────────────────────────────────────
// TABLE DEFINITIONS
// ─────────────────────────────────────────────────────────────

/// LedgerEntries table — one row per signed ledger entry.
/// All crypto fields are stored as TEXT (hex strings or JSON).
class LedgerEntries extends Table {
  // Identity
  TextColumn get id => text()(); // UUID v4 primary key
  IntColumn get createdAt => integer()(); // Unix timestamp (seconds)

  // Payload fields
  TextColumn get customerName => text()();
  TextColumn get description => text()();
  RealColumn get amount => real()();
  TextColumn get currency => text().withDefault(const Constant('PKR'))();
  TextColumn get entryType => text()(); // "credit" or "payment"

  // Crypto fields
  TextColumn get merchantPub => text()();
  TextColumn get merchantSig => text()();
  TextColumn get customerSig => text().withDefault(const Constant(''))();
  TextColumn get customerPub => text().withDefault(const Constant(''))();
  TextColumn get entryHash => text()();
  TextColumn get prevHash => text()();
  TextColumn get chainHash => text()();

  // OTS fields
  TextColumn get otsProof => text().withDefault(const Constant(''))();
  IntColumn get otsBitcoinBlock => integer().nullable()();

  // Sort order
  IntColumn get sequenceNum => integer()(); // monotonic sequence for ordering

  @override
  Set<Column> get primaryKey => {id};
}

/// AppMeta table — key/value store for app-level settings.
/// Stores: last_anchored_root, last_anchor_timestamp, merchant_name, etc.
class AppMeta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

// ─────────────────────────────────────────────────────────────
// DATABASE CLASS
// ─────────────────────────────────────────────────────────────

@DriftDatabase(tables: [LedgerEntries, AppMeta])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // Seed default meta values
          await into(appMeta).insertOnConflictUpdate(
            AppMetaCompanion.insert(key: 'merchant_name', value: 'My Shop'),
          );
          await into(appMeta).insertOnConflictUpdate(
            AppMetaCompanion.insert(key: 'last_anchored_root', value: ''),
          );
          await into(appMeta).insertOnConflictUpdate(
            AppMetaCompanion.insert(
                key: 'last_anchor_timestamp', value: '0'),
          );
        },
      );
}

/// Opens the SQLite connection using drift_flutter (cross-platform).
QueryExecutor _openConnection() {
  return driftDatabase(name: 'ledgerlite_pro');
}