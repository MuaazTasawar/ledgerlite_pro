import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/bridge/go_bridge.dart';
import '../../core/services/ledger_service.dart';
import '../../shared/widgets/hash_badge.dart';
import '../../shared/widgets/integrity_chip.dart';
import 'chain_block_widget.dart';

class VerifyScreen extends StatefulWidget {
  const VerifyScreen({super.key});

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  VerificationResult? _result;
  bool _isVerifying = false;
  bool _hasVerified = false;

  Future<void> _runVerification() async {
    setState(() {
      _isVerifying = true;
      _hasVerified = false;
      _result = null;
    });

    try {
      final result =
          await context.read<LedgerService>().verifyFullChain();
      if (mounted) {
        setState(() {
          _result = result;
          _isVerifying = false;
          _hasVerified = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _hasVerified = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Chain')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          if (!_hasVerified && !_isVerifying) _buildStartButton(),
          if (_isVerifying) _buildVerifying(),
          if (_hasVerified && _result != null) ...[
            _buildResultCard(),
            const SizedBox(height: 20),
            ChainBlockWidget(result: _result!),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _runVerification,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Verify again'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Chain Integrity',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(
          'Verifies every entry\'s hash, signature, and chain '
          'link. Any tampering is detected immediately.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildStartButton() {
    return ElevatedButton.icon(
      onPressed: _runVerification,
      icon: const Icon(Icons.verified_user_rounded, size: 18),
      label: const Text('Verify full chain'),
    );
  }

  Widget _buildVerifying() {
    return Column(
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text('Verifying chain...',
            style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }

  Widget _buildResultCard() {
    final r = _result!;
    final isValid = r.valid;
    final color = isValid
        ? const Color(0xFF2ECC71)
        : const Color(0xFFD7263D);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isValid
                    ? Icons.verified_rounded
                    : Icons.broken_image_rounded,
                color: color,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isValid ? 'Chain intact' : 'Tampering detected!',
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                          fontSize: 18),
                    ),
                    Text(
                      isValid
                          ? '${r.entriesChecked} entries verified in ${r.durationMs}ms'
                          : 'Failed at entry ${r.failedAtIndex + 1}: ${r.reason}',
                      style: TextStyle(
                          color: color.withValues(alpha: 0.8),
                          fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isValid && r.merkleRoot.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Merkle root: ',
                    style: Theme.of(context).textTheme.bodySmall),
                HashBadge(hash: r.merkleRoot, label: 'Root'),
              ],
            ),
          ],
          const SizedBox(height: 12),
          IntegrityChip(
            status: isValid
                ? IntegrityStatus.verified
                : IntegrityStatus.failed,
          ),
        ],
      ),
    );
  }
}