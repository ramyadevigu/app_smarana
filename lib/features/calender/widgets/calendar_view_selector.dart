import 'package:flutter/material.dart';

import '../models/calendar_view_mode.dart';

extension CalendarViewModePresentation on CalendarViewMode {
  String get label => switch (this) {
    CalendarViewMode.list => 'List',
    CalendarViewMode.year => 'Year',
    CalendarViewMode.month => 'Month',
    CalendarViewMode.week => 'Week',
    CalendarViewMode.threeDay => '3 Day',
    CalendarViewMode.day => 'Day',
  };
}

class CalendarViewIcon extends StatelessWidget {
  const CalendarViewIcon({
    required this.mode,
    this.size = 24,
    this.color,
    super.key,
  });

  final CalendarViewMode mode;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (mode == CalendarViewMode.threeDay) {
      return CustomPaint(
        size: Size.square(size),
        painter: _ThreeDayIconPainter(
          color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }

    final icon = switch (mode) {
      CalendarViewMode.list => Icons.view_list_outlined,
      CalendarViewMode.year => Icons.calendar_view_month_outlined,
      CalendarViewMode.month => Icons.calendar_month_outlined,
      CalendarViewMode.week => Icons.view_week_outlined,
      CalendarViewMode.threeDay => Icons.view_week_outlined,
      CalendarViewMode.day => Icons.view_day_outlined,
    };
    return Icon(icon, size: size, color: color);
  }
}

class _ThreeDayIconPainter extends CustomPainter {
  const _ThreeDayIconPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final bounds = Rect.fromLTWH(
      size.width * 0.12,
      size.height * 0.17,
      size.width * 0.76,
      size.height * 0.68,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds, const Radius.circular(2)),
      paint,
    );
    for (var column = 1; column < 3; column++) {
      final x = bounds.left + bounds.width * column / 3;
      canvas.drawLine(Offset(x, bounds.top), Offset(x, bounds.bottom), paint);
    }
    canvas.drawLine(
      Offset(bounds.left, bounds.top + bounds.height * 0.28),
      Offset(bounds.right, bounds.top + bounds.height * 0.28),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ThreeDayIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

class CalendarViewSelector extends StatelessWidget {
  const CalendarViewSelector({
    required this.selectedMode,
    required this.onSelected,
    super.key,
  });

  final CalendarViewMode selectedMode;
  final ValueChanged<CalendarViewMode> onSelected;

  static const modes = CalendarViewMode.values;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopupMenuButton<CalendarViewMode>(
      key: const ValueKey('calendar-view-selector'),
      tooltip: 'Calendar view: ${selectedMode.label}',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 6),
      onSelected: onSelected,
      color: colors.surfaceContainerHigh,
      elevation: 8,
      menuPadding: const EdgeInsets.symmetric(vertical: 6),
      constraints: const BoxConstraints(minWidth: 188, maxWidth: 220),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: CalendarViewIcon(mode: selectedMode),
      itemBuilder: (context) => [
        for (final mode in modes)
          PopupMenuItem<CalendarViewMode>(
            value: mode,
            height: 48,
            padding: EdgeInsets.zero,
            child: _buildMenuItem(context, mode),
          ),
      ],
    );
  }

  Widget _buildMenuItem(BuildContext context, CalendarViewMode mode) {
    final colors = Theme.of(context).colorScheme;
    final selected = mode == selectedMode;
    final foreground = selected ? colors.primary : colors.onSurfaceVariant;
    return Semantics(
      key: ValueKey('calendar-view-option-${mode.name}'),
      button: true,
      selected: selected,
      label: 'Calendar view: ${mode.label}${selected ? ', selected' : ''}',
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected
              ? colors.primaryContainer.withValues(alpha: 0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            CalendarViewIcon(mode: mode, size: 20, color: foreground),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                mode.label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: selected ? colors.primary : colors.onSurface,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (selected) Icon(Icons.check, size: 18, color: colors.primary),
          ],
        ),
      ),
    );
  }
}
