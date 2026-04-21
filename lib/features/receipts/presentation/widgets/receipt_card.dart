import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/models/receipt_model.dart';

class ReceiptCard extends StatelessWidget {
  final ReceiptModel receipt;
  final String? currentUserId;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onAddWarranty;
  final VoidCallback? onComplaint;

  const ReceiptCard({
    super.key,
    required this.receipt,
    this.currentUserId,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onAddWarranty,
    this.onComplaint,
  });

  bool get _isFamilyShared =>
      receipt.sharedWithFamily &&
      currentUserId != null &&
      receipt.userId != currentUserId;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image or KSeF placeholder
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  children: [
                    SizedBox(
                      height: 180,
                      width: double.infinity,
                      child: receipt.isKsefInvoice &&
                              (receipt.imageUrl.isEmpty)
                          ? _KsefPlaceholder()
                          : CachedNetworkImage(
                              imageUrl: receipt.imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                color: Theme.of(context).colorScheme.surface,
                                child: const Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: Theme.of(context).colorScheme.surface,
                                child: const Icon(Icons.receipt_long,
                                    size: 48, color: Colors.grey),
                              ),
                            ),
                    ),
                    // Badges row (top right)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (receipt.isKsefInvoice)
                            _Badge(
                              icon: Icons.description_rounded,
                              label: 'FAKTURA',
                              color: AppColors.lightPrimary,
                            ),
                          if (receipt.isKsefInvoice && receipt.aiProcessed)
                            const SizedBox(width: 4),
                          if (receipt.aiProcessed)
                            _Badge(
                              icon: Icons.auto_awesome,
                              label: 'AI',
                              color: AppColors.lightPrimary,
                            ),
                          if (_isFamilyShared) ...[
                            const SizedBox(width: 4),
                            _Badge(
                              icon: Icons.family_restroom_rounded,
                              label: 'Rodzinne',
                              color: Colors.blue,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Merchant & date
              Text(
                receipt.merchantName ?? 'Nieznany sklep',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (receipt.purchaseDate != null)
                Text(
                  Formatters.formatDate(receipt.purchaseDate),
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                ),
              const SizedBox(height: 6),
              // Amount
              Text(
                Formatters.formatCurrency(receipt.amount),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              // KSeF details
              if (receipt.isKsefInvoice) ...[
                const SizedBox(height: 6),
                if (receipt.sellerNip != null)
                  Row(
                    children: [
                      Icon(Icons.badge_outlined,
                          size: 14,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5)),
                      const SizedBox(width: 4),
                      Text(
                        'NIP: ${receipt.sellerNip}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                if (receipt.ksefNumber != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    receipt.ksefNumber!,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
              const SizedBox(height: 8),
              // Category chip
              if (receipt.category != null)
                Chip(
                  label: Text(
                    receipt.category!,
                    style: const TextStyle(fontSize: 12),
                  ),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              const SizedBox(height: 8),
              // Action buttons
              Row(
                children: [
                  if (onEdit != null)
                    IconButton(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      tooltip: 'Edytuj',
                      visualDensity: VisualDensity.compact,
                    ),
                  if (onAddWarranty != null)
                    TextButton.icon(
                      onPressed: onAddWarranty,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Gwarancja',
                          style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  if (onComplaint != null)
                    IconButton(
                      onPressed: onComplaint,
                      icon:
                          const Icon(Icons.description_outlined, size: 20),
                      tooltip: 'Reklamacja',
                      visualDensity: VisualDensity.compact,
                    ),
                  const Spacer(),
                  if (onDelete != null)
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outlined, size: 20),
                      color: AppColors.lightDestructive,
                      tooltip: 'Usuń',
                      visualDensity: VisualDensity.compact,
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

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Badge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _KsefPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              'Faktura KSeF',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            Text(
              'Kliknij, aby pobrać PDF',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
