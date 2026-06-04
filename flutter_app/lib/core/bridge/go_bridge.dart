import 'dart:ffi';
import 'dart:io';
import 'dart:convert';

// ─────────────────────────────────────────────────────────────
// GoBridge — Dart interface to the Go crypto engine (mobile)
//
// On Android: loads GoEngine.aar (compiled via gomobile bind)
// On iOS:     loads GoEngine.xcframework (compiled via gomobile bind)
//
// BUILD INSTRUCTIONS (run from go_engine/ directory):
//
//   Android:
//     gomobile bind -target=android -o ../flutter_app/android/libs/GoEngine.aar \
//       github.com/MuaazTasawar/ledgerlite_pro/go_engine/mobile
//
//   iOS:
//     gomobile bind -target=ios -o ../flutter_app/ios/GoEngine.xcframework \
//       github.com/MuaazTasawar/ledgerlite_pro/go_engine/mobile
//
// After building, add GoEngine.aar to android/app/build.gradle:
//   implementation fileTree(dir: 'libs', include: ['*.aar'])
//
// NOTE: Until gomobile is built, this bridge uses a pure-Dart
// software fallback so the app compiles and runs during development.
// The fallback is clearly marked and must be replaced before production.
// ─────────────────────────────────────────────────────────────

/// Result of a chain verification — mirrors crypto.VerificationResult in Go.
class VerificationResult {
  final bool valid;
  final int failedAtIndex;
  final String failedEntryId;
  final String reason;
  final int entriesChecked;
  final String merkleRoot;
  final int durationMs;

  const VerificationResult({
    required this.valid,
    required this.failedAtIndex,
    required this.failedEntryId,
    required this.reason,
    required this.entriesChecked,
    required this.merkleRoot,
    required this.durationMs,
  });

  factory VerificationResult.fromJson(Map<String, dynamic> json) {
    return VerificationResult(
      valid: json['Valid'] as bool? ?? false,
      failedAtIndex: json['FailedAtIndex'] as int? ?? -1,
      failedEntryId: json['FailedEntryID'] as String? ?? '',
      reason: json['Reason'] as String? ?? '',
      entriesChecked: json['EntriesChecked'] as int? ?? 0,
      merkleRoot: json['MerkleRoot'] as String? ?? '',
      durationMs: json['DurationMs'] as int? ?? 0,
    );
  }
}

/// GoBridge is a singleton that wraps all calls to the Go crypto engine.
/// On mobile it calls the gomobile-generated bindings.
/// During development (before gomobile build), it uses a Dart fallback.
class GoBridge {
  GoBridge._();
  static final GoBridge instance = GoBridge._();

  /// Whether the native Go library is loaded.
  /// Set to true after successful gomobile library initialization.
  bool _nativeLoaded = false;

  /// Attempt to load the native Go library.
  /// Call this from main.dart after WidgetsFlutterBinding.ensureInitialized().
  Future<void> init() async {
    try {
      // TODO: Replace with actual gomobile-generated method channel init
      // when GoEngine.aar / GoEngine.xcframework is built.
      // Example for method channel approach:
      //   await GoEnginePlugin.initialize();
      //   _nativeLoaded = true;
      //
      // For now we run in fallback mode during development.
      _nativeLoaded = false;
    } catch (e) {
      _nativeLoaded = false;
    }
  }

  // ─────────────────────────────────────────────────────────
  // Key Management
  // ─────────────────────────────────────────────────────────

  /// Generates a new Ed25519 key pair.
  /// Returns {"public_key": "...", "private_key": "..."}
  Future<Map<String, String>> generateKeyPair() async {
    if (_nativeLoaded) {
      // TODO: return await GoMobile.generateKeyPair();
    }
    return _fallbackGenerateKeyPair();
  }

  /// Derives public key from private key hex.
  Future<String> publicKeyFromPrivate(String privateKeyHex) async {
    if (_nativeLoaded) {
      // TODO: return await GoMobile.publicKeyFromPrivate(privateKeyHex);
    }
    return _fallbackPublicKeyFromPrivate(privateKeyHex);
  }

