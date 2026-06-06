import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'go_bridge.dart';

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
// Result extraction — uses dart:js_interop correctly
// Go returns { ok: true, value: "..." } or { ok: false, error: "..." }
// We convert to JSON string first, then parse in Dart
// ─────────────────────────────────────────────────────────────

@JS('JSON.stringify')
external JSString _jsonStringify(JSObject obj);

String _extract(JSObject result) {
  final jsonStr = _jsonStringify(result).toDart;
  final map = jsonDecode(jsonStr) as Map<String, dynamic>;
  final ok = map['ok'] as bool? ?? false;
  if (!ok) {
    final error = map['error'] as String? ?? 'unknown error';
    throw Exception('Go WASM error: $error');
  }
  return map['value'] as String? ?? '';
}

class WasmBridge {
  WasmBridge._();
  static final WasmBridge instance = WasmBridge._();

  bool get isAvailable => kIsWeb;

  Future<Map<String, String>> generateKeyPair() async {
    final result = _goGenerateKeyPair();
    final json = _extract(result);
    final map = jsonDecode(json) as Map<String, dynamic>;
    return {
      'public_key': map['public_key'] as String? ?? '',
      'private_key': map['private_key'] as String? ?? '',
    };
  }

  Future<String> merchantSignEntry(
    {
      required String entryPayloadJson,required String privateKeyHex,required String prevChainHash
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
    return VerificationResult.fromJson(
        jsonDecode(json) as Map<String, dynamic>);
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
    return VerificationResult.fromJson(
        jsonDecode(json) as Map<String, dynamic>);
  }
}