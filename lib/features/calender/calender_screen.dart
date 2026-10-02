import 'package:flutter/material.dart';

import 'models/calendar_view_mode.dart';
import '../reminders/models/reminder.dart';
import '../reminders/screens/add_reminder_screen.dart';
import '../reminders/services/reminder_storage.dart';
import 'services/calendar_service.dart';
import 'theme/calendar_colors.dart';

const _calendarMonthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

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
  late DateTime _today;
  late CalendarViewMode _activeViewMode;
  List<Reminder> _reminders = [];
  Map<DateTime, List<CalendarOccurrence>> _occurrencesByDate = {};
  List<CalendarOccurrence> _upcomingOccurrences = [];
  int _monthTransitionDirection = 1;
  bool _isLoading = true;
  bool _hasLoadError = false;

  @override
  void initState() {
    super.initState();
    _storage = widget.storage ?? ReminderStorage();
    final today = _dateOnly(widget.clock());
    _today = today;
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
    final leadingDays = firstOfMonth.weekday % DateTime.daysPerWeek;
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
    final countdownStart = _dateOnly(widget.clock());
    final countdownOccurrences = _calendarService.occurrencesBetween(
      _reminders,
      start: countdownStart,
      endExclusive: countdownStart.add(const Duration(days: 31)),
    );
    _upcomingOccurrences = countdownOccurrences.values
        .expand((occurrences) => occurrences)
        .where((occurrence) => occurrence.dateTime.isAfter(widget.clock()))
        .toList()
      ..sort((first, second) => first.dateTime.compareTo(second.dateTime));
  }

  void _changeMonth(int offset) {
    final nextMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + offset,
    );
    final lastDay = DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
    setState(() {
      _monthTransitionDirection = offset.sign;
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
    final selectedDate = _dateOnly(date);
    setState(() {
      if (selectedDate.year != _displayedMonth.year ||
          selectedDate.month != _displayedMonth.month) {
        _monthTransitionDirection = selectedDate.isAfter(_displayedMonth)
            ? 1
            : -1;
      }
      _selectedDate = selectedDate;
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
      _monthTransitionDirection = today.isBefore(_displayedMonth) ? -1 : 1;
      _today = today;
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

  bool _isToday(DateTime date) => _sameDay(date, _today);

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
    return Scaffold(
      body: SafeArea(child: _buildBody(context)),
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

  PopupMenuItem<String> _viewModeMenuItem(
    CalendarViewMode mode,
    String label,
  ) {
    final selected = _activeViewMode == mode;
    return PopupMenuItem<String>(
      value: mode.name,
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

    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        key: ValueKey('calendar-view-${_activeViewMode.name}'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCalendarHeader(context),
                const SizedBox(height: 8),
                _buildWeekdayHeader(context),
                SizedBox(
                  height: constraints.maxHeight * 0.43,
                  child: GestureDetector(
                    onHorizontalDragEnd: (details) {
                      final velocity = details.primaryVelocity ?? 0;
                      if (velocity.abs() > 100) {
                        _changeMonth(velocity < 0 ? 1 : -1);
                      }
                    },
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        final offset = Tween<Offset>(
                          begin: Offset(_monthTransitionDirection * 0.12, 0),
                          end: Offset.zero,
                        ).animate(animation);
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(position: offset, child: child),
                        );
                      },
                      child: _buildMonthGridCard(
                        context,
                        monthOnly: false,
                        key: ValueKey(
                          'calendar-month-${_displayedMonth.year}-'
                          '${_displayedMonth.month}',
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _buildSelectedDateContent(context),
                  ),
                ),
              ],
            ),
          ),
          _buildCountdownSheet(),
        ],
      ),
    );
  }

  Widget _buildCalendarHeader(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: 'Choose ${localizations.formatMonthYear(_displayedMonth)}',
              child: InkWell(
                key: const ValueKey('calendar-select-date'),
                borderRadius: BorderRadius.circular(8),
                onTap: _pickDate,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: _calendarMonthNames[
                              _displayedMonth.month - 1
                            ],
                          ),
                          TextSpan(
                            text: ' ${_displayedMonth.year}',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                      key: ValueKey(
                        'calendar-month-title-${_displayedMonth.year}-'
                        '${_displayedMonth.month}',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          PopupMenuButton<CalendarViewMode>(
            key: const ValueKey('calendar-view-selector'),
            tooltip: 'Calendar view',
            icon: const Icon(Icons.view_agenda_outlined),
            initialValue: _activeViewMode,
            onSelected: _selectViewMode,
            itemBuilder: (context) => [
              _viewMenuItem(CalendarViewMode.monthAndWeek, 'Month + Week'),
              _viewMenuItem(CalendarViewMode.nextThreeDays, 'Next 3 Days'),
            ],
          ),
          PopupMenuButton<String>(
            tooltip: 'More calendar views',
            icon: const Icon(Icons.calendar_view_month_outlined),
            onSelected: (value) {
              if (value == 'today') {
                _returnToToday();
              } else if (value == 'previous-month') {
                _changeMonth(-1);
              } else if (value == 'next-month') {
                _changeMonth(1);
              } else if (value == CalendarViewMode.monthOnly.name) {
                _selectViewMode(CalendarViewMode.monthOnly);
              } else if (value == CalendarViewMode.monthAndWeek.name) {
                _selectViewMode(CalendarViewMode.monthAndWeek);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'today',
                child: ListTile(
                  leading: Icon(Icons.today_outlined),
                  title: Text('Go to Today'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'previous-month',
                child: ListTile(
                  leading: Icon(Icons.chevron_left),
                  title: Text('Previous month'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'next-month',
                child: ListTile(
                  leading: Icon(Icons.chevron_right),
                  title: Text('Next month'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              _viewModeMenuItem(
                CalendarViewMode.monthOnly,
                'Month Only',
              ),
              _viewModeMenuItem(
                CalendarViewMode.monthAndWeek,
                'Month + Week',
              ),
            ],
          ),
          _buildMoreMenu(),
        ],
      ),
    );
  }

  Widget _buildMoreMenu() {
    if (widget.appMenu case final appMenu?) {
      return appMenu;
    }
    return PopupMenuButton<String>(
      tooltip: 'More calendar options',
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        if (value == 'today') {
          _returnToToday();
        } else if (value == 'previous-month') {
          _changeMonth(-1);
        } else if (value == 'next-month') {
          _changeMonth(1);
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'today',
          child: ListTile(
            leading: Icon(Icons.today_outlined),
            title: Text('Go to Today'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'previous-month',
          child: ListTile(
            leading: Icon(Icons.chevron_left),
            title: Text('Previous month'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'next-month',
          child: ListTile(
            leading: Icon(Icons.chevron_right),
            title: Text('Next month'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Widget _buildWeekdayHeader(BuildContext context, {bool compact = false}) {
    final localizations = MaterialLocalizations.of(context);
    const sundayFirstIndexes = [0, 1, 2, 3, 4, 5, 6];
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    );
    return SizedBox(
      height: compact ? 18 : 28,
      child: Row(
        children: [
          for (var index = 0; index < sundayFirstIndexes.length; index++)
            Expanded(
              child: Center(
                child: Text(
                  localizations.narrowWeekdays[sundayFirstIndexes[index]],
                  style: style?.copyWith(
                    color: index == 0 || index == 6
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
    Key? key,
    bool monthOnly = false,
    bool compact = false,
    bool twoWeekPreview = false,
  }) {
    return LayoutBuilder(
      key: key ?? ValueKey('calendar-month-grid-$monthOnly-$twoWeekPreview'),
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
    return 42;
  }

  DateTime _monthGridStartDate() {
    final firstOfMonth = DateTime(_displayedMonth.year, _displayedMonth.month);
    return firstOfMonth.subtract(
      Duration(days: firstOfMonth.weekday % DateTime.daysPerWeek),
    );
  }

  Widget _buildSelectedDateContent(BuildContext context) {
    if (_activeViewMode == CalendarViewMode.nextThreeDays) {
      return _buildThreeDayAgenda(context);
    }
    if (_activeViewMode == CalendarViewMode.monthOnly) {
      return const SizedBox.shrink(key: ValueKey('calendar-month-only-content'));
    }

    final occurrences = _occurrencesFor(_selectedDate);
    if (occurrences.isEmpty) {
      final theme = Theme.of(context);
      return Center(
        key: const ValueKey('calendar-empty-day'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_month_outlined,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 12),
            Text(
              'You have a free day',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Take it easy',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final localizations = MaterialLocalizations.of(context);
    return ListView(
      key: const ValueKey('calendar-selected-day-events'),
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 120),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            localizations.formatFullDate(_selectedDate),
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        for (final occurrence in occurrences)
          _buildSelectedEventRow(context, occurrence),
      ],
    );
  }

  Widget _buildSelectedEventRow(
    BuildContext context,
    CalendarOccurrence occurrence,
  ) {
    final theme = Theme.of(context);
    final reminder = occurrence.reminder;
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(occurrence.dateTime),
      alwaysUse24HourFormat: true,
    );
    return InkWell(
      key: ValueKey('calendar-selected-reminder-${reminder.id}'),
      onTap: () => _openEditReminder(reminder),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            SizedBox(
              width: 58,
              child: Text(
                time,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Container(
              width: 3,
              height: 28,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: CalendarColors.forReminder(reminder.id).foreground(
                  theme.brightness == Brightness.dark,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Text(
                reminder.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (reminder.recurrenceRule.type != RecurrenceType.none)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.repeat, size: 16),
              ),
            if (reminder.notificationMode ==
                ReminderNotificationMode.alarmAndNotification)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.alarm_outlined, size: 16),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountdownSheet() {
    return DraggableScrollableSheet(
      key: const ValueKey('calendar-countdown-sheet'),
      initialChildSize: 0.14,
      minChildSize: 0.1,
      maxChildSize: 0.7,
      snap: true,
      snapSizes: const [0.14, 0.42],
      builder: (context, scrollController) {
        final theme = Theme.of(context);
        final localizations = MaterialLocalizations.of(context);
        return Material(
          color: theme.colorScheme.surfaceContainerLow,
          elevation: 3,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListView(
            key: const ValueKey('calendar-countdown-content'),
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Center(
                child: Semantics(
                  container: true,
                  label: 'Countdown panel drag handle',
                  child: Container(
                    width: 34,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.4,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Countdown',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              if (_upcomingOccurrences.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    'No upcoming reminders',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                for (final occurrence in _upcomingOccurrences.take(12))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.event_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(
                      occurrence.reminder.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${localizations.formatMediumDate(occurrence.dateTime)} · '
                      '${TimeOfDay.fromDateTime(occurrence.dateTime).format(context)}',
                    ),
                    onTap: () => _openEditReminder(occurrence.reminder),
                  ),
            ],
          ),
        );
      },
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
        : selected
      ? colors.onPrimary
        : today
      ? colors.onSurface
        : weekend
        ? colors.tertiary
        : colors.onSurface;
    final eventCount = occurrences.length;
    final fullDate = MaterialLocalizations.of(context).formatFullDate(date);

    return Semantics(
      key: ValueKey('calendar-day-${date.year}-${date.month}-${date.day}'),
      button: true,
      selected: selected,
      label: [
        fullDate,
        if (today) 'today',
        if (selected) 'selected',
        if (eventCount > 0) '$eventCount reminders',
      ].join(', '),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () => _selectDate(date),
        child: Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 1 : 2,
              compact ? 0 : 2,
              compact ? 1 : 2,
              compact ? 0 : 1,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 210),
                  curve: Curves.easeOutCubic,
                  width: compact ? 13 : 32,
                  height: compact ? 13 : 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? colors.primary : Colors.transparent,
                    border: today && !selected
                        ? Border.all(
                            color: colors.primary.withValues(alpha: 0.7),
                            width: 1,
                          )
                        : null,
                  ),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 210),
                    curve: Curves.easeOutCubic,
                    style:
                        (compact
                                ? theme.textTheme.labelSmall
                                : theme.textTheme.labelMedium ??
                                      theme.textTheme.bodyMedium ??
                                      const TextStyle())!
                            .copyWith(
                              color: selected ? colors.onPrimary : dateColor,
                              fontWeight: selected || today
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                    child: Text(
                      MaterialLocalizations.of(context).formatDecimal(
                        date.day,
                      ),
                    ),
                  ),
                ),
                if (monthOnly)
                  Expanded(
                    child: _buildMonthCellEvents(context, occurrences, date),
                  )
                else if (compact)
                  SizedBox(
                    height: 2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final occurrence in occurrences.take(3))
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1),
                            child: Container(
                              width: 2,
                              height: 2,
                              decoration: BoxDecoration(
                                color:
                                    CalendarColors.forReminder(
                                      occurrence.reminder.id,
                                    ).foreground(
                                      theme.brightness == Brightness.dark,
                                    ),
                                shape: BoxShape.circle,
                              ),
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
                  key: isSelected ? const ValueKey('calendar-empty-day') : null,
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    isSelected && isToday
                        ? 'No Reminders today'
                        : 'No reminders',
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
    final description = occurrence.reminder.description;
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
                      if (!dense &&
                          description != null &&
                          description.trim().isNotEmpty)
                        Text(
                          description,
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
