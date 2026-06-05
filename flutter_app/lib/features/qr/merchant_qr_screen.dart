import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/models/entry.dart';
import '../../core/services/ledger_service.dart';
import '../../shared/theme.dart';
import '../../shared/widgets/hash_badge.dart';
import '../../shared/widgets/integrity_chip.dart';
import 'customer_scan_screen.dart';

class MerchantQrScreen extends StatefulWidget {
  final SignedEntryModel entry;
  const MerchantQrScreen({super.key, required this.entry});

  @override
  State<MerchantQrScreen> createState() => _MerchantQrScreenState();
}

class _MerchantQrScreenState extends State<MerchantQrScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  bool _isCompleted = false;
  bool _isProcessing = false;
  String? _error;
  SignedEntryModel? _updatedEntry;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  String get _qrPayload {
    final entryJson = widget.entry.toSignedEntryJson();
    final encoded = base64Encode(utf8.encode(entryJson));
    return 'llpro:sign:$encoded';
  }

  Future<void> _scanCustomerConfirmation() async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => const CustomerScanScreen(
          mode: CustomerScanMode.merchantReceivesConfirmation,
        ),
      ),
    );

    if (result == null || !mounted) return;

    final customerSig = result['customer_sig'] ?? '';
    final customerPub = result['customer_pub'] ?? '';

    if (customerSig.isEmpty || customerPub.isEmpty) {
      setState(() =>
          _error = 'Invalid confirmation QR — missing signature or public key');
      return;
    }

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      await context.read<LedgerService>().applyCustomerSignature(
            entryId: widget.entry.id,
            customerSig: customerSig,
            customerPubKey: customerPub,
          );

      final updated = widget.entry.copyWith(
        customerSig: customerSig,
        customerPub: customerPub,
      );

      if (mounted) {
        setState(() {
          _isCompleted = true;
          _isProcessing = false;
          _updatedEntry = updated;
        });
        _pulseCtrl.stop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _error = 'Failed to apply signature: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Get Customer Signature'),
        actions: [
          if (!_isCompleted)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Skip',
                  style: TextStyle(color: Colors.grey.shade500)),
            ),
        ],
      ),
      body: _isCompleted ? _buildSuccess() : _buildQrStep(),
    );
  }

  Widget _buildQrStep() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildStepIndicator(1),
        const SizedBox(height: 28),
        Text(
          'Show this QR to your customer',
          style: Theme.of(context).textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'They scan it on their phone to sign the entry. '
          'Once signed, scan their confirmation QR below.',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        _buildEntrySummary(),
        const SizedBox(height: 24),
        Center(
          child: AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, child) =>
                Transform.scale(scale: _pulseAnim.value, child: child),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.2),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: QrImageView(
                data: _qrPayload,
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: HashBadge(
            hash: widget.entry.entryHash,
            label: 'Entry',
          ),
        ),
        const SizedBox(height: 32),
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.dangerRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppTheme.dangerRed.withValues(alpha: 0.3)),
            ),
            child: Text(
              _error!,
              style: TextStyle(color: AppTheme.dangerRed, fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
        ],
        ElevatedButton.icon(
          onPressed: _isProcessing ? null : _scanCustomerConfirmation,
          icon: _isProcessing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.qr_code_scanner_rounded, size: 18),
          label: Text(_isProcessing
              ? 'Verifying signature...'
              : 'Scan customer confirmation'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Save without customer signature'),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.verified_rounded,
                  color: AppTheme.successGreen, size: 44),
            ),
            const SizedBox(height: 20),
            Text(
              'Dual signature complete!',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Both merchant and customer have signed this entry. '
              'Neither party can alter it without detection.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const IntegrityChip(
              status: IntegrityStatus.verified,
              label: 'Dual signed · Tamper-proof',
            ),
            const SizedBox(height: 8),
            if (_updatedEntry != null)
              HashBadge(
                  hash: _updatedEntry!.chainHash, label: 'Chain'),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntrySummary() {
    final isCredit = widget.entry.type == EntryType.credit;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isCredit
                  ? AppTheme.dangerRed.withValues(alpha: 0.1)
                  : AppTheme.successGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCredit
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              color:
                  isCredit ? AppTheme.dangerRed : AppTheme.successGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.entry.customerName,
                    style: Theme.of(context).textTheme.titleMedium),
                Text(
                  widget.entry.description,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            '${widget.entry.currency} ${widget.entry.amount.toStringAsFixed(0)}',
            style: TextStyle(
              color:
                  isCredit ? AppTheme.dangerRed : AppTheme.successGreen,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int currentStep) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _stepDot(1, 'Show QR', currentStep),
        _stepLine(currentStep > 1),
        _stepDot(2, 'Customer signs', currentStep),
        _stepLine(currentStep > 2),
        _stepDot(3, 'Done', currentStep),
      ],
    );
  }

  Widget _stepDot(int step, String label, int current) {
    final isActive = step == current;
    final isDone = step < current || _isCompleted;
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone
                ? AppTheme.successGreen
                : isActive
                    ? AppTheme.primaryGreen
                    : Colors.grey.shade200,
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check_rounded,
                    color: Colors.white, size: 14)
                : Text(
                    '$step',
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isActive ? AppTheme.primaryGreen : Colors.grey,
            fontWeight:
                isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _stepLine(bool filled) {
    return Container(
      width: 32,
      height: 2,
      margin: const EdgeInsets.only(bottom: 16),
      color: filled ? AppTheme.successGreen : Colors.grey.shade200,
    );
  }
}