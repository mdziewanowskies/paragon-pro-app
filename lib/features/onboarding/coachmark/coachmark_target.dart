import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'coachmark_controller.dart';

/// Wrapper rejestrujący GlobalKey przy `CoachmarkController` żeby
/// overlay mógł obliczyć Rect targetu w runtime.
///
/// Brak żadnej zmiany wizualnej — pełna transparencja gdy tutorial
/// nieaktywny. Można zostawić w drzewie permanentnie.
class CoachmarkTarget extends ConsumerStatefulWidget {
  final String stepId;
  final Widget child;

  /// Padding wokół targetu w spotlight'cie. Domyślnie 6 px — daje
  /// odddech wokół ikonek, FAB-ów i chipsów.
  final double padding;

  /// Promień rogów spotlight'u. Null = okrąg (dla zaokrąglonych ikon
  /// i FAB-ów); konkretna wartość dla prostokątnych elementów.
  final BorderRadius? borderRadius;

  const CoachmarkTarget({
    super.key,
    required this.stepId,
    required this.child,
    this.padding = 6,
    this.borderRadius,
  });

  @override
  ConsumerState<CoachmarkTarget> createState() => _CoachmarkTargetState();
}

class _CoachmarkTargetState extends ConsumerState<CoachmarkTarget> {
  final GlobalKey _key = GlobalKey();
  CoachmarkController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cache'ujemy notifier — `ref` jest niedostępny w dispose(),
    // a tutaj możemy je bezpiecznie odczytać przy każdym
    // remount/parent change.
    _controller = ref.read(coachmarkControllerProvider.notifier);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(coachmarkControllerProvider.notifier)
          .register(widget.stepId, _key);
    });
  }

  @override
  void dispose() {
    _controller?.unregister(widget.stepId, _key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _key, child: widget.child);
  }
}

extension CoachmarkTargetGeometry on GlobalKey {
  /// Liczy rectangle w globalnych koordynatach. Zwraca null jeśli
  /// widget jeszcze nie zlayoutowany.
  Rect? globalRect() {
    final ctx = currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final offset = box.localToGlobal(Offset.zero);
    return offset & box.size;
  }
}
