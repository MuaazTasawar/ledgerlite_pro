import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../bridge/go_bridge.dart';
import '../db/database.dart';
import '../db/ledger_dao.dart';
import '../models/entry.dart';
import '../models/ledger.dart';
import 'key_service.dart';

/// LedgerService is the single source of truth for all ledger operations.
///
/// It coordinates between:
///   - GoBridge (crypto: sign, verify, hash, Merkle)
///   - LedgerDao (SQLite persistence)
///   - KeyService (merchant's private key)
///
/// All UI interactions go through this service — never directly to the DAO.
class LedgerService {
  final AppDatabase _db;
  final KeyService _keyService;
  final GoBridge _bridge;
  final _uuid = const Uuid();
  late final LedgerDao _dao = LedgerDao(_db);

  LedgerService({
    required AppDatabase db,
    required KeyService keyService,
    GoBridge? bridge,
  })  : _db = db,
        _keyService = keyService,
        _bridge = bridge ?? GoBridge.instance;

  // ─────────────────────────────────────────────────────────
  // READ
  // ─────────────────────────────────────────────────────────

  /// Returns all entries ordered by sequence number (oldest first).
  Future<List<SignedEntryModel>> allEntries() => _dao.allEntries();

  /// Watches all entries as a live stream for UI rebuilds.
  Stream<List<SignedEntryModel>> watchAllEntries() => _dao.watchAllEntries();

  /// Returns all entries for a specific customer.
  Future<List<SignedEntryModel>> entriesForCustomer(String name) =>
      _dao.entriesForCustomer(name);

  /// Returns all distinct customer names.
  Future<List<String>> customerNames() => _dao.customerNames();

  /// Returns the LedgerSummary for the home screen.
  Future<LedgerSummary> summary() async {
    final entries = await allEntries();
    final root = entries.isEmpty
        ? ''
        : await _bridge.computeMerkleRoot(_entriesToJson(entries));
    final lastAnchorRoot =
        await _dao.getMeta('last_anchored_root') ?? '';
    return LedgerSummary.fromEntries(
      entries,
      merkleRoot: root,
      isAnchored: root.isNotEmpty && root == lastAnchorRoot,
    );
  }

  /// Returns a CustomerLedger for a single customer.
  Future<CustomerLedger> customerLedger(String customerName) async {
    final entries = await entriesForCustomer(customerName);
    final customerPub = entries
        .where((e) => e.customerPub.isNotEmpty)
        .map((e) => e.customerPub)
        .firstOrNull ?? '';
    return CustomerLedger(
      customerName: customerName,
      customerPub: customerPub,
      entries: entries,
    );
  }

  // ─────────────────────────────────────────────────────────
  // WRITE — Add Entry
  // ─────────────────────────────────────────────────────────

  /// Creates a new merchant-signed ledger entry.
  ///
  /// Steps:
  ///   1. Build the payload JSON
  ///   2. Get the current head hash (prevHash for new entry)
  ///   3. Call Go bridge to sign the entry
  ///   4. Persist to SQLite
  ///   5. Return the signed entry (for QR handshake or immediate save)
  Future<SignedEntryModel> addEntry({
    required String customerName,
    required String description,
    required double amount,
    required EntryType type,
    String currency = 'PKR',
  }) async {
    if (!_keyService.isReady) {
      throw StateError('ledger: KeyService not initialized');
    }

    // Step 1 — Build payload (no timestamp/merchantPub — Go fills those)
    final payloadJson = jsonEncode({
      'id': _uuid.v4(),
      'customer_name': customerName,
      'description': description,
      'amount': amount,
      'currency': currency,
      'type': type.value,
      'timestamp': 0,
      'merchant_pub': '',
    });

    // Step 2 — Get prevHash
    final entries = await allEntries();
    final prevHash = entries.isEmpty
        ? 'GENESIS'
        : await _bridge.getHeadHash(_entriesToJson(entries));

    // Step 3 — Merchant signs via Go bridge
    final signedJson = await _bridge.merchantSignEntry(
      entryPayloadJson: payloadJson,
      privateKeyHex: _keyService.privateKey,
      prevChainHash: prevHash,
    );

    // Step 4 — Parse and persist
    final signedMap = jsonDecode(signedJson) as Map<String, dynamic>;
    final entry = SignedEntryModel.fromBridgeJson(signedMap);
    await _dao.insertEntry(entry);

    return entry;
  }

  // ─────────────────────────────────────────────────────────
  // WRITE — Customer Signature (QR Handshake)
  // ─────────────────────────────────────────────────────────

