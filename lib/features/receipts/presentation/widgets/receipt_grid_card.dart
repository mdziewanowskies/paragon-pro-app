import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/receipt_image.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/models/receipt_model.dart';

class ReceiptGridCard extends StatelessWidget {
  final ReceiptModel receipt;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ReceiptGridCard({
    super.key,
    required this.receipt,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image / placeholder
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  !receipt.hasValidImageUrl
                      ? Container(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.1),
                          child: Center(
                            child: Icon(
                              receipt.isKsefInvoice
                                  ? Icons.description_rounded
                                  : Icons.receipt_long_rounded,
                              size: 36,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        )
                      : Hero(
                          tag: 'receipt-image-${receipt.id}',
                          child: ReceiptImage(
                            imageUrl: receipt.imageUrl,
                            fit: BoxFit.cover,
                          ),
                        ),
                  // Badges
                  if (receipt.isKsefInvoice || receipt.aiProcessed)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.lightPrimary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              receipt.isKsefInvoice
                                  ? Icons.description_rounded
                                  : Icons.auto_awesome,
                              color: Colors.white,
                              size: 10,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              receipt.isKsefInvoice ? 'KSeF' : 'AI',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      receipt.merchantName ?? 'Nieznany',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (receipt.purchaseDate != null)
                      Text(
                        Formatters.formatDate(receipt.purchaseDate),
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    const Spacer(),
                    Text(
                      Formatters.formatCurrency(receipt.amount),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
