import 'package:drift/drift.dart';
import 'database.dart';
import '../models/entry.dart';

part 'ledger_dao.g.dart';

@DriftAccessor(tables: [LedgerEntries, AppMeta])
class LedgerDao extends DatabaseAccessor<AppDatabase> with _$LedgerDaoMixin {
  LedgerDao(super.db);

  // ─────────────────────────────────────────────────────────
  // INSERT
  // ─────────────────────────────────────────────────────────

  /// Inserts a new signed entry into the ledger.
  /// Computes sequenceNum automatically from current count.
  Future<void> insertEntry(SignedEntryModel entry) async {
    final count = await entryCount();
    await into(ledgerEntries).insert(
      LedgerEntriesCompanion.insert(
        id: entry.id,
        createdAt: entry.timestamp,
        customerName: entry.customerName,
        description: entry.description,
        amount: entry.amount,
        currency: Value(entry.currency),
        entryType: entry.type.value,
        merchantPub: entry.merchantPub,
        merchantSig: entry.merchantSig,
        customerSig: Value(entry.customerSig),
        customerPub: Value(entry.customerPub),
        entryHash: entry.entryHash,
        prevHash: entry.prevHash,
        chainHash: entry.chainHash,
        otsProof: Value(entry.otsProof),
        otsBitcoinBlock: entry.otsBitcoinBlock != null
            ? Value(entry.otsBitcoinBlock!)
            : const Value.absent(),
        sequenceNum: count + 1,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // READ
  // ─────────────────────────────────────────────────────────

  /// Returns all entries ordered by sequenceNum ascending.
  Future<List<SignedEntryModel>> allEntries() async {
    final rows = await (select(ledgerEntries)
          ..orderBy([(t) => OrderingTerm.asc(t.sequenceNum)]))
        .get();
    return rows.map(_rowToModel).toList();
  }

  /// Watches all entries as a stream — UI rebuilds on any change.
  Stream<List<SignedEntryModel>> watchAllEntries() {
    return (select(ledgerEntries)
          ..orderBy([(t) => OrderingTerm.asc(t.sequenceNum)]))
        .watch()
        .map((rows) => rows.map(_rowToModel).toList());
  }

  /// Returns all entries for a specific customer (by name).
  Future<List<SignedEntryModel>> entriesForCustomer(String customerName) async {
    final rows = await (select(ledgerEntries)
          ..where((t) => t.customerName.equals(customerName))
          ..orderBy([(t) => OrderingTerm.asc(t.sequenceNum)]))
        .get();
    return rows.map(_rowToModel).toList();
  }

  /// Returns the last entry in the chain (highest sequenceNum).
  Future<SignedEntryModel?> lastEntry() async {
    final rows = await (select(ledgerEntries)
          ..orderBy([(t) => OrderingTerm.desc(t.sequenceNum)])
          ..limit(1))
        .get();
    if (rows.isEmpty) return null;
    return _rowToModel(rows.first);
  }

  /// Returns total count of entries.
  Future<int> entryCount() async {
    final count = ledgerEntries.id.count();
    final query = selectOnly(ledgerEntries)..addColumns([count]);
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  /// Returns distinct customer names for the customer list screen.
  Future<List<String>> customerNames() async {
    final query = selectOnly(ledgerEntries, distinct: true)
      ..addColumns([ledgerEntries.customerName])
      ..orderBy([OrderingTerm.asc(ledgerEntries.customerName)]);
    final rows = await query.get();
    return rows
        .map((r) => r.read(ledgerEntries.customerName) ?? '')
        .where((n) => n.isNotEmpty)
        .toList();
  }

  // ─────────────────────────────────────────────────────────
  // UPDATE
  // ─────────────────────────────────────────────────────────

  /// Updates the customer signature and public key on an existing entry.
  /// Called after the customer completes the QR signing handshake.
  Future<void> updateCustomerSig({
    required String entryId,
    required String customerSig,
    required String customerPub,
  }) async {
    await (update(ledgerEntries)..where((t) => t.id.equals(entryId))).write(
      LedgerEntriesCompanion(
        customerSig: Value(customerSig),
        customerPub: Value(customerPub),
      ),
    );
  }

  /// Updates the OTS proof and Bitcoin block number after anchoring.
  Future<void> updateOtsProof({
    required String entryId,
    required String otsProof,
    int? bitcoinBlock,
  }) async {
    await (update(ledgerEntries)..where((t) => t.id.equals(entryId))).write(
      LedgerEntriesCompanion(
        otsProof: Value(otsProof),
        otsBitcoinBlock:
            bitcoinBlock != null ? Value(bitcoinBlock) : const Value.absent(),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // APP META
  // ─────────────────────────────────────────────────────────

  /// Reads a meta value by key. Returns null if not found.
  Future<String?> getMeta(String key) async {
    final row = await (select(appMeta)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  /// Writes a meta value by key (upsert).
  Future<void> setMeta(String key, String value) async {
    await into(appMeta).insertOnConflictUpdate(
      AppMetaCompanion.insert(key: key, value: value),
    );
  }

  // ─────────────────────────────────────────────────────────
  // INTERNAL
  // ─────────────────────────────────────────────────────────

  SignedEntryModel _rowToModel(LedgerEntry row) {
    return SignedEntryModel(
      id: row.id,
      customerName: row.customerName,
      description: row.description,
      amount: row.amount,
      currency: row.currency,
      type: EntryTypeX.fromString(row.entryType),
      timestamp: row.createdAt,
      merchantPub: row.merchantPub,
      merchantSig: row.merchantSig,
      customerSig: row.customerSig,
      customerPub: row.customerPub,
      entryHash: row.entryHash,
      prevHash: row.prevHash,
      chainHash: row.chainHash,
      otsProof: row.otsProof,
      otsBitcoinBlock: row.otsBitcoinBlock,
    );
  }
}

// Drift requires this part file for the DAO mixin.
// Run: flutter pub run build_runner build --delete-conflicting-outputs
// to generate ledger_dao.g.dart with _$LedgerDaoMixin.
// Until then, define the mixin manually as a no-op so the project compiles.