  /// Applies the customer's signature to an existing entry.
  ///
  /// Called after the QR handshake completes on the customer's device.
  /// [entryId]        — the entry to update
  /// [customerSig]    — hex Ed25519 signature from customer
  /// [customerPubKey] — customer's Ed25519 public key (hex)
  Future<void> applyCustomerSignature({
    required String entryId,
    required String customerSig,
    required String customerPubKey,
  }) async {
    await _dao.updateCustomerSig(
      entryId: entryId,
      customerSig: customerSig,
      customerPub: customerPubKey,
    );
  }

  /// Signs an entry as the customer (called on the customer's phone).
  ///
  /// The customer scans the merchant's QR, which contains the SignedEntry JSON.
  /// This method adds the customer's signature and returns the updated JSON
  /// to be displayed as a QR for the merchant to scan back.
  Future<String> signAsCustomer({
    required String signedEntryJson,
    required String customerPrivateKeyHex,
  }) async {
    return _bridge.customerSignEntry(
      signedEntryJson: signedEntryJson,
      customerPrivateKeyHex: customerPrivateKeyHex,
    );
  }

  // ─────────────────────────────────────────────────────────
  // VERIFY
  // ─────────────────────────────────────────────────────────

  /// Verifies the full chain integrity.
  /// Returns a VerificationResult with detailed pass/fail info.
  Future<VerificationResult> verifyFullChain() async {
    final entries = await allEntries();
    if (entries.isEmpty) {
      return const VerificationResult(
        valid: true,
        failedAtIndex: -1,
        failedEntryId: '',
        reason: 'Chain is empty',
        entriesChecked: 0,
        merkleRoot: '',
        durationMs: 0,
      );
    }
    return _bridge.verifyChain(_entriesToJson(entries));
  }

  /// Hashes a payload in real time — for the live hash badge while typing.
  Future<String> hashPayload({
    required String customerName,
    required String description,
    required double amount,
    required EntryType type,
    String currency = 'PKR',
  }) async {
    final payloadJson = jsonEncode({
      'id': 'preview',
      'customer_name': customerName,
      'description': description,
      'amount': amount,
      'currency': currency,
      'type': type.value,
      'timestamp': 0,
      'merchant_pub': _keyService.publicKey,
    });
    return _bridge.hashEntryPayload(payloadJson);
  }

  // ─────────────────────────────────────────────────────────
  // OTS
  // ─────────────────────────────────────────────────────────

  /// Updates the OTS proof on an entry after anchoring.
  Future<void> saveOtsProof({
    required String entryId,
    required String otsProof,
    int? bitcoinBlock,
  }) async {
    await _dao.updateOtsProof(
      entryId: entryId,
      otsProof: otsProof,
      bitcoinBlock: bitcoinBlock,
    );
  }

  /// Saves the last anchored Merkle root to app meta.
  Future<void> saveAnchoredRoot(String root) async {
    await _dao.setMeta('last_anchored_root', root);
    await _dao.setMeta(
      'last_anchor_timestamp',
      DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  // ─────────────────────────────────────────────────────────
  // EXPORT
  // ─────────────────────────────────────────────────────────

  /// Builds the receipt export payload for a single entry.
  /// This JSON is what gets embedded in the receipt QR and PDF.
  Map<String, dynamic> buildReceiptPayload(SignedEntryModel entry) {
    return {
      'app': 'LedgerLite Pro',
      'version': '1.0.0',
      'entry': jsonDecode(entry.toSignedEntryJson()),
      'customer_pub': entry.customerPub,
      'ots_proof': entry.otsProof,
      'ots_bitcoin_block': entry.otsBitcoinBlock,
      'merchant_name': _keyService.merchantName,
      'exported_at': DateTime.now().toIso8601String(),
    };
  }

  /// Builds a full chain export payload (for full ledger backup/verification).
  Future<Map<String, dynamic>> buildChainExport() async {
    final entries = await allEntries();
    final root = entries.isEmpty
        ? ''
        : await _bridge.computeMerkleRoot(_entriesToJson(entries));
    return {
      'app': 'LedgerLite Pro',
      'version': '1.0.0',
      'merchant_pub': _keyService.publicKey,
      'merchant_name': _keyService.merchantName,
      'merkle_root': root,
      'entry_count': entries.length,
      'entries':
          entries.map((e) => jsonDecode(e.toSignedEntryJson())).toList(),
      'exported_at': DateTime.now().toIso8601String(),
    };
  }

  // ─────────────────────────────────────────────────────────
  // Internal helpers
  // ─────────────────────────────────────────────────────────

  String _entriesToJson(List<SignedEntryModel> entries) {
    return jsonEncode(
        entries.map((e) => jsonDecode(e.toSignedEntryJson())).toList());
  }
}