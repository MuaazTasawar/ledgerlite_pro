import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// OtsService handles communication with the OpenTimestamps public API.
///
/// OpenTimestamps anchors a SHA-256 hash to the Bitcoin blockchain —
/// creating an immutable, publicly verifiable timestamp that proves
/// the hash existed at a specific point in time.
///
/// API: https://aia.opentimestamps.org/timestamp (free, no account needed)
/// Docs: https://opentimestamps.org
///
/// Flow:
///   1. Compute Merkle root of the full chain (via LedgerService)
///   2. POST the root hash bytes to the OTS API → get a pending proof
///   3. Store the pending proof locally
///   4. Later, upgrade the proof (call upgrade endpoint) → get Bitcoin block
///   5. Store the final proof + block number
///
/// Note: Bitcoin confirmation takes ~1–2 hours (one block).
/// For demos, pre-anchor a test hash a day before to show a confirmed proof.
class OtsService {
  static const _stampUrl = 'https://aia.opentimestamps.org/timestamp';
  static const _upgradeUrl = 'https://aia.opentimestamps.org/timestamp/upgrade';

  final http.Client _client;

  OtsService({http.Client? client}) : _client = client ?? http.Client();

  // ─────────────────────────────────────────────────────────
  // Stamp (anchor a hash)
  // ─────────────────────────────────────────────────────────

