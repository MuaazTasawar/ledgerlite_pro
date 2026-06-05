import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/services/key_service.dart';
import '../../core/services/ledger_service.dart';
import '../../shared/theme.dart';
import '../../shared/widgets/integrity_chip.dart';

enum CustomerScanMode {
  customerSignsEntry,
  merchantReceivesConfirmation,
}

class CustomerScanScreen extends StatefulWidget {
  final CustomerScanMode mode;
  const CustomerScanScreen({super.key, required this.mode});

  @override
  State<CustomerScanScreen> createState() => _CustomerScanScreenState();
}

class _CustomerScanScreenState extends State<CustomerScanScreen> {
  final MobileScannerController _scannerCtrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _scanned = false;
  bool _isProcessing = false;
  String? _error;
  String? _confirmationQrPayload;
  Map<String, dynamic>? _scannedEntryPreview;

  @override
  void dispose() {
    _scannerCtrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned || _isProcessing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null) return;
    final raw = barcode.rawValue;
    if (raw == null || raw.isEmpty) return;

    setState(() => _scanned = true);
    _scannerCtrl.stop();

    if (widget.mode == CustomerScanMode.customerSignsEntry) {
      _handleCustomerSign(raw);
    } else {
      _handleMerchantReceivesConfirmation(raw);
    }
  }

  Future<void> _handleCustomerSign(String qrRaw) async {
    if (!qrRaw.startsWith('llpro:sign:')) {
      setState(() {
        _error = 'Invalid QR — not a LedgerLite entry';
        _scanned = false;
      });
      _scannerCtrl.start();
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final encoded = qrRaw.substring('llpro:sign:'.length);
      final entryJson = utf8.decode(base64Decode(encoded));
      final entryMap = jsonDecode(entryJson) as Map<String, dynamic>;
      final payload = entryMap['payload'] as Map<String, dynamic>;

      setState(() => _scannedEntryPreview = payload);

      final keyService = context.read<KeyService>();
      if (!keyService.isReady) {
        setState(() {
          _error = 'Key service not ready — please restart the app';
          _isProcessing = false;
          _scanned = false;
        });
        _scannerCtrl.start();
        return;
      }

      final updatedJson =
          await context.read<LedgerService>().signAsCustomer(
                signedEntryJson: entryJson,
                customerPrivateKeyHex: keyService.privateKey,
              );

      final updatedMap =
          jsonDecode(updatedJson) as Map<String, dynamic>;
      final customerSig = updatedMap['customer_sig'] as String? ?? '';
      final customerPub = keyService.publicKey;

      final confirmJson = jsonEncode({
        'customer_sig': customerSig,
        'customer_pub': customerPub,
        'entry_hash': updatedMap['entry_hash'],
      });
      final confirmEncoded = base64Encode(utf8.encode(confirmJson));

      if (mounted) {
        setState(() {
          _confirmationQrPayload = 'llpro:confirm:$confirmEncoded';
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to sign entry: $e';
          _isProcessing = false;
          _scanned = false;
        });
        _scannerCtrl.start();
      }
    }
  }

  void _handleMerchantReceivesConfirmation(String qrRaw) {
    if (!qrRaw.startsWith('llpro:confirm:')) {
      setState(() {
        _error = 'Invalid QR — not a LedgerLite confirmation';
        _scanned = false;
      });
      _scannerCtrl.start();
      return;
    }

    try {
      final encoded = qrRaw.substring('llpro:confirm:'.length);
      final confirmJson = utf8.decode(base64Decode(encoded));
      final confirmMap =
          jsonDecode(confirmJson) as Map<String, dynamic>;

      final customerSig = confirmMap['customer_sig'] as String? ?? '';
      final customerPub = confirmMap['customer_pub'] as String? ?? '';

      if (customerSig.isEmpty || customerPub.isEmpty) {
        setState(() {
          _error = 'Confirmation QR is missing required fields';
          _scanned = false;
        });
        _scannerCtrl.start();
        return;
      }

      Navigator.pop(context, {
        'customer_sig': customerSig,
        'customer_pub': customerPub,
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to parse confirmation: $e';
        _scanned = false;
      });
      _scannerCtrl.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_confirmationQrPayload != null) {
      return _buildConfirmationQr();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.mode == CustomerScanMode.customerSignsEntry
              ? 'Scan Merchant QR'
              : 'Scan Customer Confirmation',
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerCtrl,
            onDetect: _onDetect,
          ),
          _buildScanOverlay(),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text('Signing entry...',
                        style: TextStyle(
                            color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
            ),
          if (_error != null)
            Positioned(
              bottom: 40,
              left: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.dangerRed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13)),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _error = null),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 18),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScanOverlay() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: Colors.black54,
          padding:
              const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          child: Text(
            widget.mode == CustomerScanMode.customerSignsEntry
                ? 'Point camera at the merchant\'s QR code'
                : 'Point camera at the customer\'s confirmation QR',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ),
        const Spacer(),
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(
                  color: AppTheme.primaryGreen, width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(children: _buildCorners()),
          ),
        ),
        const Spacer(),
        Container(
          width: double.infinity,
          color: Colors.black54,
          padding: const EdgeInsets.all(20),
          child: Text(
            widget.mode == CustomerScanMode.customerSignsEntry
                ? 'Your Ed25519 key will sign this entry'
                : 'Verifying customer Ed25519 signature',
            style:
                const TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildCorners() {
    const size = 20.0;
    const thickness = 3.0;
    final color = AppTheme.primaryGreen;
    return [
      Positioned(top: 0, left: 0,
          child: Container(width: size, height: thickness, color: color)),
      Positioned(top: 0, left: 0,
          child: Container(width: thickness, height: size, color: color)),
      Positioned(top: 0, right: 0,
          child: Container(width: size, height: thickness, color: color)),
      Positioned(top: 0, right: 0,
          child: Container(width: thickness, height: size, color: color)),
      Positioned(bottom: 0, left: 0,
          child: Container(width: size, height: thickness, color: color)),
      Positioned(bottom: 0, left: 0,
          child: Container(width: thickness, height: size, color: color)),
      Positioned(bottom: 0, right: 0,
          child: Container(width: size, height: thickness, color: color)),
      Positioned(bottom: 0, right: 0,
          child: Container(width: thickness, height: size, color: color)),
    ];
  }

  Widget _buildConfirmationQr() {
    final payload = _scannedEntryPreview;
    return Scaffold(
      appBar: AppBar(title: const Text('Show Merchant This QR')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.successGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppTheme.successGreen.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: AppTheme.successGreen, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Entry signed successfully',
                        style: TextStyle(
                          color: AppTheme.successGreen,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'Show the QR below to the merchant',
                        style: TextStyle(
                          color: AppTheme.successGreen
                              .withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (payload != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _previewRow(
                      'Customer', payload['customer_name'] ?? ''),
                  _previewRow(
                      'Description', payload['description'] ?? ''),
                  _previewRow(
                    'Amount',
                    '${payload['currency'] ?? 'PKR'} ${payload['amount'] ?? 0}',
                  ),
                  _previewRow(
                    'Type',
                    (payload['type'] ?? 'credit')
                        .toString()
                        .toUpperCase(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.successGreen.withValues(alpha: 0.2),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: QrImageView(
                data: _confirmationQrPayload!,
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const IntegrityChip(
            status: IntegrityStatus.verified,
            label: 'Signed with your Ed25519 key',
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _previewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
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
          Expanded(
            child: Text(value,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}