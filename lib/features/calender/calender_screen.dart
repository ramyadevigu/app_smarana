import 'package:flutter/material.dart';

import 'models/calendar_view_mode.dart';
import '../reminders/models/reminder.dart';
import '../reminders/screens/add_reminder_screen.dart';
import '../reminders/services/reminder_storage.dart';
import 'services/calendar_service.dart';
import 'theme/calendar_colors.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    this.storage,
    this.clock = DateTime.now,
    this.viewMode = CalendarViewMode.monthAndWeek,
    this.onViewModeChanged,
    this.appMenu,
  });

  final ReminderStorage? storage;
  final DateTime Function() clock;
  final CalendarViewMode viewMode;
  final ValueChanged<CalendarViewMode>? onViewModeChanged;
  final Widget? appMenu;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late final ReminderStorage _storage;
  final CalendarService _calendarService = CalendarService();

  late DateTime _selectedDate;
  late DateTime _displayedMonth;
  late CalendarViewMode _activeViewMode;
  List<Reminder> _reminders = [];
  Map<DateTime, List<CalendarOccurrence>> _occurrencesByDate = {};
  bool _isLoading = true;
  bool _hasLoadError = false;

  @override
  void initState() {
    super.initState();
    _storage = widget.storage ?? ReminderStorage();
    final today = _dateOnly(widget.clock());
    _activeViewMode = _normalizeViewMode(widget.viewMode);
    _selectedDate = today;
    _displayedMonth = DateTime(today.year, today.month);
    _loadReminders();
  }

  @override
  void didUpdateWidget(covariant CalendarScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewMode != widget.viewMode) {
      _activeViewMode = _normalizeViewMode(widget.viewMode);
    }
  }

  CalendarViewMode _normalizeViewMode(CalendarViewMode mode) => switch (mode) {
    CalendarViewMode.nextThreeDays => CalendarViewMode.nextThreeDays,
    CalendarViewMode.monthOnly ||
    CalendarViewMode.split => CalendarViewMode.monthOnly,
    _ => CalendarViewMode.monthAndWeek,
  };

  void _selectViewMode(CalendarViewMode mode) {
    if (_activeViewMode == mode) {
      return;
    }
    setState(() => _activeViewMode = mode);
    widget.onViewModeChanged?.call(mode);
  }

  Future<void> _loadReminders({bool showLoading = false}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _hasLoadError = false;
      });
    }

    try {
      final reminders = await _storage.getReminders();
      if (!mounted) {
        return;
      }
      setState(() {
        _reminders = reminders;
        _hasLoadError = false;
        _isLoading = false;
        _refreshVisibleOccurrences();
      });
    } on Exception {
      if (!mounted) {
        return;
      }
      setState(() {
        _hasLoadError = true;
        _isLoading = false;
      });
    }
  }

  void _refreshVisibleOccurrences() {
    final firstOfMonth = DateTime(_displayedMonth.year, _displayedMonth.month);
    final leadingDays = firstOfMonth.weekday - DateTime.monday;
    final firstGridDate = firstOfMonth.subtract(Duration(days: leadingDays));
    final monthEndExclusive = firstGridDate.add(
      Duration(days: _monthGridCellCount()),
    );
    final previewStart = _weekStart(_selectedDate)
        .subtract(const Duration(days: 7));
    final previewEndExclusive = previewStart.add(const Duration(days: 14));
    final start = previewStart.isBefore(firstGridDate)
        ? previewStart
        : firstGridDate;
    final endExclusive = previewEndExclusive.isAfter(monthEndExclusive)
        ? previewEndExclusive
        : monthEndExclusive;
    _occurrencesByDate = _calendarService.occurrencesBetween(
      _reminders,
      start: start,
      endExclusive: endExclusive,
    );
  }

  void _changeMonth(int offset) {
    final nextMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + offset,
    );
    final lastDay = DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
    setState(() {
      _displayedMonth = nextMonth;
      _selectedDate = DateTime(
        nextMonth.year,
        nextMonth.month,
        _selectedDate.day.clamp(1, lastDay),
      );
      _refreshVisibleOccurrences();
    });
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (date != null && mounted) {
      _selectDate(date);
    }
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = _dateOnly(date);
      if (_selectedDate.month != _displayedMonth.month ||
          _selectedDate.year != _displayedMonth.year) {
        _displayedMonth = DateTime(_selectedDate.year, _selectedDate.month);
      }
      _refreshVisibleOccurrences();
    });
  }

  void _returnToToday() {
    final today = _dateOnly(widget.clock());
    setState(() {
      _selectedDate = today;
      _displayedMonth = DateTime(today.year, today.month);
      _refreshVisibleOccurrences();
    });
  }

  Future<void> _openAddReminder() async {
    final reminder = await Navigator.of(context).push<Reminder>(
      MaterialPageRoute<Reminder>(
        builder: (_) =>
            AddReminderScreen(storage: _storage, initialDate: _selectedDate),
      ),
    );
    if (reminder != null && mounted) {
      await _loadReminders(showLoading: true);
    }
  }

  Future<void> _openEditReminder(Reminder reminder) async {
    final updatedReminder = await Navigator.of(context).push<Reminder>(
      MaterialPageRoute<Reminder>(
        builder: (_) =>
            AddReminderScreen(reminder: reminder, storage: _storage),
      ),
    );
    if (updatedReminder != null && mounted) {
      await _loadReminders(showLoading: true);
    }
  }

  Future<void> _deleteReminder(Reminder reminder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: const Text('Delete reminder?'),
        content: Text('Delete "${reminder.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await _storage.deleteReminder(reminder.id);
      if (mounted) {
        await _loadReminders(showLoading: true);
      }
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to delete the reminder.')),
        );
      }
    }
  }

  bool _isToday(DateTime date) => _sameDay(date, widget.clock());

  bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  DateTime _dateOnly(DateTime date) {
    final localDate = date.isUtc ? date.toLocal() : date;
    return DateTime(localDate.year, localDate.month, localDate.day);
  }

  List<CalendarOccurrence> _occurrencesFor(DateTime date) =>
      _occurrencesByDate[_dateOnly(date)] ?? const [];

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Go to today',
          onPressed: _returnToToday,
          icon: const Icon(Icons.calendar_month_outlined),
        ),
        titleSpacing: 0,
        title: TextButton(
          key: const ValueKey('calendar-select-date'),
          onPressed: _pickDate,
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurface,
          ),
          child: Text(
            localizations.formatMonthYear(_displayedMonth),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        actions: [
          PopupMenuButton<CalendarViewMode>(
            key: const ValueKey('calendar-view-selector'),
            tooltip: 'Calendar view',
            icon: const Icon(Icons.view_agenda_outlined),
            initialValue: _activeViewMode,
            onSelected: _selectViewMode,
            itemBuilder: (context) => [
              _viewMenuItem(CalendarViewMode.monthAndWeek, 'Month + Week'),
              _viewMenuItem(CalendarViewMode.nextThreeDays, 'Next 3 Days'),
              _viewMenuItem(CalendarViewMode.monthOnly, 'Month Only'),
            ],
          ),
          ?widget.appMenu,
        ],
      ),
      body: _buildBody(context),
      floatingActionButton: FloatingActionButton(
        heroTag: 'calendar-add-reminder',
        onPressed: _openAddReminder,
        tooltip: 'Add reminder for selected date',
        child: const Icon(Icons.add),
      ),
    );
  }

  PopupMenuItem<CalendarViewMode> _viewMenuItem(
    CalendarViewMode mode,
    String label,
  ) {
    final selected = _activeViewMode == mode;
    return PopupMenuItem<CalendarViewMode>(
      value: mode,
      child: Row(
        children: [
          Icon(selected ? Icons.check_circle : Icons.circle_outlined, size: 18),
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_hasLoadError) {
      final theme = Theme.of(context);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                color: theme.colorScheme.error,
                size: 44,
              ),
              const SizedBox(height: 12),
              Text(
                'Unable to load calendar reminders.',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _loadReminders(showLoading: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      key: ValueKey('calendar-view-${_activeViewMode.name}'),
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMonthNavigation(context),
          if (_activeViewMode == CalendarViewMode.monthOnly) ...[
            _buildWeekdayHeader(context),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _buildMonthGridCard(context, monthOnly: true),
              ),
            ),
          ] else if (_activeViewMode == CalendarViewMode.nextThreeDays) ...[
            _buildAgendaHeading(context),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _buildThreeDayAgenda(context),
              ),
            ),
          ] else ...[
            _buildWeekdayHeader(context, compact: true),
            SizedBox(
              height: 38,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _buildMonthGridCard(
                  context,
                  compact: true,
                  twoWeekPreview: true,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildAgendaHeading(context),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _buildWeekAgenda(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMonthNavigation(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('calendar-previous-month'),
            tooltip: 'Previous month',
            onPressed: () => _changeMonth(-1),
            icon: const Icon(Icons.chevron_left),
            visualDensity: VisualDensity.compact,
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _returnToToday,
            icon: const Icon(Icons.today_outlined, size: 18),
            label: const Text('Today'),
          ),
          const Spacer(),
          IconButton(
            key: const ValueKey('calendar-next-month'),
            tooltip: 'Next month',
            onPressed: () => _changeMonth(1),
            icon: const Icon(Icons.chevron_right),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayHeader(BuildContext context, {bool compact = false}) {
    final localizations = MaterialLocalizations.of(context);
    const mondayFirstIndexes = [1, 2, 3, 4, 5, 6, 0];
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    );
    return SizedBox(
      height: compact ? 18 : 28,
      child: Row(
        children: [
          for (var index = 0; index < mondayFirstIndexes.length; index++)
            Expanded(
              child: Center(
                child: Text(
                  localizations.narrowWeekdays[mondayFirstIndexes[index]],
                  style: style?.copyWith(
                    color: index > 4
                        ? Theme.of(context).colorScheme.tertiary
                        : style.color,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMonthGridCard(
    BuildContext context, {
    bool monthOnly = false,
    bool compact = false,
    bool twoWeekPreview = false,
  }) {
    return LayoutBuilder(
      key: ValueKey('calendar-month-grid-$monthOnly-$twoWeekPreview'),
      builder: (context, constraints) {
        final cellCount = twoWeekPreview ? 14 : _monthGridCellCount();
        final rowCount = cellCount ~/ 7;
        final cellExtent = constraints.maxHeight / rowCount;
        return GridView.builder(
          key: ValueKey(
            twoWeekPreview ? 'calendar-week-preview' : 'calendar-month-grid',
          ),
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cellCount,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: cellExtent,
          ),
          itemBuilder: (context, index) {
            final date =
                (twoWeekPreview
                        ? _weekStart(_selectedDate)
                              .subtract(const Duration(days: 7))
                        : _monthGridStartDate())
                    .add(Duration(days: index));
            return _buildDateCell(
              context,
              date,
              monthOnly: monthOnly,
              compact: compact,
            );
          },
        );
      },
    );
  }

  int _monthGridCellCount() {
    final firstOfMonth = DateTime(_displayedMonth.year, _displayedMonth.month);
    final leadingDays = firstOfMonth.weekday - DateTime.monday;
    final daysInMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + 1,
      0,
    ).day;
    return ((leadingDays + daysInMonth + 6) ~/ 7) * 7;
  }

  DateTime _monthGridStartDate() {
    final firstOfMonth = DateTime(_displayedMonth.year, _displayedMonth.month);
    return firstOfMonth.subtract(
      Duration(days: firstOfMonth.weekday - DateTime.monday),
    );
  }

  Widget _buildDateCell(
    BuildContext context,
    DateTime date, {
    required bool monthOnly,
    bool compact = false,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final occurrences = _occurrencesFor(date);
    final selected = _sameDay(date, _selectedDate);
    final today = _isToday(date);
    final inDisplayedMonth = date.month == _displayedMonth.month;
    final weekend =
        date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
    final dateColor = !inDisplayedMonth
        ? colors.onSurfaceVariant.withValues(alpha: 0.45)
        : selected && today
        ? colors.onPrimary
        : selected
        ? colors.onPrimaryContainer
        : today
        ? colors.primary
        : weekend
        ? colors.tertiary
        : colors.onSurface;
    final eventCount = occurrences.length;
    final fullDate = MaterialLocalizations.of(context).formatFullDate(date);

    return Semantics(
      key: ValueKey('calendar-day-${date.year}-${date.month}-${date.day}'),
      button: true,
      selected: selected,
      label: eventCount == 0 ? fullDate : '$fullDate, $eventCount reminders',
      child: Material(
        color: selected
            ? today
                  ? colors.primary
                  : colors.primaryContainer
            : today
            ? colors.primary.withValues(alpha: 0.07)
            : weekend
            ? colors.surfaceContainerLow.withValues(alpha: 0.55)
            : colors.surface,
        child: InkWell(
          onTap: () => _selectDate(date),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: selected || today
                    ? colors.primary.withValues(alpha: 0.7)
                    : colors.outlineVariant.withValues(alpha: 0.42),
                width: selected || today ? 0.9 : 0.4,
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              compact ? 1 : 2,
              compact ? 0 : 2,
              compact ? 1 : 2,
              compact ? 0 : 1,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: compact ? 15 : 25,
                  height: compact ? 15 : 25,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? today
                              ? colors.primary
                              : colors.primary.withValues(alpha: 0.14)
                        : today
                        ? colors.primary
                        : null,
                    border: today && selected
                        ? Border.all(color: colors.onPrimary, width: 1.2)
                        : null,
                  ),
                  child: Text(
                    MaterialLocalizations.of(context).formatDecimal(date.day),
                    style:
                        (compact
                                ? theme.textTheme.labelSmall
                                : theme.textTheme.labelMedium)
                            ?.copyWith(
                              color: today && !selected
                                  ? colors.onPrimary
                                  : dateColor,
                              fontWeight: selected || today
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                  ),
                ),
                if (monthOnly)
                  Expanded(
                    child: _buildMonthCellEvents(context, occurrences, date),
                  )
                else if (compact)
                  Padding(
                    padding: EdgeInsets.zero,
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 2,
                      children: [
                        for (final occurrence in occurrences.take(3))
                          Container(
                            width: 2.5,
                            height: 2.5,
                            decoration: BoxDecoration(
                              color: CalendarColors.forReminder(
                                occurrence.reminder.id,
                              ).foreground(theme.brightness == Brightness.dark),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  )
                else ...[
                  const SizedBox(height: 3),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 3,
                    runSpacing: 2,
                    children: [
                      for (final occurrence in occurrences.take(4))
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: CalendarColors.forReminder(
                              occurrence.reminder.id,
                            ).foreground(theme.brightness == Brightness.dark),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthCellEvents(
    BuildContext context,
    List<CalendarOccurrence> occurrences,
    DateTime date,
  ) {
    final theme = Theme.of(context);
    final visible = occurrences.take(2).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final occurrence in visible)
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: CalendarColors.forReminder(occurrence.reminder.id)
                    .surface(theme.brightness == Brightness.dark),
                borderRadius: BorderRadius.circular(3),
              ),
              alignment: Alignment.centerLeft,
              child: Text(
                occurrence.reminder.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 9,
                  color: CalendarColors.forReminder(occurrence.reminder.id)
                      .foreground(theme.brightness == Brightness.dark),
                ),
              ),
            ),
          ),
        if (occurrences.length > visible.length)
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: () => _openDayDetails(date),
                child: Text(
                  '+${occurrences.length - visible.length} more',
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _openDayDetails(DateTime date) {
    _selectDate(date);
    _selectViewMode(CalendarViewMode.monthAndWeek);
  }

  Widget _buildAgendaHeading(BuildContext context) {
    final start = _activeViewMode == CalendarViewMode.nextThreeDays
        ? _selectedDate
        : _weekStart(_selectedDate);
    final end = start.add(
      Duration(days: _activeViewMode == CalendarViewMode.nextThreeDays ? 2 : 6),
    );
    final localizations = MaterialLocalizations.of(context);
    final label = _activeViewMode == CalendarViewMode.nextThreeDays
        ? 'NEXT 3 DAYS'
        : 'WEEKLY SCHEDULE';
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  localizations.formatFullDate(_selectedDate),
                  key: const ValueKey('calendar-selected-date-label'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${localizations.formatShortDate(start)} – ${localizations.formatShortDate(end)}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  DateTime _weekStart(DateTime date) =>
      _dateOnly(date).subtract(Duration(days: date.weekday - DateTime.monday));

  Widget _buildWeekAgenda(BuildContext context) {
    final start = _weekStart(_selectedDate);
    return ListView(
      key: const ValueKey('calendar-week-agenda'),
      padding: const EdgeInsets.only(bottom: 72),
      children: [
        _buildWeekDayBlock(context, start, fullWidth: true),
        for (var dayOffset = 1; dayOffset < 7; dayOffset += 2)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildWeekDayBlock(
                  context,
                  start.add(Duration(days: dayOffset)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildWeekDayBlock(
                  context,
                  start.add(Duration(days: dayOffset + 1)),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildWeekDayBlock(
    BuildContext context,
    DateTime date, {
    bool fullWidth = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final occurrences = _occurrencesFor(date);
    final weekday = MaterialLocalizations.of(context)
        .narrowWeekdays[date.weekday % 7];
    final isToday = _isToday(date);
    final isSelected = _sameDay(date, _selectedDate);

    return Material(
      color: isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.24)
          : Colors.transparent,
      child: InkWell(
        onTap: () => _selectDate(date),
        child: Padding(
          padding: EdgeInsets.fromLTRB(fullWidth ? 5 : 4, 4, 4, 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    Text(
                      '$weekday ${date.day}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: isToday
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.circle, size: 7, color: colorScheme.primary),
                    ],
                  ],
                ),
              ),
              if (occurrences.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    'No reminders',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                for (final occurrence in occurrences)
                  _buildEventRow(context, occurrence, dense: true),
              Container(
                height: 0.5,
                margin: const EdgeInsets.only(top: 4),
                color: colorScheme.outlineVariant.withValues(alpha: 0.55),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThreeDayAgenda(BuildContext context) {
    return ListView.builder(
      key: const ValueKey('calendar-three-day-agenda'),
      padding: const EdgeInsets.only(bottom: 76),
      itemCount: 3,
      itemBuilder: (context, index) {
        final date = _selectedDate.add(Duration(days: index));
        return _buildAgendaDay(context, date, compact: false);
      },
    );
  }

  Widget _buildAgendaDay(
    BuildContext context,
    DateTime date, {
    required bool compact,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final occurrences = _occurrencesFor(date);
    final isSelected = _sameDay(date, _selectedDate);
    final isToday = _isToday(date);
    final weekday = MaterialLocalizations.of(context)
        .narrowWeekdays[date.weekday % 7];
    return Material(
      color: isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.28)
          : Colors.transparent,
      child: InkWell(
        onTap: () => _selectDate(date),
        child: Padding(
          padding: EdgeInsets.fromLTRB(6, compact ? 5 : 8, 4, compact ? 5 : 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: compact ? 58 : 68,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      weekday.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isToday
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${date.day}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isToday ? colorScheme.primary : null,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                constraints: const BoxConstraints(minHeight: 38),
                color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                margin: const EdgeInsets.only(right: 8),
              ),
              Expanded(
                child: occurrences.isEmpty
                    ? Container(
                        key: isSelected
                            ? const ValueKey('calendar-empty-day')
                            : null,
                        padding: const EdgeInsets.only(top: 9),
                        child: Text(
                          isSelected && isToday
                              ? 'No Reminders today'
                              : 'No reminders',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          for (final occurrence in occurrences)
                            _buildEventRow(context, occurrence),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventRow(
    BuildContext context,
    CalendarOccurrence occurrence, {
    bool dense = false,
  }) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final eventColor = CalendarColors.forReminder(occurrence.reminder.id);
    final recurrence = occurrence.reminder.recurrenceRule.type;
    return Padding(
      padding: EdgeInsets.only(bottom: dense ? 2 : 5),
      child: Material(
        key: ValueKey(
          'calendar-reminder-${occurrence.reminder.id}-${occurrence.dateTime.day}',
        ),
        color: eventColor.surface(dark),
        borderRadius: BorderRadius.circular(dense ? 4 : 7),
        child: InkWell(
          borderRadius: BorderRadius.circular(dense ? 4 : 7),
          onTap: () => _openEditReminder(occurrence.reminder),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              dense ? 4 : 7,
              dense ? 2 : 6,
              2,
              dense ? 2 : 6,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: dense ? 39 : 63,
                  child: Text(
                    dense
                        ? MaterialLocalizations.of(context).formatTimeOfDay(
                            TimeOfDay.fromDateTime(occurrence.dateTime),
                            alwaysUse24HourFormat: true,
                          )
                        : TimeOfDay.fromDateTime(occurrence.dateTime)
                              .format(context),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style:
                        (dense
                                ? theme.textTheme.labelSmall
                                : theme.textTheme.labelSmall)
                            ?.copyWith(
                              color: eventColor.foreground(dark),
                              fontSize: dense ? 9 : null,
                              fontWeight: FontWeight.w800,
                            ),
                  ),
                ),
                if (!dense)
                  Container(
                    width: 3,
                    height: 31,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: eventColor.foreground(dark),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        occurrence.reminder.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            (dense
                                    ? theme.textTheme.labelSmall
                                    : theme.textTheme.bodyMedium)
                                ?.copyWith(
                                  fontSize: dense ? 10 : null,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      if (!dense && occurrence.reminder.description
                          case final String text when text.trim().isNotEmpty)
                        Text(
                          text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (recurrence != RecurrenceType.none)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: dense ? 1 : 3),
                    child: Icon(
                      Icons.repeat,
                      size: dense ? 10 : 15,
                      color: eventColor.foreground(dark),
                    ),
                  ),
                if (occurrence.reminder.notificationMode ==
                    ReminderNotificationMode.alarmAndNotification)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: dense ? 1 : 3),
                    child: Icon(
                      Icons.alarm,
                      size: dense ? 10 : 15,
                      color: eventColor.foreground(dark),
                    ),
                  ),
                PopupMenuButton<String>(
                  tooltip: 'More actions for ${occurrence.reminder.title}',
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(
                    minWidth: dense ? 20 : 34,
                    minHeight: dense ? 18 : 34,
                  ),
                  iconSize: dense ? 13 : 17,
                  onSelected: (action) {
                    if (action == 'edit') {
                      _openEditReminder(occurrence.reminder);
                    } else if (action == 'delete') {
                      _deleteReminder(occurrence.reminder);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Edit'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline),
                        title: Text('Delete'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
