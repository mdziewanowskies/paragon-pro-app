import 'package:flutter/material.dart';

/// Empty state z pulsującą ikoną, tytułem, opcjonalnym subtitle + hint
/// + CTA. Audyt: "ilustracja zwiniętej tarczy + tekst 'Tu pojawią się
/// Twoje gwarancje — żadnej nie zapomnisz'. Lekki, miękki,
/// gimme-a-reason-to-come-back". Ilustracje custom Lottie nadal TODO —
/// na razie używamy Material ikony w kolorowym kółku.
class EmptyState extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? hint;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Opcjonalny kolor akcentu (tło kółka + ikona + hint). Pozwala
  /// ekranom mieć semantyczny ton (gwarancje = warning, KSeF = aqua,
  /// achievements = gold). Null = primary z theme'u.
  final Color? accentColor;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.hint,
    this.actionLabel,
    this.onAction,
    this.accentColor,
  });

  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  late final Animation<double> _scale = Tween<double>(
    begin: 0.96,
    end: 1.04,
  ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent =
        widget.accentColor ?? Theme.of(context).colorScheme.primary;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scale,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accent.withValues(alpha: 0.28),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  widget.icon,
                  size: 44,
                  color: accent,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              textAlign: TextAlign.center,
            ),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                textAlign: TextAlign.center,
              ),
            ],
            if (widget.hint != null) ...[
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lightbulb_outline_rounded,
                        size: 16, color: accent),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.hint!,
                        style: TextStyle(
                          fontSize: 12,
                          color: accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (widget.onAction != null && widget.actionLabel != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: widget.onAction,
                child: Text(widget.actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
