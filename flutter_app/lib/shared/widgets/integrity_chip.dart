import 'package:flutter/material.dart';

enum IntegrityStatus { verified, failed, pending, anchored }

class IntegrityChip extends StatelessWidget {
  final IntegrityStatus status;
  final String? label;
  final bool compact;

  const IntegrityChip({
    super.key,
    required this.status,
    this.label,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = _config();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: config.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, size: compact ? 12 : 14, color: config.color),
          const SizedBox(width: 5),
          Text(
            label ?? config.label,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              color: config.color,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  _ChipConfig _config() {
    switch (status) {
      case IntegrityStatus.verified:
        return _ChipConfig(
          color: const Color(0xFF2ECC71),
          icon: Icons.verified_rounded,
          label: 'Chain intact',
        );
      case IntegrityStatus.failed:
        return _ChipConfig(
          color: const Color(0xFFD7263D),
          icon: Icons.broken_image_rounded,
          label: 'Tampered!',
        );
      case IntegrityStatus.pending:
        return _ChipConfig(
          color: const Color(0xFFF5A623),
          icon: Icons.hourglass_top_rounded,
          label: 'Pending',
        );
      case IntegrityStatus.anchored:
        return _ChipConfig(
          color: const Color(0xFFF7931A),
          icon: Icons.anchor_rounded,
          label: 'Bitcoin anchored',
        );
    }
  }
}

class _ChipConfig {
  final Color color;
  final IconData icon;
  final String label;
  const _ChipConfig({
    required this.color,
    required this.icon,
    required this.label,
  });
}