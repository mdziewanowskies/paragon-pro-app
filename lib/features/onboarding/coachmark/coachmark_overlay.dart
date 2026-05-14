import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import 'coachmark_controller.dart';
import 'coachmark_target.dart';

/// V3 Sprint 1 — Pełnoekranowy overlay tutorialu.
/// Spotlight wyciętą maską ciemnego backdropu + glow + karta z opisem.
class CoachmarkOverlay extends ConsumerStatefulWidget {
  const CoachmarkOverlay({super.key});

  @override
  ConsumerState<CoachmarkOverlay> createState() => _CoachmarkOverlayState();
}

class _CoachmarkOverlayState extends ConsumerState<CoachmarkOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _enter;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _enter.dispose();
    super.dispose();
  }

  void _retriggerEnter() {
    _enter
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(coachmarkControllerProvider);
    final ctrl = ref.read(coachmarkControllerProvider.notifier);
    if (!state.active) return const SizedBox.shrink();

    final step = ctrl.currentStep;
    final isLast = state.index == CoachmarkController.steps.length - 1;
    final isFirst = state.index == 0;

    return Positioned.fill(
      child: _StepContent(
        key: ValueKey(step.id),
        step: step,
        isFirst: isFirst,
        isLast: isLast,
        stepIndex: state.index,
        totalSteps: CoachmarkController.steps.length,
        pulse: _pulse,
        enter: _enter,
        onNext: () {
          ctrl.next();
          _retriggerEnter();
        },
        onSkip: ctrl.skip,
      ),
    );
  }
}

class _StepContent extends StatelessWidget {
  final CoachmarkStep step;
  final bool isFirst;
  final bool isLast;
  final int stepIndex;
  final int totalSteps;
  final Animation<double> pulse;
  final Animation<double> enter;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _StepContent({
    super.key,
    required this.step,
    required this.isFirst,
    required this.isLast,
    required this.stepIndex,
    required this.totalSteps,
    required this.pulse,
    required this.enter,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (step.isIntro) {
          return _IntroFullScreen(
            step: step,
            enter: enter,
            isLast: isLast,
            stepIndex: stepIndex,
            totalSteps: totalSteps,
            onNext: onNext,
            onSkip: onSkip,
          );
        }
        return _SpotlightLayout(
          step: step,
          stepIndex: stepIndex,
          totalSteps: totalSteps,
          pulse: pulse,
          enter: enter,
          onNext: onNext,
          onSkip: onSkip,
        );
      },
    );
  }
}

class _SpotlightLayout extends ConsumerStatefulWidget {
  final CoachmarkStep step;
  final int stepIndex;
  final int totalSteps;
  final Animation<double> pulse;
  final Animation<double> enter;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _SpotlightLayout({
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.pulse,
    required this.enter,
    required this.onNext,
    required this.onSkip,
  });

  @override
  ConsumerState<_SpotlightLayout> createState() => _SpotlightLayoutState();
}

class _SpotlightLayoutState extends ConsumerState<_SpotlightLayout> {
  int _retries = 0;

