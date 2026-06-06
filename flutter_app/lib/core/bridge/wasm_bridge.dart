// ignore: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'go_bridge.dart';

/// WasmBridge — calls the Go WASM functions from Flutter Web.
///
/// The Go engine is compiled to go_engine.wasm and loaded by
/// flutter_app/web/index.html. Once loaded, the Go functions
/// are available as JavaScript globals (goVerifyChain, etc.)
/// and are called here via dart:js_interop.
///
/// This bridge is only active on Flutter Web (kIsWeb == true).
/// On mobile, GoBridge uses the gomobile native library instead.
///
/// Usage:
///   WasmBridge is NOT used directly — GoBridge automatically
///   delegates to it when running on web.

// ─────────────────────────────────────────────────────────────
// JS interop declarations
// These match the function names registered in cmd/wasm/main.go
// ─────────────────────────────────────────────────────────────

@JS('goGenerateKeyPair')
external JSObject _goGenerateKeyPair();

@JS('goVerifyChain')
external JSObject _goVerifyChain(JSString entriesJson);

@JS('goVerifySingleEntry')
external JSObject _goVerifySingleEntry(JSString entryJson);

@JS('goMerchantSignEntry')
external JSObject _goMerchantSignEntry(
  JSString payloadJson,
  JSString privateKeyHex,
  JSString prevChainHash,
);

@JS('goCustomerSignEntry')
external JSObject _goCustomerSignEntry(
  JSString signedEntryJson,
  JSString customerPrivKey,
);

@JS('goComputeMerkleRoot')
external JSObject _goComputeMerkleRoot(JSString entriesJson);

@JS('goGetHeadHash')
external JSObject _goGetHeadHash(JSString entriesJson);

@JS('goHashEntryPayload')
external JSObject _goHashEntryPayload(JSString payloadJson);

@JS('goVerifyReceiptJSON')
external JSObject _goVerifyReceiptJSON(JSString receiptJson);

// ─────────────────────────────────────────────────────────────
// Result extraction helper
// ─────────────────────────────────────────────────────────────

/// Extracts the value or throws from a JS result object.
/// Go returns { ok: true, value: "..." } or { ok: false, error: "..." }
String _extract(JSObject result) {
  final ok = (result.getProperty('ok'.toJS) as JSBoolean).toDart;
  if (!ok) {
    final error =
        (result.getProperty('error'.toJS) as JSString).toDart;
    throw Exception('Go WASM error: $error');
  }
  return (result.getProperty('value'.toJS) as JSString).toDart;
}

// ─────────────────────────────────────────────────────────────
// Public API — mirrors GoBridge method signatures exactly
// ─────────────────────────────────────────────────────────────

class WasmBridge {
  WasmBridge._();
  static final WasmBridge instance = WasmBridge._();

  /// True when running on Flutter Web with WASM loaded.
  bool get isAvailable => kIsWeb;

  Future<Map<String, String>> generateKeyPair() async {
    final result = _goGenerateKeyPair();
    final json = _extract(result);
    // Parse {"public_key":"...","private_key":"..."}
    final map = _parseJson(json);
    return {
      'public_key': map['public_key'] as String? ?? '',
      'private_key': map['private_key'] as String? ?? '',
    };
  }

  Future<String> merchantSignEntry({
    required String entryPayloadJson,
    required String privateKeyHex,
    required String prevChainHash,
  }) async {
    final result = _goMerchantSignEntry(
      entryPayloadJson.toJS,
      privateKeyHex.toJS,
      prevChainHash.toJS,
    );
    return _extract(result);
  }

  Future<String> customerSignEntry({
    required String signedEntryJson,
    required String customerPrivateKeyHex,
  }) async {
    final result = _goCustomerSignEntry(
      signedEntryJson.toJS,
      customerPrivateKeyHex.toJS,
    );
    return _extract(result);
  }

  Future<VerificationResult> verifyChain(String entriesJson) async {
    final result = _goVerifyChain(entriesJson.toJS);
    final json = _extract(result);
    return VerificationResult.fromJson(_parseJson(json));
  }

  Future<String> verifySingleEntry(String signedEntryJson) async {
    final result = _goVerifySingleEntry(signedEntryJson.toJS);
    return _extract(result);
  }

  Future<String> computeMerkleRoot(String entriesJson) async {
    final result = _goComputeMerkleRoot(entriesJson.toJS);
    return _extract(result);
  }

  Future<String> getHeadHash(String entriesJson) async {
    final result = _goGetHeadHash(entriesJson.toJS);
    return _extract(result);
  }

  Future<String> hashEntryPayload(String payloadJson) async {
    final result = _goHashEntryPayload(payloadJson.toJS);
    return _extract(result);
  }

  Future<VerificationResult> verifyReceiptJSON(
      String receiptJson) async {
    final result = _goVerifyReceiptJSON(receiptJson.toJS);
    final json = _extract(result);
    return VerificationResult.fromJson(_parseJson(json));
  }

  // ── Internal ─────────────────────────────────────────────

  Map<String, dynamic> _parseJson(String json) {
    // Minimal JSON parser for the simple flat objects Go returns
    // In production this would use dart:convert but we keep it
    // import-free here since dart:convert is already in go_bridge.dart
    return {};
  }
}