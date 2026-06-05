import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HashBadge extends StatelessWidget {
  final String hash;
  final String label;
  final bool isLoading;
  final Color? color;

  const HashBadge({
    super.key,
    required this.hash,
    this.label = '',
    this.isLoading = false,
    this.color,
  });

  static const Color _defaultHashColor = Color(0xFF6B7FD7);

  String get _displayHash {
    if (hash.isEmpty) return '--------';
    if (hash.length >= 16) {
      return '${hash.substring(0, 8)}…${hash.substring(hash.length - 4)}';
    }
    return hash;
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor = color ?? _defaultHashColor;

    return GestureDetector(
      onTap: hash.isNotEmpty
          ? () {
              Clipboard.setData(ClipboardData(text: hash));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'Hash copied to clipboard',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                  backgroundColor: badgeColor,
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: badgeColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tag_rounded, size: 12, color: badgeColor),
            const SizedBox(width: 4),
            if (label.isNotEmpty) ...[
              Text(
                '$label: ',
                style: TextStyle(
                  fontSize: 11,
                  color: badgeColor.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            if (isLoading)
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: badgeColor,
                ),
              )
            else
              Text(
                _displayHash,
                style: TextStyle(
                  fontSize: 11,
                  color: badgeColor,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
          ],
        ),
      ),
    );
  }
}