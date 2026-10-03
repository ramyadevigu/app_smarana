import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/calendar_view_mode.dart';
import 'widgets/calendar_view_selector.dart';
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

const _calendarShortMonthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sept',
  'Oct',
  'Nov',
  'Dec',
];

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    this.storage,
    this.clock = DateTime.now,
    this.viewMode = CalendarViewMode.month,
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
  Offset? _monthPointerStart;
  bool _isLoading = true;
  bool _hasLoadError = false;

  @override
  void initState() {
    super.initState();
    _storage = widget.storage ?? ReminderStorage();
    final today = _dateOnly(widget.clock());
    _today = today;
    _activeViewMode = widget.viewMode;
    _selectedDate = today;
    _displayedMonth = DateTime(today.year, today.month);
    _loadReminders();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CalendarScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewMode != widget.viewMode) {
      _activeViewMode = widget.viewMode;
      _refreshVisibleOccurrences();
    }
  }

  void _selectViewMode(CalendarViewMode mode) {
    if (_activeViewMode == mode) {
      return;
    }
    setState(() {
      _activeViewMode = mode;
      _refreshVisibleOccurrences();
    });
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
    var start = previewStart.isBefore(firstGridDate)
        ? previewStart
        : firstGridDate;
    var endExclusive = previewEndExclusive.isAfter(monthEndExclusive)
        ? previewEndExclusive
        : monthEndExclusive;
    switch (_activeViewMode) {
      case CalendarViewMode.year:
        start = DateTime(_displayedMonth.year);
        endExclusive = DateTime(_displayedMonth.year + 1);
      case CalendarViewMode.week:
        start = _weekStart(_selectedDate);
        endExclusive = start.add(const Duration(days: 7));
      case CalendarViewMode.threeDay:
        start = _selectedDate.subtract(const Duration(days: 1));
        endExclusive = _selectedDate.add(const Duration(days: 2));
      case CalendarViewMode.day:
        start = _selectedDate;
        endExclusive = _selectedDate.add(const Duration(days: 1));
      case CalendarViewMode.list:
      case CalendarViewMode.month:
        break;
    }
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
    _upcomingOccurrences =
        countdownOccurrences.values
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

  void _changePeriod(int offset) {
    if (_activeViewMode != CalendarViewMode.year) {
      _changeMonth(offset);
      return;
    }
    _setYear(_displayedMonth.year + offset);
  }

  void _setYear(int year) {
    if (year == _displayedMonth.year) {
      return;
    }
    final lastDay = DateTime(year, _selectedDate.month + 1, 0).day;
    setState(() {
      _monthTransitionDirection = year > _displayedMonth.year ? 1 : -1;
      _displayedMonth = DateTime(year, _displayedMonth.month);
      _selectedDate = DateTime(
        year,
        _selectedDate.month,
        _selectedDate.day.clamp(1, lastDay),
      );
      _refreshVisibleOccurrences();
    });
  }

  Future<void> _pickYear() async {
    final year = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (_) => _YearPickerSheet(
        selectedYear: _displayedMonth.year,
        currentYear: _today.year,
      ),
    );
    if (year == null || !mounted || year == _displayedMonth.year) {
      return;
    }
    _setYear(year);
  }

  Future<void> _pickDate() async {
    if (_activeViewMode == CalendarViewMode.year) {
      return _pickYear();
    }
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
        shape: const CircleBorder(),
        onPressed: _openAddReminder,
        tooltip: 'Add reminder for selected date',
        child: const Icon(Icons.add_rounded, size: 30),
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCalendarHeader(context),
          const SizedBox(height: 8),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeInOutCubic,
              switchOutCurve: Curves.easeInOutCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.08, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: _buildViewContent(
                context,
                key: ValueKey('calendar-view-${_activeViewMode.name}'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewContent(BuildContext context, {required Key key}) {
    return switch (_activeViewMode) {
      CalendarViewMode.list => _buildListView(context, key),
      CalendarViewMode.year => _buildYearView(context, key),
      CalendarViewMode.month => _buildMonthView(context, key),
      CalendarViewMode.week => _buildTimelineView(
        context,
        CalendarViewMode.week,
        key,
      ),
      CalendarViewMode.threeDay => _buildTimelineView(
        context,
        CalendarViewMode.threeDay,
        key,
      ),
      CalendarViewMode.day => _buildTimelineView(
        context,
        CalendarViewMode.day,
        key,
      ),
    };
  }

  Widget _buildListView(BuildContext context, Key key) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          key: key,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: constraints.maxHeight * 0.55,
              child: Column(
                children: [
                  _buildWeekdayHeader(context),
                  Expanded(
                    child: _buildMonthGridCard(
                      context,
                      key: const ValueKey('calendar-list-month-grid'),
                      monthOnly: true,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Semantics(
              button: true,
              label: 'Expand Countdown reminders',
              hint: 'Open the scrollable Countdown panel',
              child: InkWell(
                key: const ValueKey('calendar-countdown-toggle'),
                onTap: _showCountdownSheet,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Countdown',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      Icon(
                        Icons.expand_less,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: _buildUpcomingList(
                context,
                const ValueKey('calendar-list-content'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMonthView(BuildContext context, Key key) {
    return Column(
      key: key,
      children: [
        _buildWeekdayHeader(context),
        Expanded(
          child: Listener(
            onPointerDown: (event) => _monthPointerStart = event.position,
            onPointerUp: (event) {
              final start = _monthPointerStart;
              _monthPointerStart = null;
              if (start == null) {
                return;
              }
              final delta = event.position - start;
              if (delta.dx.abs() > 48 && delta.dx.abs() > delta.dy.abs()) {
                _changeMonth(delta.dx < 0 ? 1 : -1);
              }
            },
            onPointerCancel: (_) => _monthPointerStart = null,
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
                monthOnly: true,
                key: ValueKey(
                  'calendar-month-${_displayedMonth.year}-'
                  '${_displayedMonth.month}',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildYearView(BuildContext context, Key key) {
    final year = _displayedMonth.year;
    final direction = _monthTransitionDirection;
    return AnimatedSwitcher(
      key: key,
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final incoming = child.key == ValueKey('calendar-year-$year');
        final offset = Tween<Offset>(
          begin: Offset(0, incoming ? 0.08 * direction : -0.08 * direction),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: _buildYearMonths(context, year),
    );
  }

  Widget _buildYearMonths(BuildContext context, int year) {
    return LayoutBuilder(
      key: ValueKey('calendar-year-$year'),
      builder: (context, constraints) {
        const horizontalPadding = 2.0;
        const verticalPadding = 8.0;
        const bottomPadding = 64.0;
        const spacing = 8.0;
        final monthWidth =
            (constraints.maxWidth - horizontalPadding * 2 - spacing * 2) / 3;
        final monthHeight =
            (constraints.maxHeight -
                verticalPadding -
                bottomPadding -
                spacing * 3) /
            4;
        // Content fits the viewport; bouncing physics gives a spring-back
        // overscroll instead of changing the year.
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(
            horizontalPadding,
            verticalPadding,
            horizontalPadding,
            bottomPadding,
          ),
          child: RepaintBoundary(
            child: Column(
              children: [
                for (var row = 0; row < 4; row++) ...[
                  if (row > 0) const SizedBox(height: spacing),
                  SizedBox(
                    height: monthHeight,
                    child: Row(
                      children: [
                        for (var col = 0; col < 3; col++) ...[
                          if (col > 0) const SizedBox(width: spacing),
                          SizedBox(
                            width: monthWidth,
                            child: RepaintBoundary(
                              child: _buildMiniMonth(
                                context,
                                DateTime(year, row * 3 + col + 1),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniMonth(BuildContext context, DateTime month) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final firstDay = DateTime(month.year, month.month);
    final leadingDays = firstDay.weekday % DateTime.daysPerWeek;
    final dayCount = DateTime(month.year, month.month + 1, 0).day;
    final rows = (leadingDays + dayCount + 6) ~/ 7;
    final localizations = MaterialLocalizations.of(context);
    final dayStyle = (theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
      fontSize: 7,
      height: 1,
    );
    return Column(
      children: [
        SizedBox(
          height: 22,
          child: Semantics(
            button: true,
            label: 'Open ${_calendarMonthNames[month.month - 1]} ${month.year}',
            child: InkWell(
              key: ValueKey('calendar-year-month-${month.year}-${month.month}'),
              borderRadius: BorderRadius.circular(4),
              onTap: () => _openMonthFromYear(month),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _calendarShortMonthNames[month.month - 1],
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 14,
          child: Row(
            children: [
              for (final weekday in MaterialLocalizations.of(
                context,
              ).narrowWeekdays)
                Expanded(
                  child: Center(
                    child: Text(
                      weekday,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            children: [
              for (var row = 0; row < rows; row++)
                Expanded(
                  child: Row(
                    children: [
                      for (var col = 0; col < 7; col++)
                        Expanded(
                          child: _buildYearDay(
                            month,
                            row * 7 + col - leadingDays + 1,
                            dayCount,
                            dayStyle,
                            colors,
                            localizations,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildYearDay(
    DateTime month,
    int day,
    int dayCount,
    TextStyle style,
    ColorScheme colors,
    MaterialLocalizations localizations,
  ) {
    if (day < 1 || day > dayCount) {
      return const SizedBox.shrink();
    }
    final date = DateTime(month.year, month.month, day);
    final selected = _sameDay(date, _selectedDate);
    final today = _isToday(date);
    final eventCount = _occurrencesFor(date).length;
    final hasEvents = eventCount > 0;
    return Semantics(
      key: ValueKey('calendar-day-${date.year}-${date.month}-${date.day}'),
      button: true,
      selected: selected,
      label: [
        localizations.formatFullDate(date),
        if (today) 'today',
        if (selected) 'selected',
        if (hasEvents) '$eventCount reminders',
      ].join(', '),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _selectDate(date),
        child: Center(
          child: DecoratedBox(
            key: ValueKey(
              'calendar-day-marker-${date.year}-${date.month}-${date.day}',
            ),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? colors.primary : null,
              border: today && !selected
                  ? Border.all(color: colors.primary.withValues(alpha: 0.7))
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.all(1.5),
              child: Text(
                key: ValueKey(
                  'calendar-day-number-${date.year}-${date.month}-${date.day}',
                ),
                '$day',
                style: style.copyWith(
                  color: selected
                      ? colors.onPrimary
                      : hasEvents
                      ? colors.primary
                      : colors.onSurface,
                  fontWeight: selected || today || hasEvents
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openMonthFromYear(DateTime month) {
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    setState(() {
      _displayedMonth = DateTime(month.year, month.month);
      _selectedDate = DateTime(
        month.year,
        month.month,
        _selectedDate.day.clamp(1, lastDay),
      );
      _refreshVisibleOccurrences();
    });
    _selectViewMode(CalendarViewMode.month);
  }

  Widget _buildUpcomingList(BuildContext context, Key key) {
    final localizations = MaterialLocalizations.of(context);
    if (_upcomingOccurrences.isEmpty) {
      return Center(
        key: key,
        child: Text(
          'No upcoming reminders',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }
    return ListView.builder(
      key: key,
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 100),
      itemCount: _upcomingOccurrences.length,
      itemBuilder: (context, index) {
        final occurrence = _upcomingOccurrences[index];
        final reminder = occurrence.reminder;
        final color = CalendarColors.forReminder(reminder.id)
            .foreground(Theme.of(context).brightness == Brightness.dark);
        return ListTile(
          key: ValueKey('calendar-list-${reminder.id}-${occurrence.dateTime}'),
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: SizedBox(
            width: 48,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  localizations.formatShortDate(occurrence.dateTime),
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Text(
                  MaterialLocalizations.of(context).formatTimeOfDay(
                    TimeOfDay.fromDateTime(occurrence.dateTime),
                    alwaysUse24HourFormat: true,
                  ),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          title: Text(
            reminder.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle:
              reminder.description == null ||
                  reminder.description!.trim().isEmpty
              ? null
              : Text(
                  reminder.description!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                reminder.recurrenceRule.type == RecurrenceType.none
                    ? Icons.event_outlined
                    : Icons.repeat,
                color: color,
              ),
              PopupMenuButton<String>(
                tooltip: 'More actions for ${reminder.title}',
                onSelected: (action) {
                  if (action == 'edit') {
                    _openEditReminder(reminder);
                  } else if (action == 'delete') {
                    _deleteReminder(reminder);
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
          onTap: () => _openEditReminder(reminder),
        );
      },
    );
  }

  Widget _buildTimelineView(
    BuildContext context,
    CalendarViewMode mode,
    Key key,
  ) {
    final dates = switch (mode) {
      CalendarViewMode.week => List.generate(
        7,
        (index) => _weekStart(_selectedDate).add(Duration(days: index)),
      ),
      CalendarViewMode.threeDay => List.generate(
        3,
        (index) => _selectedDate.add(Duration(days: index - 1)),
      ),
      _ => [_selectedDate],
    };
    return Column(
      key: key,
      children: [
        if (mode == CalendarViewMode.day)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              MaterialLocalizations.of(context).formatFullDate(_selectedDate),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          )
        else
          _buildTimelineDateSelector(
            context,
            dates,
            mode == CalendarViewMode.week
                ? (date) {
                    _selectDate(date);
                    _selectViewMode(CalendarViewMode.day);
                  }
                : _selectDate,
          ),
        Expanded(
          child: mode == CalendarViewMode.day
              ? ListView.builder(
                  key: ValueKey('calendar-timeline-${mode.name}'),
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: 24,
                  itemBuilder: (context, hour) =>
                      _buildTimelineHour(context, hour),
                )
              : _buildMultiDayTimeline(context, mode, dates),
        ),
      ],
    );
  }

  Widget _buildTimelineDateSelector(
    BuildContext context,
    List<DateTime> dates,
    ValueChanged<DateTime> onDateSelected,
  ) {
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);
    return SizedBox(
      height: 64,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 48 + dates.length * 112,
          child: Row(
            children: [
              const SizedBox(width: 48),
              for (final date in dates)
                SizedBox(
                  width: 112,
                  child: Semantics(
                    key: ValueKey(
                      'calendar-timeline-date-${date.year}-${date.month}-${date.day}',
                    ),
                    button: true,
                    selected: _sameDay(date, _selectedDate),
                    label: localizations.formatFullDate(date),
                    child: InkWell(
                      onTap: () => onDateSelected(date),
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: _sameDay(date, _selectedDate)
                              ? theme.colorScheme.primaryContainer
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              localizations.narrowWeekdays[date.weekday % 7],
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: _sameDay(date, _selectedDate)
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              '${date.day}',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: _sameDay(date, _selectedDate)
                                    ? theme.colorScheme.primary
                                    : null,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineHour(BuildContext context, int hour) {
    final occurrences = _hourOccurrences(_selectedDate, hour);
    final isCurrentHour =
        _isToday(_selectedDate) && widget.clock().hour == hour;
    return _buildTimelineHourRow(context, hour, [
      _buildTimelineDateColumn(
        context,
        _selectedDate,
        occurrences,
        isCurrentHour,
        0,
      ),
    ], occurrences.length);
  }

  Widget _buildMultiDayTimeline(
    BuildContext context,
    CalendarViewMode mode,
    List<DateTime> dates,
  ) {
    return SingleChildScrollView(
      key: ValueKey('calendar-timeline-${mode.name}'),
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 48 + dates.length * 112,
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: 24,
          itemBuilder: (context, hour) {
            final eventLists = [
              for (final date in dates) _hourOccurrences(date, hour),
            ];
            final columns = [
              for (var index = 0; index < dates.length; index++)
                _buildTimelineDateColumn(
                  context,
                  dates[index],
                  eventLists[index],
                  _isToday(dates[index]) && widget.clock().hour == hour,
                  index,
                ),
            ];
            var maximumEventCount = 0;
            for (final events in eventLists) {
              if (events.length > maximumEventCount) {
                maximumEventCount = events.length;
              }
            }
            return _buildTimelineHourRow(
              context,
              hour,
              columns,
              maximumEventCount,
            );
          },
        ),
      ),
    );
  }

  List<CalendarOccurrence> _hourOccurrences(DateTime date, int hour) =>
      _occurrencesFor(date)
          .where((occurrence) => occurrence.dateTime.hour == hour)
          .toList();

  Widget _buildTimelineHourRow(
    BuildContext context,
    int hour,
    List<Widget> columns,
    int maximumEventCount,
  ) {
    final theme = Theme.of(context);
    final rowHeight = maximumEventCount < 3
        ? 64.0
        : maximumEventCount * 24.0 + 10;
    return SizedBox(
      height: rowHeight,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: rowHeight),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 48,
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  '${hour.toString().padLeft(2, '0')}:00',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            Expanded(child: Row(children: columns)),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineDateColumn(
    BuildContext context,
    DateTime date,
    List<CalendarOccurrence> occurrences,
    bool isCurrentHour,
    int index,
  ) {
    final theme = Theme.of(context);
    final borderColor = theme.colorScheme.outlineVariant.withValues(
      alpha: 0.55,
    );
    return Expanded(
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: borderColor, width: 0.7),
            left: BorderSide(color: borderColor, width: index == 0 ? 0 : 0.5),
          ),
        ),
        child: Stack(
          children: [
            if (isCurrentHour)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(height: 2, color: theme.colorScheme.primary),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 3, 0, 3),
              child: Column(
                children: [
                  for (final occurrence in occurrences)
                    _buildEventRow(context, occurrence, dense: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarHeader(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          if (_activeViewMode == CalendarViewMode.week ||
              _activeViewMode == CalendarViewMode.day)
            IconButton(
              key: const ValueKey('calendar-hierarchy-back'),
              tooltip: _activeViewMode == CalendarViewMode.day
                  ? 'Back to Week'
                  : 'Back to Month',
              visualDensity: VisualDensity.compact,
              onPressed: () => _selectViewMode(
                _activeViewMode == CalendarViewMode.day
                    ? CalendarViewMode.week
                    : CalendarViewMode.month,
              ),
              icon: const Icon(Icons.chevron_left),
            ),
          Expanded(
            child: Semantics(
              button: true,
              label: _activeViewMode == CalendarViewMode.year
                  ? 'Choose year ${_displayedMonth.year}'
                  : 'Choose ${localizations.formatMonthYear(_displayedMonth)}',
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
                        children: _activeViewMode == CalendarViewMode.year
                            ? [TextSpan(text: '${_displayedMonth.year}')]
                            : [
                                TextSpan(
                                  text:
                                      _calendarMonthNames[_displayedMonth
                                              .month -
                                          1],
                                ),
                                TextSpan(
                                  text: ' ${_displayedMonth.year}',
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
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
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
          ),
          CalendarViewSelector(
            selectedMode: _activeViewMode,
            onSelected: _selectViewMode,
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
      tooltip: 'More calendar views',
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        if (value == 'today') {
          _returnToToday();
        } else if (value == 'countdown') {
          _showCountdownSheet();
        } else if (value == 'previous-month') {
          _changePeriod(-1);
        } else if (value == 'next-month') {
          _changePeriod(1);
        }
      },
      itemBuilder: (context) {
        final period = _activeViewMode == CalendarViewMode.year
            ? 'year'
            : 'month';
        return [
          const PopupMenuItem(
            value: 'countdown',
            child: ListTile(
              leading: Icon(Icons.hourglass_bottom),
              title: Text('Countdown'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const PopupMenuItem(
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
              leading: const Icon(Icons.chevron_left),
              title: Text('Previous $period'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: 'next-month',
            child: ListTile(
              leading: const Icon(Icons.chevron_right),
              title: Text('Next $period'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ];
      },
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

  void _showCountdownSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: _buildCountdownSheet(),
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
    DateTime? monthContext,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final occurrences = _occurrencesFor(date);
    final selected = _sameDay(date, _selectedDate);
    final today = _isToday(date);
    final displayedMonth = monthContext ?? _displayedMonth;
    final inDisplayedMonth =
        date.month == displayedMonth.month && date.year == displayedMonth.year;
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
        onTap: () {
          _selectDate(date);
          if (monthOnly) {
            _selectViewMode(CalendarViewMode.week);
          }
        },
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
                key: ValueKey(
                  'calendar-day-marker-${date.year}-${date.month}-${date.day}',
                ),
                duration: const Duration(milliseconds: 210),
                curve: Curves.easeOutCubic,
                width: compact ? 11 : 32,
                height: compact ? 11 : 32,
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
                            fontSize: compact ? 7 : null,
                            height: compact ? 1 : null,
                          ),
                  child: Text(
                    key: ValueKey(
                      'calendar-day-number-${date.year}-${date.month}-${date.day}',
                    ),
                    MaterialLocalizations.of(context).formatDecimal(date.day),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ),
              if (monthOnly)
                Expanded(
                  child: _buildMonthCellEvents(context, occurrences, date),
                )
              else if (compact)
                SizedBox(
                  height: 1,
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
                              color: CalendarColors.forReminder(
                                occurrence.reminder.id,
                              ).foreground(theme.brightness == Brightness.dark),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              else ...[
                const SizedBox(height: 2),
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
    _selectViewMode(CalendarViewMode.day);
  }

  DateTime _weekStart(DateTime date) =>
      _dateOnly(date).subtract(Duration(days: date.weekday - DateTime.monday));

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
                if (!dense)
                  PopupMenuButton<String>(
                    tooltip: 'More actions for ${occurrence.reminder.title}',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 34,
                      minHeight: 34,
                    ),
                    iconSize: 17,
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

class _YearPickerSheet extends StatefulWidget {
  const _YearPickerSheet({
    required this.selectedYear,
    required this.currentYear,
  });

  final int selectedYear;
  final int currentYear;

  static const firstYear = 1900;
  static const lastYear = 2100;

  @override
  State<_YearPickerSheet> createState() => _YearPickerSheetState();
}

class _YearPickerSheetState extends State<_YearPickerSheet> {
  static const _itemExtent = 52.0;
  late final FixedExtentScrollController _controller;
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = widget.selectedYear;
    _controller = FixedExtentScrollController(
      initialItem: _year - _YearPickerSheet.firstYear,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _jumpTo(int year) {
    _controller.animateToItem(
      year - _YearPickerSheet.firstYear,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Select year',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _jumpTo(widget.currentYear),
                  child: const Text('This year'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: _itemExtent * 5,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  IgnorePointer(
                    child: Container(
                      height: _itemExtent,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  ListWheelScrollView.useDelegate(
                    key: const ValueKey('calendar-year-picker'),
                    controller: _controller,
                    itemExtent: _itemExtent,
                    perspective: 0.003,
                    diameterRatio: 2.2,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: (index) {
                      HapticFeedback.selectionClick();
                      setState(
                        () => _year = _YearPickerSheet.firstYear + index,
                      );
                    },
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount:
                          _YearPickerSheet.lastYear -
                          _YearPickerSheet.firstYear +
                          1,
                      builder: (context, index) {
                        final year = _YearPickerSheet.firstYear + index;
                        final selected = year == _year;
                        final isCurrent = year == widget.currentYear;
                        return Semantics(
                          button: true,
                          selected: selected,
                          label: isCurrent ? '$year, this year' : '$year',
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _jumpTo(year),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 150),
                                    style:
                                        (selected
                                                ? theme.textTheme.headlineSmall
                                                : theme.textTheme.titleLarge)!
                                            .copyWith(
                                              fontWeight: selected
                                                  ? FontWeight.w700
                                                  : FontWeight.w400,
                                              color: selected
                                                  ? scheme.onPrimaryContainer
                                                  : scheme.onSurfaceVariant,
                                            ),
                                    child: Text('$year'),
                                  ),
                                  if (isCurrent) ...[
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.circle,
                                      size: 6,
                                      color: scheme.primary,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(_year),
                    child: const Text('Select'),
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
