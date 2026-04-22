import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/polish_plurals.dart';
import '../../data/store_logo_service.dart';

class StoreTile extends StatelessWidget {
  final String storeName;
  final int receiptCount;
  final double totalSpent;
  final VoidCallback? onTap;

  const StoreTile({
    super.key,
    required this.storeName,
    required this.receiptCount,
    required this.totalSpent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final faviconUrl = StoreLogoService.getFaviconUrl(storeName);
    final initials = StoreLogoService.getInitials(storeName);
    final color = StoreLogoService.getColor(storeName);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo or initials
              _StoreLogo(
                faviconUrl: faviconUrl,
                initials: initials,
                color: color,
              ),
              const SizedBox(height: 10),
              // Name
              Text(
                storeName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              // Receipt count badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  PolishPlurals.receipts(receiptCount),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const Spacer(),
              // Total spent
              Text(
                Formatters.formatCurrency(totalSpent),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreLogo extends StatelessWidget {
  final String? faviconUrl;
  final String initials;
  final Color color;

  const _StoreLogo({
    required this.faviconUrl,
    required this.initials,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (faviconUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: faviconUrl!,
          width: 40,
          height: 40,
          fit: BoxFit.contain,
          errorWidget: (_, __, ___) => _InitialsAvatar(
            initials: initials,
            color: color,
          ),
        ),
      );
    }
    return _InitialsAvatar(initials: initials, color: color);
  }
}

class _InitialsAvatar extends StatelessWidget {
  final String initials;
  final Color color;

  const _InitialsAvatar({required this.initials, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
