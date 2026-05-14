import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../screens/warranty_list_screen.dart';

/// V3 karta gwarancji. Audyt: "karta gwarancji: ikona produktu w
/// outline+tinted circle, nazwa produktu jako tytuł (15/600), pod nim
/// sklep + data zakupu jako caption. Termin gwarancji jako mini timeline
/// 1-rok bar progress (od 'Od' do 'Do' z markerem 'Dziś')".
///
/// Jeśli `notes` zawiera nazwę produktu — używamy jej jako tytuł
/// (np. "Laptop Lenovo X1"), w przeciwnym razie fallback do nazwy sklepu.
class WarrantyCard extends StatelessWidget {
  final WarrantyModel warranty;
  final VoidCallback? onTap;

  const WarrantyCard({
    super.key,
    required this.warranty,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final accent = _accentColor();
    final productName = _productName();
    final hasProductName =
        warranty.notes != null && warranty.notes!.trim().isNotEmpty;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Ink(
          decoration: BoxDecoration(
            color: c.surface1,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: AppShadows.md,
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _ProductAvatar(accent: accent),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          productName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _captionLine(hasProductName),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: c.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _StatusPill(accent: accent, label: _statusLabel()),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _Timeline(
                start: warranty.startDate,
                end: warranty.endDate,
                accent: accent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _accentColor() {
    if (!warranty.isActive) return AppColors.danger500;
    if (warranty.isExpiringSoon) return AppColors.warning500;
    return AppColors.primary400;
  }

  String _statusLabel() {
    final days = warranty.endDate.difference(DateTime.now()).inDays;
    if (!warranty.isActive) {
      final daysAgo = DateTime.now().difference(warranty.endDate).inDays;
      if (daysAgo < 1) return 'Wygasła dziś';
      return 'Wygasła ${daysAgo}d temu';
    }
    if (days <= 0) return 'Wygasa dziś';
    if (days == 1) return 'Wygasa jutro';
    if (days <= 30) return 'Za $days dni';
    if (days < 60) return 'Za $days dni';
    final months = (days / 30).round();
    return 'Za $months mies.';
  }

  String _productName() {
    if (warranty.notes != null && warranty.notes!.trim().isNotEmpty) {
      // Pierwsze 60 znaków notatki — często to nazwa produktu
      // ("Laptop Lenovo X1 Carbon Gen 12") wpisana przez usera.
      var s = warranty.notes!.trim();
      if (s.length > 60) s = '${s.substring(0, 57)}…';
      return s;
    }
    return _formatMerchant(warranty.merchantName) ?? 'Gwarancja';
  }

  String _captionLine(bool hasProductName) {
    final parts = <String>[];
    if (hasProductName && warranty.merchantName != null) {
      parts.add(_formatMerchant(warranty.merchantName) ?? '');
    }
    parts.add('zakup ${Formatters.formatDate(warranty.startDate)}');
    return parts.where((p) => p.isNotEmpty).join(' · ');
  }

  String? _formatMerchant(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    var s = raw.trim();
    s = s.replaceAll(RegExp(r'\s+[A-Z]?\d{3,}\b'), '');
    s = s.replaceFirst(RegExp(r'^SKLEP\s+', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s
        .split(' ')
        .map((w) => w.isEmpty
            ? ''
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }
}

class _ProductAvatar extends StatelessWidget {
  final Color accent;
  const _ProductAvatar({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withValues(alpha: 0.16),
        border: Border.all(
          color: accent.withValues(alpha: 0.36),
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.shield_rounded, size: 22, color: accent),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final Color accent;
  final String label;
  const _StatusPill({required this.accent, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: accent,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Mini timeline bar (1-rok lub na pełen okres gwarancji) z markerem
/// "Dziś". Audyt: "termin gwarancji jako mini timeline 1-rok bar
/// progress — natychmiast widzisz, ile zostało".
class _Timeline extends StatelessWidget {
  final DateTime start;
  final DateTime end;
  final Color accent;
  const _Timeline({
    required this.start,
    required this.end,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final now = DateTime.now();
    final total = end.difference(start).inDays;
    final elapsed = now.difference(start).inDays.clamp(0, total);
    final progress = total > 0 ? elapsed / total : 1.0;
    final progressClamped = progress.clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        // Marker ma się mieścić w track'u — zostawiamy 10 px paddingu
        // po obu stronach żeby kropka nie była uciętą półokrężnicą.
        final markerX = (progressClamped * (w - 16)).clamp(0.0, w - 16);
        return SizedBox(
          height: 36,
          child: Stack(
            children: [
              // Track + filled portion
              Positioned(
                left: 0,
                right: 0,
                top: 12,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: c.surface2,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progressClamped,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accent.withValues(alpha: 0.5), accent],
                        ),
                        borderRadius:
                            BorderRadius.circular(AppRadius.full),
                      ),
                    ),
                  ),
                ),
              ),
              // Marker "Dziś"
              if (progressClamped < 1.0)
                Positioned(
                  left: markerX,
                  top: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c.surface0,
                          border: Border.all(color: accent, width: 3),
                          boxShadow: AppShadows.sm,
                        ),
                      ),
                    ],
                  ),
                ),
              // Labels: Od / Do
              Positioned(
                left: 0,
                bottom: 0,
                child: Text(
                  Formatters.formatDate(start),
                  style: TextStyle(
                    fontSize: 10,
                    color: c.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Text(
                  Formatters.formatDate(end),
                  style: TextStyle(
                    fontSize: 10,
                    color: c.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
