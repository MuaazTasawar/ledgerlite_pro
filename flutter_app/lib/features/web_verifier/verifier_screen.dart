import 'package:flutter/material.dart';
import '../../shared/widgets/hash_badge.dart';
import '../../shared/widgets/integrity_chip.dart';

/// VerifierScreen — placeholder for the Go WASM web verifier.
/// Full implementation arrives in Phase 9 (WASM build).
class VerifierScreen extends StatelessWidget {
  const VerifierScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Web Verifier')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Browser-based Verifier',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'The Go crypto engine is compiled to WebAssembly and '
              'hosted on GitHub Pages. Any third party can verify '
              'a receipt JSON in any browser — no app required.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            const IntegrityChip(
              status: IntegrityStatus.pending,
              label: 'WASM build — Phase 9',
            ),
            const SizedBox(height: 16),
            HashBadge(hash: 'coming_in_phase_9', label: 'WASM'),
          ],
        ),
      ),
    );
  }
}