  /// Submits a Merkle root hash to OpenTimestamps for anchoring.
  ///
  /// [merkleRootHex] — 64-char hex string (SHA-256 Merkle root)
  ///
  /// Returns an [OtsStampResult] with the pending proof bytes (base64).
  /// The proof is "pending" until Bitcoin confirms the block (~1 hour).
  Future<OtsStampResult> stampHash(String merkleRootHex) async {
    if (merkleRootHex.isEmpty || merkleRootHex.length != 64) {
      return OtsStampResult.error('Invalid Merkle root hash length');
    }

    try {
      // Convert hex to raw bytes — OTS API expects raw SHA-256 bytes
      final hashBytes = _hexToBytes(merkleRootHex);

      final response = await _client
          .post(
            Uri.parse(_stampUrl),
            headers: {'Content-Type': 'application/octet-stream'},
            body: hashBytes,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        // Response body is the .ots proof file bytes
        final proofBase64 = base64Encode(response.bodyBytes);
        return OtsStampResult.success(
          proofBase64: proofBase64,
          merkleRoot: merkleRootHex,
          isPending: true,
        );
      } else {
        return OtsStampResult.error(
          'OTS API returned ${response.statusCode}: ${response.body}',
        );
      }
    } on Exception catch (e) {
      return OtsStampResult.error('OTS stamp failed: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  // Upgrade (check if Bitcoin confirmed)
  // ─────────────────────────────────────────────────────────

  /// Attempts to upgrade a pending OTS proof to a confirmed Bitcoin proof.
  ///
  /// [proofBase64] — the pending proof bytes (base64) from [stampHash]
  ///
  /// Returns an [OtsUpgradeResult]:
  ///   - If Bitcoin has confirmed: includes the Bitcoin block number
  ///   - If still pending: returns isPending = true
  ///   - On error: returns the error message
  Future<OtsUpgradeResult> upgradeProof(String proofBase64) async {
    if (proofBase64.isEmpty) {
      return OtsUpgradeResult.error('No proof to upgrade');
    }

    try {
      final proofBytes = base64Decode(proofBase64);

      final response = await _client
          .post(
            Uri.parse(_upgradeUrl),
            headers: {'Content-Type': 'application/octet-stream'},
            body: proofBytes,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        // Upgraded proof returned — parse Bitcoin block from proof
        final upgradedBase64 = base64Encode(response.bodyBytes);
        final blockNumber = _extractBitcoinBlock(response.bodyBytes);
        return OtsUpgradeResult.success(
          upgradedProofBase64: upgradedBase64,
          bitcoinBlock: blockNumber,
          isPending: blockNumber == null,
        );
      } else if (response.statusCode == 304) {
        // 304 Not Modified — proof is still pending, no new data
        return OtsUpgradeResult.pending();
      } else {
        return OtsUpgradeResult.error(
          'OTS upgrade returned ${response.statusCode}',
        );
      }
    } on Exception catch (e) {
      return OtsUpgradeResult.error('OTS upgrade failed: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  // Verification helper
  // ─────────────────────────────────────────────────────────

  /// Returns a human-readable anchor status string for display in the UI.
  String anchorStatusLabel({
    required String otsProof,
    required int? bitcoinBlock,
  }) {
    if (otsProof.isEmpty) return 'Not anchored';
    if (bitcoinBlock != null) {
      return 'Anchored · Bitcoin block #$bitcoinBlock';
    }
    return 'Pending confirmation (~1 hr)';
  }

  // ─────────────────────────────────────────────────────────
  // Internal helpers
  // ─────────────────────────────────────────────────────────

  Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < hex.length; i += 2) {
      result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return result;
  }

  /// Attempts to extract the Bitcoin block number from OTS proof bytes.
  /// OTS proofs encode the block height as a little-endian varint.
  /// This is a best-effort extraction — returns null if not found.
  int? _extractBitcoinBlock(Uint8List proofBytes) {
    try {
      // OTS Bitcoin attestation tag: 0x0588960d73d71916
      // Followed by block height as little-endian varint
      // We scan for the attestation tag and read the varint after it
      const tag = [0x05, 0x88, 0x96, 0x0d, 0x73, 0xd7, 0x19, 0x16];
      for (int i = 0; i < proofBytes.length - tag.length - 8; i++) {
        bool found = true;
        for (int j = 0; j < tag.length; j++) {
          if (proofBytes[i + j] != tag[j]) {
            found = false;
            break;
          }
        }
        if (found) {
          // Skip 8-byte length prefix after tag, then read varint
          int offset = i + tag.length + 8;
          return _readVarint(proofBytes, offset);
        }
      }
    } catch (_) {
      // Extraction failed — proof may be in a format we don't recognize
    }
    return null;
  }

  int? _readVarint(Uint8List bytes, int offset) {
    if (offset >= bytes.length) return null;
    int result = 0;
    int shift = 0;
    while (offset < bytes.length) {
      final byte = bytes[offset++];
      result |= (byte & 0x7F) << shift;
      if ((byte & 0x80) == 0) return result;
      shift += 7;
      if (shift >= 32) return null; // overflow guard
    }
    return null;
  }
}

// ─────────────────────────────────────────────────────────────
// Result types
// ─────────────────────────────────────────────────────────────

class OtsStampResult {
  final bool success;
  final String? proofBase64;
  final String? merkleRoot;
  final bool isPending;
  final String? errorMessage;

  const OtsStampResult._({
    required this.success,
    this.proofBase64,
    this.merkleRoot,
    this.isPending = false,
    this.errorMessage,
  });

  factory OtsStampResult.success({
    required String proofBase64,
    required String merkleRoot,
    bool isPending = true,
  }) =>
      OtsStampResult._(
        success: true,
        proofBase64: proofBase64,
        merkleRoot: merkleRoot,
        isPending: isPending,
      );

  factory OtsStampResult.error(String message) =>
      OtsStampResult._(success: false, errorMessage: message);
}

class OtsUpgradeResult {
  final bool success;
  final String? upgradedProofBase64;
  final int? bitcoinBlock;
  final bool isPending;
  final String? errorMessage;

  const OtsUpgradeResult._({
    required this.success,
    this.upgradedProofBase64,
    this.bitcoinBlock,
    this.isPending = false,
    this.errorMessage,
  });

  factory OtsUpgradeResult.success({
    required String upgradedProofBase64,
    int? bitcoinBlock,
    bool isPending = false,
  }) =>
      OtsUpgradeResult._(
        success: true,
        upgradedProofBase64: upgradedProofBase64,
        bitcoinBlock: bitcoinBlock,
        isPending: isPending,
      );

  factory OtsUpgradeResult.pending() =>
      const OtsUpgradeResult._(success: true, isPending: true);

  factory OtsUpgradeResult.error(String message) =>
      OtsUpgradeResult._(success: false, errorMessage: message);
}