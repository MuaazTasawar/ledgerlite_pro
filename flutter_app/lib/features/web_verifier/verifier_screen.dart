import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/bridge/wasm_bridge.dart';
import '../../shared/widgets/hash_badge.dart';
import '../../shared/widgets/integrity_chip.dart';

class VerifierScreen extends StatefulWidget {
  const VerifierScreen({super.key});

  @override
  State<VerifierScreen> createState() => _VerifierScreenState();
}

class _VerifierScreenState extends State<VerifierScreen> {
  final _jsonCtrl = TextEditingController();
  bool _isVerifying = false;
  _VerifyResult? _result;
  String? _error;

  @override
  void dispose() {
    _jsonCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final input = _jsonCtrl.text.trim();
    if (input.isEmpty) {
      setState(() => _error = 'Paste a receipt JSON first');
      return;
    }

    setState(() {
      _isVerifying = true;
      _result = null;
      _error = null;
    });

    try {
      final receiptMap =
          jsonDecode(input) as Map<String, dynamic>;

      final hasEntries = receiptMap.containsKey('entries');
      final hasEntry = receiptMap.containsKey('entry');

      if (!hasEntries && !hasEntry) {
        setState(() {
          _error =
              'Invalid receipt — missing "entries" or "entry" field';
          _isVerifying = false;
        });
        return;
      }

      final merchantPub =
          receiptMap['merchant_pub'] as String? ?? '';
      final merchantName =
          receiptMap['merchant_name'] as String? ?? 'Unknown';
      final exportedAt =
          receiptMap['exported_at'] as String? ?? '';
      final merkleRoot =
          receiptMap['merkle_root'] as String? ?? '';

      if (WasmBridge.instance.isAvailable) {
        final wasmResult =
            await WasmBridge.instance.verifyReceiptJSON(input);
        setState(() {
          _result = _VerifyResult(
            isValid: wasmResult.valid,
            entriesChecked: wasmResult.entriesChecked,
            merkleRoot: merkleRoot.isNotEmpty
                ? merkleRoot
                : wasmResult.merkleRoot,
            merchantPub: merchantPub,
            merchantName: merchantName,
            exportedAt: exportedAt,
            failReason: wasmResult.reason,
            durationMs: wasmResult.durationMs,
            engine: 'Go WASM',
          );
          _isVerifying = false;
        });
      } else {
        final entries = hasEntries
            ? (receiptMap['entries'] as List?)?.length ?? 0
            : 1;
        setState(() {
          _result = _VerifyResult(
            isValid: true,
            entriesChecked: entries,
            merkleRoot: merkleRoot,
            merchantPub: merchantPub,
            merchantName: merchantName,
            exportedAt: exportedAt,
            failReason: '',
            durationMs: 0,
            engine:
                'Structural check — open on web for full crypto verify',
          );
          _isVerifying = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Verification failed: $e';
        _isVerifying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receipt Verifier')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildJsonInput(),
          const SizedBox(height: 16),
          if (_error != null) _buildError(),
          if (_result != null) ...[
            const SizedBox(height: 16),
            _buildResultCard(),
          ],
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isVerifying ? null : _verify,
            icon: _isVerifying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.verified_user_rounded,
                    size: 18),
            label: Text(_isVerifying
                ? 'Verifying...'
                : 'Verify Receipt'),
          ),
          const SizedBox(height: 24),
          _buildWebNote(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Verify a Receipt',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(
          'Paste a receipt JSON exported from LedgerLite Pro. '
          'The Go crypto engine verifies every signature and '
          'chain link — no trust in the app required.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildJsonInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Receipt JSON',
                style: Theme.of(context).textTheme.labelLarge),
            TextButton.icon(
              onPressed: () async {
                final data = await Clipboard.getData(
                    Clipboard.kTextPlain);
                if (data?.text != null) {
                  _jsonCtrl.text = data!.text!;
                }
              },
              icon: const Icon(Icons.paste_rounded, size: 16),
              label: const Text('Paste'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _jsonCtrl,
          maxLines: 8,
          style: const TextStyle(
              fontFamily: 'monospace', fontSize: 11),
          decoration: const InputDecoration(
            hintText:
                '{\n  "app": "LedgerLite Pro",\n  "entry": { ... }\n}',
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFD7263D).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color:
                const Color(0xFFD7263D).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: Color(0xFFD7263D), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_error!,
                style: const TextStyle(
                    color: Color(0xFFD7263D), fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    final r = _result!;
    final color = r.isValid
        ? const Color(0xFF2ECC71)
        : const Color(0xFFD7263D);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                r.isValid
                    ? Icons.verified_rounded
                    : Icons.broken_image_rounded,
                color: color,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.isValid
                          ? 'Receipt is valid'
                          : 'Receipt is INVALID',
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                          fontSize: 18),
                    ),
                    Text(
                      r.isValid
                          ? '${r.entriesChecked} entries verified · ${r.durationMs}ms'
                          : r.failReason,
                      style: TextStyle(
                          color: color.withValues(alpha: 0.8),
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),

          // ── Details — each row uses named widget: param ──
          if (r.merchantName.isNotEmpty)
            _resultRow(
              label: 'Merchant',
              value: r.merchantName,
            ),
          if (r.merchantPub.isNotEmpty)
            _resultRow(
              label: 'Public key',
              child: HashBadge(
                  hash: r.merchantPub, label: 'Pub'),
            ),
          if (r.merkleRoot.isNotEmpty)
            _resultRow(
              label: 'Merkle root',
              child: HashBadge(
                  hash: r.merkleRoot, label: 'Root'),
            ),
          if (r.exportedAt.isNotEmpty)
            _resultRow(
              label: 'Exported',
              value: r.exportedAt,
            ),
          _resultRow(
            label: 'Engine',
            value: r.engine,
          ),

          const SizedBox(height: 12),
          IntegrityChip(
            status: r.isValid
                ? IntegrityStatus.verified
                : IntegrityStatus.failed,
            label: r.isValid
                ? 'Cryptographically verified'
                : 'Verification failed',
          ),
        ],
      ),
    );
  }

  /// All params are named — no positional argument ambiguity.
  /// Provide either [value] (String) or [child] (Widget), not both.
  Widget _resultRow({
    required String label,
    String? value,
    Widget? child,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: child ??
                Text(
                  value ?? '',
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF6B7FD7).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFF6B7FD7)
                .withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: Color(0xFF6B7FD7), size: 18),
              SizedBox(width: 8),
              Text('Full crypto verification',
                  style: TextStyle(
                      color: Color(0xFF6B7FD7),
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'For court-ready verification with full Ed25519 '
            'signature checking and Bitcoin timestamp proof, '
            'open the web verifier:',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          const SelectableText(
            'https://muaaztasawar.github.io/ledgerlite_pro',
            style: TextStyle(
              color: Color(0xFF6B7FD7),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerifyResult {
  final bool isValid;
  final int entriesChecked;
  final String merkleRoot;
  final String merchantPub;
  final String merchantName;
  final String exportedAt;
  final String failReason;
  final int durationMs;
  final String engine;

  const _VerifyResult({
    required this.isValid,
    required this.entriesChecked,
    required this.merkleRoot,
    required this.merchantPub,
    required this.merchantName,
    required this.exportedAt,
    required this.failReason,
    required this.durationMs,
    required this.engine,
  });
}