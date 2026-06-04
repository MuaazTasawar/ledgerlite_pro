import 'dart:convert';

/// EntryType — mirrors the "type" field in Go's EntryPayload.
enum EntryType {
  credit, // udhaar — customer owes merchant
  payment, // customer paid back
}

extension EntryTypeX on EntryType {
  String get value => name; // "credit" or "payment"
  static EntryType fromString(String s) =>
      EntryType.values.firstWhere((e) => e.name == s, orElse: () => EntryType.credit);
}

/// SignedEntryModel is the Dart-side representation of a fully signed ledger entry.
/// It mirrors crypto.SignedEntry from Go, with convenience getters added.
class SignedEntryModel {
  // ── Payload fields ──────────────────────────────────────
  final String id;
  final String customerName;
  final String description;
  final double amount;
  final String currency;
  final EntryType type;
  final int timestamp; // Unix seconds
  final String merchantPub; // hex Ed25519 public key

  // ── Crypto fields ────────────────────────────────────────
  final String merchantSig; // hex Ed25519 signature
  final String customerSig; // hex Ed25519 signature (empty if not yet signed)
  final String entryHash; // SHA-256 of canonical payload JSON
  final String prevHash; // chain_hash of previous entry, or "GENESIS"
  final String chainHash; // SHA-256(entryHash + prevHash)

  // ── OTS fields ───────────────────────────────────────────
  final String otsProof; // base64 OTS proof bytes (empty until anchored)
  final int? otsBitcoinBlock; // Bitcoin block number when anchored
  final String customerPub; // customer's public key (stored separately from payload)

  const SignedEntryModel({
    required this.id,
    required this.customerName,
    required this.description,
    required this.amount,
    required this.currency,
    required this.type,
    required this.timestamp,
    required this.merchantPub,
    required this.merchantSig,
    required this.customerSig,
    required this.entryHash,
    required this.prevHash,
    required this.chainHash,
    required this.otsProof,
    this.otsBitcoinBlock,
    required this.customerPub,
  });

  // ── Convenience getters ──────────────────────────────────

  /// True if the customer has signed this entry.
  bool get isDualSigned => customerSig.isNotEmpty && customerPub.isNotEmpty;

  /// True if this entry has been anchored to OpenTimestamps.
  bool get isAnchored => otsProof.isNotEmpty;

  /// Human-readable short hash for display (first 8 chars of entryHash).
  String get shortHash =>
      entryHash.length >= 8 ? entryHash.substring(0, 8) : entryHash;

  /// Short chain hash for display.
  String get shortChainHash =>
      chainHash.length >= 8 ? chainHash.substring(0, 8) : chainHash;

  DateTime get dateTime =>
      DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);

  /// Returns the Go-compatible payload JSON for re-signing or verification.
  String toPayloadJson() {
    return jsonEncode({
      'id': id,
      'customer_name': customerName,
      'description': description,
      'amount': amount,
      'currency': currency,
      'type': type.value,
      'timestamp': timestamp,
      'merchant_pub': merchantPub,
    });
  }

  /// Returns the full SignedEntry JSON for passing to Go's VerifyChain / bridge.
  String toSignedEntryJson() {
    return jsonEncode({
      'payload': {
        'id': id,
        'customer_name': customerName,
        'description': description,
        'amount': amount,
        'currency': currency,
        'type': type.value,
        'timestamp': timestamp,
        'merchant_pub': merchantPub,
      },
      'merchant_sig': merchantSig,
      'customer_sig': customerSig,
      'entry_hash': entryHash,
      'prev_hash': prevHash,
      'chain_hash': chainHash,
    });
  }

  /// Constructs a SignedEntryModel from the Go bridge's SignedEntry JSON output.
  factory SignedEntryModel.fromBridgeJson(
    Map<String, dynamic> json, {
    String customerPub = '',
    String otsProof = '',
    int? otsBitcoinBlock,
  }) {
    final payload = json['payload'] as Map<String, dynamic>;
    return SignedEntryModel(
      id: payload['id'] as String,
      customerName: payload['customer_name'] as String,
      description: payload['description'] as String,
      amount: (payload['amount'] as num).toDouble(),
      currency: payload['currency'] as String? ?? 'PKR',
      type: EntryTypeX.fromString(payload['type'] as String? ?? 'credit'),
      timestamp: payload['timestamp'] as int,
      merchantPub: payload['merchant_pub'] as String? ?? '',
      merchantSig: json['merchant_sig'] as String? ?? '',
      customerSig: json['customer_sig'] as String? ?? '',
      entryHash: json['entry_hash'] as String,
      prevHash: json['prev_hash'] as String,
      chainHash: json['chain_hash'] as String,
      otsProof: otsProof,
      otsBitcoinBlock: otsBitcoinBlock,
      customerPub: customerPub,
    );
  }

  SignedEntryModel copyWith({
    String? customerSig,
    String? customerPub,
    String? otsProof,
    int? otsBitcoinBlock,
  }) {
    return SignedEntryModel(
      id: id,
      customerName: customerName,
      description: description,
      amount: amount,
      currency: currency,
      type: type,
      timestamp: timestamp,
      merchantPub: merchantPub,
      merchantSig: merchantSig,
      customerSig: customerSig ?? this.customerSig,
      entryHash: entryHash,
      prevHash: prevHash,
      chainHash: chainHash,
      otsProof: otsProof ?? this.otsProof,
      otsBitcoinBlock: otsBitcoinBlock ?? this.otsBitcoinBlock,
      customerPub: customerPub ?? this.customerPub,
    );
  }
}