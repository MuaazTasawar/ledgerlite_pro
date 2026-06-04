import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../bridge/go_bridge.dart';

/// KeyService manages the merchant's Ed25519 key pair.
///
/// The private key is stored in flutter_secure_storage — it never leaves
/// the device and is never logged or transmitted. The public key is derived
/// from the private key on demand and is safe to share freely.
///
/// On first launch, a new key pair is generated via the Go bridge.
/// On subsequent launches, the stored private key is loaded.
class KeyService {
  static const _privateKeyStorageKey = 'merchant_private_key';
  static const _publicKeyStorageKey = 'merchant_public_key';
  static const _merchantNameKey = 'merchant_name';

  final FlutterSecureStorage _storage;
  final GoBridge _bridge;

  String _privateKey = '';
  String _publicKey = '';
  String _merchantName = 'My Shop';

  KeyService({
    FlutterSecureStorage? storage,
    GoBridge? bridge,
  })  : _storage = storage ?? const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock_this_device,
          ),
        ),
        _bridge = bridge ?? GoBridge.instance;

  // ─────────────────────────────────────────────────────────
  // Public getters
  // ─────────────────────────────────────────────────────────

  /// The merchant's Ed25519 public key (hex). Safe to share.
  String get publicKey => _publicKey;

  /// The merchant's Ed25519 private key (hex). Never expose in UI.
  String get privateKey => _privateKey;

  /// The merchant's display name (shown in the app and on receipts).
  String get merchantName => _merchantName;

  /// True if keys have been loaded and the service is ready.
  bool get isReady => _privateKey.isNotEmpty && _publicKey.isNotEmpty;

  // ─────────────────────────────────────────────────────────
  // Initialization
  // ─────────────────────────────────────────────────────────

  /// Initializes the key service.
  /// - If keys exist in secure storage: loads them.
  /// - If not: generates a new key pair and stores it.
  /// Must be called before any other method.
  Future<void> init() async {
    await _bridge.init();

    final storedPriv = await _storage.read(key: _privateKeyStorageKey);
    final storedPub = await _storage.read(key: _publicKeyStorageKey);
    final storedName = await _storage.read(key: _merchantNameKey);

    if (storedName != null && storedName.isNotEmpty) {
      _merchantName = storedName;
    }

    if (storedPriv != null &&
        storedPriv.isNotEmpty &&
        storedPub != null &&
        storedPub.isNotEmpty) {
      // Keys exist — load them
      _privateKey = storedPriv;
      _publicKey = storedPub;
    } else {
      // First launch — generate a new key pair
      await _generateAndStore();
    }
  }

  // ─────────────────────────────────────────────────────────
  // Key Operations
  // ─────────────────────────────────────────────────────────

  /// Regenerates the key pair. Called if the user explicitly resets keys.
  /// WARNING: Regenerating keys invalidates all existing signatures.
  /// The caller must confirm the user understands this before calling.
  Future<void> regenerateKeys() async {
    await _generateAndStore();
  }

  /// Updates the merchant's display name.
  Future<void> setMerchantName(String name) async {
    _merchantName = name;
    await _storage.write(key: _merchantNameKey, value: name);
  }

  /// Returns the short public key for display (first 16 chars + "...").
  String get shortPublicKey {
    if (_publicKey.length < 16) return _publicKey;
    return '${_publicKey.substring(0, 16)}...';
  }

  /// Returns the full public key as a QR-ready string.
  /// Format: "llpro:pubkey:<hex>" — prefixed to distinguish from entry QRs.
  String get publicKeyQrPayload => 'llpro:pubkey:$_publicKey';

  // ─────────────────────────────────────────────────────────
  // Internal
  // ─────────────────────────────────────────────────────────

  Future<void> _generateAndStore() async {
    final kp = await _bridge.generateKeyPair();
    _privateKey = kp['private_key'] ?? '';
    _publicKey = kp['public_key'] ?? '';

    await _storage.write(key: _privateKeyStorageKey, value: _privateKey);
    await _storage.write(key: _publicKeyStorageKey, value: _publicKey);
  }
}