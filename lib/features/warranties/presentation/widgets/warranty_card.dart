import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../screens/warranty_list_screen.dart';

class WarrantyCard extends StatelessWidget {
  final WarrantyModel warranty;
  final VoidCallback? onDelete;
  final VoidCallback? onTestEmail;

  const WarrantyCard({
    super.key,
    required this.warranty,
    this.onDelete,
    this.onTestEmail,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = warranty.isExpiringSoon
        ? Colors.orange
        : warranty.isActive
            ? AppColors.lightPrimary
            : AppColors.lightDestructive;

    final statusText = warranty.isExpiringSoon
        ? 'Wygasa wkrótce'
        : warranty.isActive
            ? 'Aktywna'
            : 'Wygasła';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield_rounded, color: statusColor, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        warranty.merchantName ?? 'Gwarancja',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (warranty.amount != null)
                        Text(
                          Formatters.formatCurrency(warranty.amount),
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _InfoChip(
                  icon: Icons.calendar_today_rounded,
                  label:
                      'Od: ${Formatters.formatDate(warranty.startDate)}',
                ),
                const SizedBox(width: 12),
                _InfoChip(
                  icon: Icons.event_rounded,
                  label: 'Do: ${Formatters.formatDate(warranty.endDate)}',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              Formatters.daysUntil(warranty.endDate),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
            if (warranty.notes != null && warranty.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                warranty.notes!,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onTestEmail != null)
                  TextButton.icon(
                    onPressed: onTestEmail,
                    icon: const Icon(Icons.email_outlined, size: 16),
                    label: const Text('Test email',
                        style: TextStyle(fontSize: 12)),
                  ),
                if (onDelete != null)
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outlined,
                        size: 20, color: AppColors.lightDestructive),
                    tooltip: 'Usuń',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
