import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/entry.dart';
import '../../shared/widgets/hash_badge.dart';
import '../../shared/widgets/integrity_chip.dart';

class EntryCard extends StatelessWidget {
  final SignedEntryModel entry;
  final VoidCallback? onTap;

  const EntryCard({super.key, required this.entry, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isCredit = entry.type == EntryType.credit;
    final amountColor =
        isCredit ? const Color(0xFFD7263D) : const Color(0xFF2ECC71);
    final amountPrefix = isCredit ? '- ' : '+ ';
    final dateStr =
        DateFormat('dd MMM, hh:mm a').format(entry.dateTime);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: amountColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        entry.customerName.isNotEmpty
                            ? entry.customerName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                            color: amountColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.customerName,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          entry.description,
                          style:
                              Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$amountPrefix${entry.currency} ${entry.amount.toStringAsFixed(0)}',
                        style: TextStyle(
                            color: amountColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(dateStr,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontSize: 10)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  HashBadge(hash: entry.entryHash),
                  const SizedBox(width: 6),
                  if (entry.isDualSigned)
                    const IntegrityChip(
                      status: IntegrityStatus.verified,
                      label: 'Dual signed',
                      compact: true,
                    )
                  else
                    const IntegrityChip(
                      status: IntegrityStatus.pending,
                      label: 'Merchant only',
                      compact: true,
                    ),
                  const SizedBox(width: 6),
                  if (entry.isAnchored)
                    const IntegrityChip(
                      status: IntegrityStatus.anchored,
                      compact: true,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}