  // ─────────────────────────────────────────────────────────
  // Entry Signing
  // ─────────────────────────────────────────────────────────

  /// Merchant-signs a new entry payload.
  /// [entryPayloadJson] — JSON of the entry payload (no timestamp/pub key needed)
  /// [privateKeyHex]   — merchant's private key
  /// [prevChainHash]   — "GENESIS" or last entry's chain_hash
  /// Returns JSON of the full SignedEntry.
  Future<String> merchantSignEntry({
    required String entryPayloadJson,
    required String privateKeyHex,
    required String prevChainHash,
  }) async {
    if (_nativeLoaded) {
      // TODO: return await GoMobile.merchantSignEntry(
      //   entryPayloadJson, privateKeyHex, prevChainHash);
    }
    return _fallbackMerchantSign(entryPayloadJson, privateKeyHex, prevChainHash);
  }

  /// Customer-signs an existing SignedEntry JSON.
  /// Returns updated SignedEntry JSON with customer_sig filled.
  Future<String> customerSignEntry({
    required String signedEntryJson,
    required String customerPrivateKeyHex,
  }) async {
    if (_nativeLoaded) {
      // TODO: return await GoMobile.customerSignEntry(
      //   signedEntryJson, customerPrivateKeyHex);
    }
    return _fallbackCustomerSign(signedEntryJson, customerPrivateKeyHex);
  }

  // ─────────────────────────────────────────────────────────
  // Chain Verification
  // ─────────────────────────────────────────────────────────

  /// Verifies the full chain from a JSON array of SignedEntries.
  /// Returns a [VerificationResult].
  Future<VerificationResult> verifyChain(String entriesJson) async {
    if (_nativeLoaded) {
      // TODO: final resultJson = await GoMobile.verifyChain(entriesJson);
      // return VerificationResult.fromJson(jsonDecode(resultJson));
    }
    return _fallbackVerifyChain(entriesJson);
  }

  /// Verifies a single SignedEntry JSON.
  /// Returns "ok" or throws with reason.
  Future<String> verifySingleEntry(String signedEntryJson) async {
    if (_nativeLoaded) {
      // TODO: return await GoMobile.verifySingleEntry(signedEntryJson);
    }
    return _fallbackVerifySingle(signedEntryJson);
  }

  // ─────────────────────────────────────────────────────────
  // Merkle Utilities
  // ─────────────────────────────────────────────────────────

  /// Returns the Merkle root hash of all entries.
  /// This value is what gets anchored to OpenTimestamps.
  Future<String> computeMerkleRoot(String entriesJson) async {
    if (_nativeLoaded) {
      // TODO: return await GoMobile.computeMerkleRoot(entriesJson);
    }
    return _fallbackMerkleRoot(entriesJson);
  }

  /// Returns the chain_hash of the last entry, or "GENESIS" if empty.
  Future<String> getHeadHash(String entriesJson) async {
    if (_nativeLoaded) {
      // TODO: return await GoMobile.getHeadHash(entriesJson);
    }
    return _fallbackHeadHash(entriesJson);
  }

  /// Hashes a payload JSON — used for the live hash badge while typing.
  Future<String> hashEntryPayload(String payloadJson) async {
    if (_nativeLoaded) {
      // TODO: return await GoMobile.hashEntryPayload(payloadJson);
    }
    return _fallbackHashPayload(payloadJson);
  }

  // ─────────────────────────────────────────────────────────
  // DART FALLBACKS
  // Pure-Dart implementations used during development before
  // gomobile build. NOT cryptographically secure — for UI dev only.
  // ─────────────────────────────────────────────────────────

  Map<String, String> _fallbackGenerateKeyPair() {
    // Simulate key pair with random hex strings
    final pub = _fakeHex(32);
    final priv = _fakeHex(64);
    return {'public_key': pub, 'private_key': priv};
  }

