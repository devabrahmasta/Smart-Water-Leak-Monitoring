import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_tokens.dart';

enum ToastType { success, error }

/// Figma: Components / Toast. Pil `ink` melayang, ikon + satu baris teks.
class AppToast extends StatelessWidget {
  const AppToast({super.key, required this.type, required this.message});

  final ToastType type;
  final String message;

  @override
  Widget build(BuildContext context) {
    final success = type == ToastType.success;
    // Toast tampil di Overlay, di luar Scaffold/Material. Tanpa Material,
    // Text memakai gaya default debug (garis bawah kuning ganda).
    return Material(
      type: MaterialType.transparency,
      child: Semantics(
        liveRegion: true,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          decoration: const BoxDecoration(
            color: AppColors.ink,
            borderRadius: AppRadius.pillAll,
            boxShadow: AppShadows.float,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                success ? AppIcons.success : AppIcons.close,
                size: 18,
                color: success ? AppColors.primary : AppColors.danger,
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label.copyWith(color: AppColors.onDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

OverlayEntry? _current;

/// Tampilkan [AppToast] di atas Bottom Nav selama [duration].
/// Toast baru menggantikan toast yang masih tampil.
void showToast(
  BuildContext context, {
  required ToastType type,
  required String message,
  Duration duration = const Duration(seconds: 3),
}) {
  _current?.remove();
  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => Positioned(
      left: AppSpacing.gutter,
      right: AppSpacing.gutter,
      // Di atas nav melayang (68 + jarak bawah 24 + jarak 24).
      bottom: MediaQuery.paddingOf(context).bottom + 116,
      child: IgnorePointer(
        child: Center(
          child: AppToast(type: type, message: message),
        ),
      ),
    ),
  );
  _current = entry;
  overlay.insert(entry);
  Timer(duration, () {
    if (_current == entry) _current = null;
    if (entry.mounted) entry.remove();
  });
}
