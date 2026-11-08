import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../components/components.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/models/models.dart';

/// Isian jam, menit, detik menjadi total detik. Null bila bukan angka atau di
/// luar batas kontrak (1 detik sampai 24 jam).
int? parseDurationFields(String hour, String minute, String second) {
  final h = int.tryParse(hour.trim().isEmpty ? '0' : hour.trim());
  final m = int.tryParse(minute.trim().isEmpty ? '0' : minute.trim());
  final s = int.tryParse(second.trim().isEmpty ? '0' : second.trim());
  if (h == null || m == null || s == null) return null;
  if (m > 59 || s > 59) return null;
  final total = h * 3600 + m * 60 + s;
  if (total < RoomRules.minSec || total > RoomRules.maxSec) return null;
  return total;
}

/// Isian jam dan menit menjadi `HH:MM`. Null bila di luar 00:00 sampai 23:59.
String? parseClockFields(String hour, String minute) {
  final h = int.tryParse(hour.trim());
  final m = int.tryParse(minute.trim().isEmpty ? '0' : minute.trim());
  if (h == null || m == null || h > 23 || m > 59) return null;
  return '${_two(h)}:${_two(m)}';
}

String _two(int value) => value.toString().padLeft(2, '0');

/// Sheet ubah satu durasi: Jam : Menit : Detik. Hasilnya detik, null bila batal.
Future<int?> showDurationSheet(
  BuildContext context, {
  required String title,
  required String message,
  required int seconds,
}) => _showSheet<int>(context, _DurationSheet(title, message, seconds));

/// Sheet ubah rentang jam sepi. Hasilnya (mulai, selesai), null bila batal.
Future<(String, String)?> showQuietRangeSheet(
  BuildContext context, {
  required String start,
  required String end,
}) => _showSheet<(String, String)>(context, _QuietRangeSheet(start, end));

Future<T?> _showSheet<T>(BuildContext context, Widget sheet) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: AppColors.ink.withValues(alpha: 0.4),
    builder: (context) => sheet,
  );
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({
    required this.title,
    required this.message,
    required this.error,
    required this.onSave,
    required this.children,
  });

  final String title;
  final String message;
  final String? error;
  final VoidCallback onSave;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.xxl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: const BoxDecoration(
            color: AppColors.bg,
            borderRadius: AppRadius.cardAll,
            boxShadow: AppShadows.float,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(title, style: AppTextStyles.headline),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                style: AppTextStyles.body.copyWith(color: AppColors.inkMuted),
              ),
              const SizedBox(height: AppSpacing.lg),
              ...children,
              if (error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  error!,
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.dangerText,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Batal',
                      style: AppButtonStyle.secondary,
                      expand: true,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppButton(
                      label: 'Simpan',
                      expand: true,
                      onPressed: onSave,
                    ),
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

/// Kotak angka dua digit dengan label di bawahnya. Saat aktif kotak berubah
/// `primary-soft`, tanpa border. Diketuk langsung memilih seluruh isinya.
class _TimeBox extends StatelessWidget {
  const _TimeBox({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: AppTextStyles.title.copyWith(color: AppColors.ink),
          cursorColor: AppColors.primary,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(2),
          ],
          onTap: () => controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: controller.text.length,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: WidgetStateColor.resolveWith(
              (states) => states.contains(WidgetState.focused)
                  ? AppColors.primarySoft
                  : AppColors.surface,
            ),
            border: const OutlineInputBorder(
              borderRadius: AppRadius.cardAll,
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted),
        ),
      ],
    );
  }
}

class _Colon extends StatelessWidget {
  const _Colon();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.sm,
      AppSpacing.lg,
      AppSpacing.sm,
      0,
    ),
    child: Text(':', style: AppTextStyles.title),
  );
}

class _DurationSheet extends StatefulWidget {
  const _DurationSheet(this.title, this.message, this.seconds);

  final String title;
  final String message;
  final int seconds;

  @override
  State<_DurationSheet> createState() => _DurationSheetState();
}

class _DurationSheetState extends State<_DurationSheet> {
  late final _hour = TextEditingController(text: _two(widget.seconds ~/ 3600));
  late final _minute = TextEditingController(
    text: _two(widget.seconds % 3600 ~/ 60),
  );
  late final _second = TextEditingController(text: _two(widget.seconds % 60));
  String? _error;

  @override
  void dispose() {
    _hour.dispose();
    _minute.dispose();
    _second.dispose();
    super.dispose();
  }

  void _save() {
    final total = parseDurationFields(_hour.text, _minute.text, _second.text);
    if (total == null) {
      setState(() => _error = 'Isi antara 1 detik dan 24 jam');
      return;
    }
    Navigator.of(context).pop(total);
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: widget.title,
      message: widget.message,
      error: _error,
      onSave: _save,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _TimeBox(controller: _hour, label: 'Jam'),
            ),
            const _Colon(),
            Expanded(
              child: _TimeBox(controller: _minute, label: 'Menit'),
            ),
            const _Colon(),
            Expanded(
              child: _TimeBox(controller: _second, label: 'Detik'),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuietRangeSheet extends StatefulWidget {
  const _QuietRangeSheet(this.start, this.end);

  final String start;
  final String end;

  @override
  State<_QuietRangeSheet> createState() => _QuietRangeSheetState();
}

class _QuietRangeSheetState extends State<_QuietRangeSheet> {
  late final _startHour = TextEditingController(
    text: widget.start.split(':')[0],
  );
  late final _startMinute = TextEditingController(
    text: widget.start.split(':')[1],
  );
  late final _endHour = TextEditingController(text: widget.end.split(':')[0]);
  late final _endMinute = TextEditingController(text: widget.end.split(':')[1]);
  String? _error;

  @override
  void dispose() {
    _startHour.dispose();
    _startMinute.dispose();
    _endHour.dispose();
    _endMinute.dispose();
    super.dispose();
  }

  void _save() {
    final start = parseClockFields(_startHour.text, _startMinute.text);
    final end = parseClockFields(_endHour.text, _endMinute.text);
    if (start == null || end == null) {
      setState(() => _error = 'Isi jam 00 sampai 23 dan menit 00 sampai 59');
      return;
    }
    if (start == end) {
      setState(() => _error = 'Jam mulai dan selesai tidak boleh sama');
      return;
    }
    Navigator.of(context).pop((start, end));
  }

  Widget _clock(
    String label,
    TextEditingController hour,
    TextEditingController minute,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppTextStyles.label),
      const SizedBox(height: AppSpacing.xs),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _TimeBox(controller: hour, label: 'Jam'),
          ),
          const _Colon(),
          Expanded(
            child: _TimeBox(controller: minute, label: 'Menit'),
          ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: 'Jam sepi',
      message:
          'Waktu WIB saat aliran air diawasi lebih ketat. Boleh melewati '
          'tengah malam, misalnya 22.00 sampai 05.00.',
      error: _error,
      onSave: _save,
      children: [
        _clock('Mulai', _startHour, _startMinute),
        const SizedBox(height: AppSpacing.md),
        _clock('Selesai', _endHour, _endMinute),
      ],
    );
  }
}
