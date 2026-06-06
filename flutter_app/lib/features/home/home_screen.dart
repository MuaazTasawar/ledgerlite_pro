import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/entry.dart';
import '../../core/services/key_service.dart';
import '../../core/services/ledger_service.dart';
import '../../shared/widgets/integrity_chip.dart';
import '../entry/add_entry_screen.dart';
import '../entry/entry_card.dart';
import '../verify/verify_screen.dart';
import 'home_controller.dart';
import '../../core/services/ots_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late HomeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = HomeController(
      ledgerService: context.read<LedgerService>(),
      keyService: context.read<KeyService>(),
    );
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Scaffold(
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _controller.refresh,
            color: const Color(0xFF1B8A5A),
            child: CustomScrollView(
              slivers: [
                _buildAppBar(context),
                _buildSummaryCard(context),
                _buildCustomerList(context),
                _buildRecentHeader(context),
                _buildRecentEntries(context),
                const SliverToBoxAdapter(
                    child: SizedBox(height: 100)),
              ],
            ),
          ),
        ),
        floatingActionButton: _buildFab(context),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      floating: true,
      snap: true,
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF1B8A5A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.lock_outline_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Consumer<HomeController>(
            builder: (_, ctrl, __) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ctrl.merchantName,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                Text(ctrl.shortPublicKey,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.verified_user_outlined),
          tooltip: 'Verify chain',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const VerifyScreen()),
          ).then((_) => _controller.refresh()),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    return SliverToBoxAdapter(
      child: Consumer<HomeController>(
        builder: (_, ctrl, __) {
          if (ctrl.isLoading) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final s = ctrl.summary;
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1B8A5A), Color(0xFF0F5C3A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1B8A5A).withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Outstanding',
                          style: TextStyle(
                              color:
                                  Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                      IntegrityChip(
                        status: s.isAnchored
                            ? IntegrityStatus.anchored
                            : IntegrityStatus.pending,
                        compact: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${s.currency} ${s.netOutstanding.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _summaryPill(
                        label: 'Credit given',
                        value:
                            '${s.currency} ${s.totalCreditOut.toStringAsFixed(0)}',
                        icon: Icons.arrow_upward_rounded,
                      ),
                      const SizedBox(width: 10),
                      _summaryPill(
                        label: 'Paid back',
                        value:
                            '${s.currency} ${s.totalPaidBack.toStringAsFixed(0)}',
                        icon: Icons.arrow_downward_rounded,
                      ),
                      const Spacer(),
                      _summaryPill(
                        label: 'Entries',
                        value: '${s.totalEntries}',
                        icon: Icons.receipt_long_rounded,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _summaryPill({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white70),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 10)),
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerList(BuildContext context) {
    return SliverToBoxAdapter(
      child: Consumer<HomeController>(
        builder: (_, ctrl, __) {
          if (ctrl.customerNames.isEmpty) {
            return const SizedBox.shrink();
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                child: Text('Customers',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: ctrl.customerNames.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final name = ctrl.customerNames[i];
                    return ActionChip(
                      label: Text(name),
                      avatar: CircleAvatar(
                        backgroundColor: const Color(0xFF1B8A5A),
                        radius: 10,
                        child: Text(
                          name.isNotEmpty
                              ? name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      onPressed: () {},
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRecentHeader(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent entries',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            Consumer<HomeController>(
              builder: (_, ctrl, __) => Text(
                '${ctrl.summary.totalEntries} total',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentEntries(BuildContext context) {
    return Consumer<HomeController>(
      builder: (_, ctrl, __) {
        if (ctrl.isLoading) {
          return const SliverToBoxAdapter(child: SizedBox());
        }
        if (ctrl.recentEntries.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 56, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text('No entries yet',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: Colors.grey.shade400)),
                  const SizedBox(height: 6),
                  Text('Tap + to record your first udhaar',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) => Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 4),
              child: EntryCard(
                entry: ctrl.recentEntries[i],
                onTap: () {},
              ),
            ),
            childCount: ctrl.recentEntries.length,
          ),
        );
      },
    );
  }
  Future<void> _showAnchorDialog(BuildContext context) async {
    final ledger = context.read<LedgerService>();
    final ots = context.read<OtsService>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Computing Merkle root...'),
          ],
        ),
      ),
    );

    try {
      final summary = await ledger.summary();
      if (!mounted) return;
      Navigator.pop(context); // close loading dialog

      if (summary.totalEntries == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No entries to anchor yet'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (summary.isAnchored) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Current chain already anchored'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Show confirm dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Anchor to Bitcoin?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This will submit your Merkle root to '
                'OpenTimestamps (free). Bitcoin confirmation '
                'takes ~1 hour.',
              ),
              const SizedBox(height: 12),
              Text(
                'Entries: ${summary.totalEntries}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Anchor'),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      // Show anchoring progress
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Submitting to OpenTimestamps...'),
            ],
          ),
        ),
      );

      final result = await ots.stampHash(summary.merkleRoot);
      if (!mounted) return;
      Navigator.pop(context); // close progress dialog

      if (result.success && result.proofBase64 != null) {
        await ledger.saveAnchoredRoot(summary.merkleRoot);
        _controller.refresh();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '✓ Anchored! Bitcoin confirmation in ~1 hour.',
            ),
            backgroundColor: const Color(0xFF1B8A5A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Anchoring failed: ${result.errorMessage ?? "unknown error"}'),
            backgroundColor: const Color(0xFFD7263D),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFD7263D),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
  Widget _buildFab(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddEntryScreen()),
      ).then((_) => _controller.refresh()),
      backgroundColor: const Color(0xFF1B8A5A),
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add_rounded),
      label: const Text('Add Entry',
          style: TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}