  String _fallbackPublicKeyFromPrivate(String privateKeyHex) {
    // Derive "public" key as last 64 chars of private (simulated)
    if (privateKeyHex.length >= 64) {
      return privateKeyHex.substring(privateKeyHex.length - 64);
    }
    return _fakeHex(32);
  }

  String _fallbackMerchantSign(
      String payloadJson, String privateKeyHex, String prevChainHash) {
    final payload = jsonDecode(payloadJson) as Map<String, dynamic>;
    payload['timestamp'] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    payload['merchant_pub'] = _fallbackPublicKeyFromPrivate(privateKeyHex);

    final entryHash = _fakeHashOf(jsonEncode(payload));
    final chainHash = _fakeHashOf(entryHash + prevChainHash);

    return jsonEncode({
      'payload': payload,
      'merchant_sig': _fakeHex(64),
      'customer_sig': '',
      'entry_hash': entryHash,
      'prev_hash': prevChainHash,
      'chain_hash': chainHash,
    });
  }

  String _fallbackCustomerSign(String signedEntryJson, String customerPrivKey) {
    final entry = jsonDecode(signedEntryJson) as Map<String, dynamic>;
    entry['customer_sig'] = _fakeHex(64);
    return jsonEncode(entry);
  }

  VerificationResult _fallbackVerifyChain(String entriesJson) {
    final entries = jsonDecode(entriesJson) as List<dynamic>;
    final start = DateTime.now();

    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i] as Map<String, dynamic>;
      final prevHash = i == 0 ? 'GENESIS' : (entries[i - 1] as Map)['chain_hash'];
      if (entry['prev_hash'] != prevHash) {
        return VerificationResult(
          valid: false,
          failedAtIndex: i,
          failedEntryId: entry['payload']?['id'] ?? '',
          reason: 'Chain broken at entry $i',
          entriesChecked: i + 1,
          merkleRoot: '',
          durationMs: DateTime.now().difference(start).inMilliseconds,
        );
      }
    }

    final root = entries.isEmpty ? '' : _fakeHashOf(
        (entries.map((e) => (e as Map)['chain_hash'] as String)).join());

    return VerificationResult(
      valid: true,
      failedAtIndex: -1,
      failedEntryId: '',
      reason: '',
      entriesChecked: entries.length,
      merkleRoot: root,
      durationMs: DateTime.now().difference(start).inMilliseconds,
    );
  }

  String _fallbackVerifySingle(String signedEntryJson) {
    // In fallback mode, always return ok
    return 'ok';
  }

  String _fallbackMerkleRoot(String entriesJson) {
    final entries = jsonDecode(entriesJson) as List<dynamic>;
    if (entries.isEmpty) return '';
    final hashes = entries.map((e) => (e as Map)['chain_hash'] as String).join();
    return _fakeHashOf(hashes);
  }

  String _fallbackHeadHash(String entriesJson) {
    final entries = jsonDecode(entriesJson) as List<dynamic>;
    if (entries.isEmpty) return 'GENESIS';
    return (entries.last as Map<String, dynamic>)['chain_hash'] as String;
  }

  String _fallbackHashPayload(String payloadJson) {
    return _fakeHashOf(payloadJson);
  }

  // ─────────────────────────────────────────────────────────
  // Internal helpers for fallback simulation
  // ─────────────────────────────────────────────────────────

  static const _hexChars = '0123456789abcdef';

  String _fakeHex(int bytes) {
    final buf = StringBuffer();
    final r = DateTime.now().microsecondsSinceEpoch;
    for (int i = 0; i < bytes * 2; i++) {
      buf.write(_hexChars[(r + i * 7) % 16]);
    }
    return buf.toString();
  }

  String _fakeHashOf(String input) {
    // Deterministic fake hash — same input gives same output in fallback
    int h = 0x811c9dc5;
    for (final c in input.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h.toRadixString(16).padLeft(8, '0') * 8; // 64 hex chars
  }
}