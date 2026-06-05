import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../core/models/entry.dart';
import '../../core/services/ledger_service.dart';
import '../../core/services/ots_service.dart';
import '../../shared/widgets/hash_badge.dart';
import '../../shared/widgets/integrity_chip.dart';

class ReceiptExportScreen extends StatefulWidget {
  final SignedEntryModel entry;

  const ReceiptExportScreen({super.key, required this.entry});

  @override
  State<ReceiptExportScreen> createState() =>
      _ReceiptExportScreenState();
}

class _ReceiptExportScreenState extends State<ReceiptExportScreen> {
  bool _isAnchoring = false;
  String? _anchorStatus;
  String? _anchorError;

  Future<void> _anchorToOts() async {
    setState(() {
      _isAnchoring = true;
      _anchorError = null;
      _anchorStatus = null;
    });

    try {
      final ledger = context.read<LedgerService>();
      final ots = context.read<OtsService>();

      final entries = await ledger.allEntries();
      final root = await ledger
          .hashPayload(
            customerName: widget.entry.customerName,
            description: widget.entry.description,
            amount: widget.entry.amount,
            type: widget.entry.type,
          );

      final result = await ots.stampHash(root);

      if (result.success && result.proofBase64 != null) {
        await ledger.saveOtsProof(
          entryId: widget.entry.id,
          otsProof: result.proofBase64!,
        );
        await ledger.saveAnchoredRoot(root);
        if (mounted) {
          setState(() {
            _anchorStatus =
                'Submitted to OpenTimestamps. Bitcoin confirmation in ~1 hour.';
            _isAnchoring = false;
          });
        }
      } else {
        setState(() {
          _anchorError = result.errorMessage ?? 'Anchoring failed';
          _isAnchoring = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _anchorError = e.toString();
          _isAnchoring = false;
        });
      }
    }
  }

  void _copyReceiptJson() {
    final ledger = context.read<LedgerService>();
    final payload = ledger.buildReceiptPayload(widget.entry);
    final json =
        const JsonEncoder.withIndent('  ').convert(payload);
    Clipboard.setData(ClipboardData(text: json));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Receipt JSON copied to clipboard'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final isCredit = entry.type == EntryType.credit;
    final amountColor = isCredit
        ? const Color(0xFFD7263D)
        : const Color(0xFF2ECC71);

    return Scaffold(
      appBar: AppBar(title: const Text('Receipt & Export')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Entry summary card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isCredit
                    ? [
                        const Color(0xFFD7263D),
                        const Color(0xFF9B1A2A)
                      ]
                    : [
                        const Color(0xFF2ECC71),
                        const Color(0xFF1A8A4A)
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCredit ? 'Udhaar (Credit)' : 'Payment',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  '${entry.currency} ${entry.amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1),
                ),
                const SizedBox(height: 8),
                Text(entry.customerName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                Text(entry.description,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Crypto details
          _sectionTitle('Cryptographic Details'),
          const SizedBox(height: 10),
          _detailRow('Entry hash',
              child: HashBadge(hash: entry.entryHash)),
          _detailRow('Chain hash',
              child: HashBadge(hash: entry.chainHash, label: 'Chain')),
          _detailRow('Status',
              child: IntegrityChip(
                status: entry.isDualSigned
                    ? IntegrityStatus.verified
                    : IntegrityStatus.pending,
                label: entry.isDualSigned
                    ? 'Dual signed'
                    : 'Merchant only',
              )),
          if (entry.isAnchored) ...[
            _detailRow('Bitcoin',
                child: IntegrityChip(
                  status: IntegrityStatus.anchored,
                  label: entry.otsBitcoinBlock != null
                      ? 'Block #${entry.otsBitcoinBlock}'
                      : 'Pending',
                )),
          ],
          const SizedBox(height: 20),

          // OTS Anchoring
          _sectionTitle('Bitcoin Timestamp'),
          const SizedBox(height: 10),
          if (!entry.isAnchored) ...[
            Text(
              'Anchor the Merkle root of your ledger to the Bitcoin '
              'blockchain for court-ready timestamping. Free via OpenTimestamps.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (_anchorStatus != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2ECC71).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFF2ECC71)
                          .withValues(alpha: 0.3)),
                ),
                child: Text(_anchorStatus!,
                    style: const TextStyle(
                        color: Color(0xFF2ECC71), fontSize: 13)),
              ),
            if (_anchorError != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFD7263D).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFD7263D)
                          .withValues(alpha: 0.3)),
                ),
                child: Text(_anchorError!,
                    style: const TextStyle(
                        color: Color(0xFFD7263D), fontSize: 13)),
              ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isAnchoring ? null : _anchorToOts,
              icon: _isAnchoring
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.anchor_rounded, size: 18),
              label: Text(_isAnchoring
                  ? 'Anchoring...'
                  : 'Anchor to Bitcoin (free)'),
            ),
          ] else ...[
            IntegrityChip(
              status: IntegrityStatus.anchored,
              label: entry.otsBitcoinBlock != null
                  ? 'Anchored · Block #${entry.otsBitcoinBlock}'
                  : 'Pending Bitcoin confirmation',
            ),
          ],
          const SizedBox(height: 20),

          // Export
          _sectionTitle('Export'),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _copyReceiptJson,
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy receipt JSON'),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w700));
  }

  Widget _detailRow(String label, {required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
          child,
        ],
      ),
    );
  }
}