  void _scheduleRetry() {
    if (_retries > 6) return;
    _retries++;
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = ref.watch(coachmarkControllerProvider.notifier);
    final key = ctrl.keyFor(widget.step.id);
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;

    final rect = key?.globalRect();
    final hasTarget = rect != null;
    if (!hasTarget) _scheduleRetry();

    final inflated = hasTarget
        ? rect.inflate(8)
        : Rect.fromCenter(
            center: Offset(size.width / 2, size.height / 2),
            width: 0,
            height: 0,
          );

    final showOnTop = hasTarget && (inflated.center.dy > size.height * 0.5);
    final cardTop = showOnTop
        ? padding.top + 16
        : inflated.bottom + 24;
    final cardBottom = showOnTop
        ? (size.height - inflated.top + 24)
        : padding.bottom + 24;

    return Stack(
      children: [
        // Backdrop z wyciętym spotlight'em
        AnimatedBuilder(
          animation: Listenable.merge([widget.pulse, widget.enter]),
          builder: (_, __) => CustomPaint(
            size: Size.infinite,
            painter: _SpotlightPainter(
              rect: inflated,
              pulse: widget.pulse.value,
              enter: widget.enter.value,
            ),
          ),
        ),
        // Tap przez backdrop — nie pozwalamy klikać UI pod spodem
        // (zapobiega "klikania w spotlight" co byłoby mylące).
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onNext,
            child: const SizedBox.expand(),
          ),
        ),
        // Karta opisu
        Positioned(
          left: 16,
          right: 16,
          top: showOnTop ? cardTop : null,
          bottom: showOnTop ? null : cardBottom,
          child: FadeTransition(
            opacity: widget.enter,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset(0, showOnTop ? -0.15 : 0.15),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: widget.enter,
                curve: Curves.easeOutCubic,
              )),
              child: _TooltipCard(
                step: widget.step,
                stepIndex: widget.stepIndex,
                totalSteps: widget.totalSteps,
                onNext: widget.onNext,
                onSkip: widget.onSkip,
                isLast: widget.stepIndex == widget.totalSteps - 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _IntroFullScreen extends StatelessWidget {
  final CoachmarkStep step;
  final Animation<double> enter;
  final bool isLast;
  final int stepIndex;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _IntroFullScreen({
    required this.step,
    required this.enter,
    required this.isLast,
    required this.stepIndex,
    required this.totalSteps,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Pełen backdrop z gradientem brand
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.surface0.withValues(alpha: 0.97),
                AppColors.primary500.withValues(alpha: 0.92),
              ],
            ),
          ),
        ),
        Positioned.fill(
          child: SafeArea(
            child: Center(
              child: FadeTransition(
                opacity: enter,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.92, end: 1).animate(
                    CurvedAnimation(
                      parent: enter,
                      curve: Curves.easeOutBack,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary400,
                                AppColors.accentAqua,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary400
                                    .withValues(alpha: 0.5),
                                blurRadius: 40,
                                spreadRadius: 6,
                              ),
                            ],
                          ),
                          child: Icon(
                            step.icon ?? Icons.auto_awesome_rounded,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          step.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          step.body,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white.withValues(alpha: 0.88),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: onNext,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.primary600,
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.full,
                                ),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            child: Text(isLast ? 'Rozpocznij' : 'Pokaż mi!'),
                          ),
                        ),
                        if (!isLast) ...[
                          const SizedBox(height: AppSpacing.sm),
                          TextButton(
                            onPressed: onSkip,
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  Colors.white.withValues(alpha: 0.7),
                            ),
                            child: const Text('Pomiń tutorial'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TooltipCard extends StatelessWidget {
  final CoachmarkStep step;
  final int stepIndex;
  final int totalSteps;
  final bool isLast;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _TooltipCard({
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.isLast,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: AppColors.primary400.withValues(alpha: 0.32),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary400.withValues(alpha: 0.18),
              blurRadius: 40,
              spreadRadius: 4,
            ),
            const BoxShadow(
              color: Colors.black54,
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary400,
                        AppColors.accentAqua,
                      ],
                    ),
                  ),
                  child: Icon(
                    step.icon ?? Icons.lightbulb_outline_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Krok ${stepIndex + 1} / $totalSteps',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        step.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              step.body,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _ProgressDots(current: stepIndex, total: totalSteps),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: onSkip,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textTertiary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Pomiń'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: onNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary500,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.full),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: Text(isLast ? 'Zakończ' : 'Dalej'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  final int current;
  final int total;
  const _ProgressDots({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary400
                : AppColors.textTertiary.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
        );
      }),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect rect;
  final double pulse;
  final double enter;

  _SpotlightPainter({
    required this.rect,
    required this.pulse,
    required this.enter,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Brak konkretnego targetu — tylko pełen backdrop bez wycięcia.
    if (rect.width < 4 || rect.height < 4) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.black.withValues(alpha: 0.78 * enter),
      );
      return;
    }
    final pulseScale = 1 + (pulse * 0.06);
    final inflated = Rect.fromCenter(
      center: rect.center,
      width: rect.width * pulseScale,
      height: rect.height * pulseScale,
    );
    final radius = inflated.shortestSide * 0.5;
    final isCircle = (rect.width - rect.height).abs() < 8;

    final cutoutPath = Path()..fillType = PathFillType.evenOdd;
    cutoutPath.addRect(Offset.zero & size);
    if (isCircle) {
      cutoutPath.addOval(inflated);
    } else {
      cutoutPath.addRRect(RRect.fromRectAndRadius(
        inflated,
        Radius.circular(radius.clamp(12, 24)),
      ));
    }

    canvas.drawPath(
      cutoutPath,
      Paint()..color = Colors.black.withValues(alpha: 0.78 * enter),
    );

    // Glow ring
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = AppColors.primary400.withValues(alpha: 0.9 * enter)
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 12);
    if (isCircle) {
      canvas.drawOval(inflated, ringPaint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          inflated,
          Radius.circular(radius.clamp(12, 24)),
        ),
        ringPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.rect != rect ||
      oldDelegate.pulse != pulse ||
      oldDelegate.enter != enter;
}
