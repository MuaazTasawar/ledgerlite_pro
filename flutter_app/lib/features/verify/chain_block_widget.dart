import 'package:flutter/material.dart';
import '../../core/bridge/go_bridge.dart';
import '../../shared/widgets/hash_badge.dart';
import '../../shared/widgets/integrity_chip.dart';

class ChainBlockWidget extends StatefulWidget {
  final VerificationResult result;

  const ChainBlockWidget({super.key, required this.result});

  @override
  State<ChainBlockWidget> createState() => _ChainBlockWidgetState();
}

class _ChainBlockWidgetState extends State<ChainBlockWidget> {
  int _revealedCount = 0;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _startReveal();
  }

  Future<void> _startReveal() async {
    setState(() => _isAnimating = true);
    final total = widget.result.entriesChecked;
    for (int i = 0; i < total; i++) {
      await Future.delayed(const Duration(milliseconds: 80));
      if (mounted) setState(() => _revealedCount = i + 1);
    }
    setState(() => _isAnimating = false);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final total = r.entriesChecked;

    if (total == 0) {
      return Center(
        child: Text('No entries to display',
            style: Theme.of(context).textTheme.bodyMedium),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Block-by-block result',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (_isAnimating)
              Text(
                '$_revealedCount / $total',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: total,
          itemBuilder: (context, i) {
            if (i >= _revealedCount) return const SizedBox.shrink();

            final isFailed =
                !r.valid && i == r.failedAtIndex;
            final isPastFailed =
                !r.valid && i > r.failedAtIndex;

            return _BlockTile(
              index: i,
              isFailed: isFailed,
              isPastFailed: isPastFailed,
              failReason: isFailed ? r.reason : null,
            );
          },
        ),
      ],
    );
  }
}

class _BlockTile extends StatefulWidget {
  final int index;
  final bool isFailed;
  final bool isPastFailed;
  final String? failReason;

  const _BlockTile({
    required this.index,
    required this.isFailed,
    required this.isPastFailed,
    this.failReason,
  });

  @override
  State<_BlockTile> createState() => _BlockTileState();
}

class _BlockTileState extends State<_BlockTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnim =
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isFailed
        ? const Color(0xFFD7263D)
        : widget.isPastFailed
            ? Colors.grey
            : const Color(0xFF2ECC71);

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            // Block number
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: widget.isFailed
                    ? Icon(Icons.close_rounded,
                        color: color, size: 14)
                    : widget.isPastFailed
                        ? Icon(Icons.remove_rounded,
                            color: color, size: 14)
                        : Icon(Icons.check_rounded,
                            color: color, size: 14),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Block ${widget.index + 1}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  if (widget.failReason != null)
                    Text(
                      widget.failReason!,
                      style: TextStyle(
                          color: color.withValues(alpha: 0.8),
                          fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            IntegrityChip(
              status: widget.isFailed
                  ? IntegrityStatus.failed
                  : widget.isPastFailed
                      ? IntegrityStatus.pending
                      : IntegrityStatus.verified,
              compact: true,
            ),
          ],
        ),
      ),
    );
  }
}