import 'entry.dart';

/// LedgerSummary holds aggregate stats for the home screen.
class LedgerSummary {
  final int totalEntries;
  final double totalCreditOut; // total udhaar given
  final double totalPaidBack; // total payments received
  final double netOutstanding; // totalCreditOut - totalPaidBack
  final String currency;
  final String headChainHash; // chain_hash of last entry
  final String merkleRoot; // last computed Merkle root
  final bool isAnchored; // whether latest root is anchored

  const LedgerSummary({
    required this.totalEntries,
    required this.totalCreditOut,
    required this.totalPaidBack,
    required this.netOutstanding,
    required this.currency,
    required this.headChainHash,
    required this.merkleRoot,
    required this.isAnchored,
  });

  factory LedgerSummary.empty() => const LedgerSummary(
        totalEntries: 0,
        totalCreditOut: 0,
        totalPaidBack: 0,
        netOutstanding: 0,
        currency: 'PKR',
        headChainHash: 'GENESIS',
        merkleRoot: '',
        isAnchored: false,
      );

  factory LedgerSummary.fromEntries(
    List<SignedEntryModel> entries, {
    required String merkleRoot,
    required bool isAnchored,
  }) {
    double creditOut = 0;
    double paidBack = 0;
    for (final e in entries) {
      if (e.type == EntryType.credit) {
        creditOut += e.amount;
      } else {
        paidBack += e.amount;
      }
    }
    final head = entries.isEmpty ? 'GENESIS' : entries.last.chainHash;
    return LedgerSummary(
      totalEntries: entries.length,
      totalCreditOut: creditOut,
      totalPaidBack: paidBack,
      netOutstanding: creditOut - paidBack,
      currency: entries.isEmpty ? 'PKR' : entries.first.currency,
      headChainHash: head,
      merkleRoot: merkleRoot,
      isAnchored: isAnchored,
    );
  }
}

/// CustomerLedger groups all entries for a single customer.
class CustomerLedger {
  final String customerName;
  final String customerPub; // Ed25519 public key (hex) — empty if not a registered customer
  final List<SignedEntryModel> entries;

  const CustomerLedger({
    required this.customerName,
    required this.customerPub,
    required this.entries,
  });

  double get totalCredit => entries
      .where((e) => e.type == EntryType.credit)
      .fold(0.0, (sum, e) => sum + e.amount);

  double get totalPaid => entries
      .where((e) => e.type == EntryType.payment)
      .fold(0.0, (sum, e) => sum + e.amount);

  double get balance => totalCredit - totalPaid;

  bool get isSettled => balance <= 0;

  int get dualSignedCount => entries.where((e) => e.isDualSigned).length;
}