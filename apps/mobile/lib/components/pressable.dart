import 'package:flutter/widgets.dart';

import '../core/theme/app_tokens.dart';

/// Umpan balik tekan dari DESIGN.md bagian 4: skala 0,97 selama 150 ms.
/// [builder] menerima status `pressed` supaya pemanggil bisa menggelapkan
/// warna satu tingkat.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.builder,
    this.onTap,
    this.semanticLabel,
    this.isButton = true,
  });

  final Widget Function(BuildContext context, bool pressed) builder;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final bool isButton;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: widget.isButton,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: enabled ? () => _set(false) : null,
        child: AnimatedScale(
          scale: _pressed ? AppSizes.pressScale : 1,
          duration: AppSizes.pressDuration,
          curve: Curves.easeOut,
          child: widget.builder(context, _pressed),
        ),
      ),
    );
  }
}
