import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';

enum ValveSwitchState {
  /// Valve terbuka.
  on,

  /// Valve tertutup.
  off,

  /// Menunggu ACK perangkat (US-07). Tidak bisa disentuh.
  pending,

  /// Perangkat offline atau server tidak terjangkau.
  disabled,
}

/// Figma: Components / Valve Switch. 52 x 32.
/// Tone gelap dipakai di dalam Room Card berstatus Valve tertutup.
class ValveSwitch extends StatelessWidget {
  const ValveSwitch({
    super.key,
    required this.state,
    this.onChanged,
    this.dark = false,
    this.semanticLabel = 'Valve',
  });

  final ValveSwitchState state;

  /// Dipanggil dengan nilai yang diminta (true = buka). Tidak dipanggil saat
  /// pending atau disabled.
  final ValueChanged<bool>? onChanged;
  final bool dark;
  final String semanticLabel;

  static const double width = 52;
  static const double height = 32;
  static const double _knob = 24;
  static const double _inset = 4;

  bool get _interactive =>
      onChanged != null &&
      (state == ValveSwitchState.on || state == ValveSwitchState.off);

  @override
  Widget build(BuildContext context) {
    final (track, knob, align) = switch (state) {
      ValveSwitchState.on => (
        AppColors.primary,
        AppColors.onPrimary,
        Alignment.centerRight,
      ),
      ValveSwitchState.off => (
        dark ? AppColors.onDark.withValues(alpha: 0.24) : AppColors.inkSubtle,
        AppColors.onPrimary,
        Alignment.centerLeft,
      ),
      ValveSwitchState.pending => (
        AppColors.primarySoft,
        AppColors.onPrimary,
        Alignment.center,
      ),
      ValveSwitchState.disabled => (
        dark ? AppColors.onDark.withValues(alpha: 0.12) : AppColors.surface,
        dark
            ? AppColors.onDark.withValues(alpha: 0.24)
            : AppColors.surfaceStrong,
        Alignment.centerLeft,
      ),
    };

    final semanticValue = switch (state) {
      ValveSwitchState.on => 'terbuka',
      ValveSwitchState.off => 'tertutup',
      ValveSwitchState.pending => 'menunggu perangkat',
      ValveSwitchState.disabled => 'tidak tersedia',
    };

    return Semantics(
      toggled: state == ValveSwitchState.on,
      enabled: _interactive,
      label: semanticLabel,
      value: semanticValue,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _interactive
            ? () => onChanged!(state != ValveSwitchState.on)
            : null,
        // Target sentuh minimal 44 di sekitar saklar 52 x 32.
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: AnimatedContainer(
            duration: AppSizes.pressDuration,
            curve: Curves.easeOut,
            width: width,
            height: height,
            padding: const EdgeInsets.all(_inset),
            decoration: BoxDecoration(
              color: track,
              borderRadius: AppRadius.pillAll,
            ),
            child: AnimatedAlign(
              duration: AppSizes.pressDuration,
              curve: Curves.easeOut,
              alignment: align,
              child: Container(
                width: _knob,
                height: _knob,
                decoration: BoxDecoration(color: knob, shape: BoxShape.circle),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
