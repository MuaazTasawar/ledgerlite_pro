import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/models/entry.dart';
import '../../core/services/ledger_service.dart';
import '../../shared/widgets/hash_badge.dart';
import '../qr/merchant_qr_screen.dart';

class AddEntryScreen extends StatefulWidget {
  const AddEntryScreen({super.key});

  @override
  State<AddEntryScreen> createState() => _AddEntryScreenState();
}

class _AddEntryScreenState extends State<AddEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  EntryType _selectedType = EntryType.credit;
  String _liveHash = '';
  bool _isHashLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  DateTime _lastTypeTime = DateTime.now();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    _lastTypeTime = DateTime.now();
    setState(() => _isHashLoading = true);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (DateTime.now().difference(_lastTypeTime).inMilliseconds <390) return;
      _updateLiveHash();
    });
  }

  Future<void> _updateLiveHash() async {
    final name = _nameCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text) ?? 0;

    if (name.isEmpty && desc.isEmpty && amount == 0) {
      setState(() {
        _liveHash = '';
        _isHashLoading = false;
      });
      return;
    }

    try {
      final hash = await context.read<LedgerService>().hashPayload(
            customerName: name.isEmpty ? 'preview' : name,
            description: desc.isEmpty ? 'preview' : desc,
            amount: amount == 0 ? 1 : amount,
            type: _selectedType,
          );
      if (mounted) {
        setState(() {
          _liveHash = hash;
          _isHashLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isHashLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      setState(() =>
          _errorMessage = 'Enter a valid amount greater than 0');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final entry = await context.read<LedgerService>().addEntry(
            customerName: _nameCtrl.text.trim(),
            description: _descCtrl.text.trim(),
            amount: amount,
            type: _selectedType,
          );

      if (mounted) {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => MerchantQrScreen(entry: entry)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Entry'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildTypeToggle(),
            const SizedBox(height: 24),
            _buildField(
              controller: _nameCtrl,
              label: 'Customer name',
              hint: 'e.g. Ahmed Khan',
              icon: Icons.person_outline_rounded,
              onChanged: (_) => _onFieldChanged(),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Enter customer name'
                  : null,
            ),
            const SizedBox(height: 16),
            _buildField(
              controller: _descCtrl,
              label: 'Description',
              hint: 'e.g. Rice 5kg, Cooking oil',
              icon: Icons.notes_rounded,
              onChanged: (_) => _onFieldChanged(),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Enter a description'
                  : null,
            ),
            const SizedBox(height: 16),
            _buildField(
              controller: _amountCtrl,
              label: 'Amount (PKR)',
              hint: '0',
              icon: Icons.currency_rupee_rounded,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'^\d+\.?\d{0,2}'))
              ],
              onChanged: (_) => _onFieldChanged(),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Enter amount';
                }
                if (double.tryParse(v) == null) {
                  return 'Invalid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            _buildHashPreview(),
            const SizedBox(height: 8),
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFD7263D).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFD7263D)
                          .withValues(alpha: 0.3)),
                ),
                child: Text(_errorMessage!,
                    style: const TextStyle(
                        color: Color(0xFFD7263D), fontSize: 13)),
              ),
              const SizedBox(height: 16),
            ],
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.lock_rounded, size: 18),
              label: Text(
                  _isSaving ? 'Signing...' : 'Sign & Save Entry'),
            ),
            const SizedBox(height: 12),
            Text(
              'This entry will be signed with your merchant key '
              'and added to the cryptographic chain.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: EntryType.values.map((type) {
          final isSelected = _selectedType == type;
          final isCredit = type == EntryType.credit;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedType = type);
                _onFieldChanged();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isCredit
                          ? const Color(0xFFD7263D)
                          : const Color(0xFF2ECC71))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isCredit
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size: 16,
                      color:
                          isSelected ? Colors.white : Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isCredit ? 'Udhaar (Credit)' : 'Payment',
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : Colors.grey,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Function(String) onChanged,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildHashPreview() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF6B7FD7).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFF6B7FD7).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.fingerprint_rounded,
              color: Color(0xFF6B7FD7), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Entry fingerprint (live)',
                  style: TextStyle(
                    fontSize: 11,
                    color: const Color(0xFF6B7FD7)
                        .withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                HashBadge(
                  hash: _liveHash,
                  isLoading: _isHashLoading,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}