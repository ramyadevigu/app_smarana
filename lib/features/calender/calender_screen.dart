import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../reminders/models/reminder.dart';
import '../reminders/screens/add_reminder_screen.dart';
import '../reminders/services/reminder_storage.dart';
import 'services/calendar_service.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    this.storage,
    this.clock = DateTime.now,
    this.appMenu,
  });

  static const double _emptyAgendaHeight = 40;
  static const double _agendaHourHeight = 88;
  static const double _agendaReminderOverflow = 96;
  static const int _timelineHours = 24;
  static const double _nowViewportFraction = 0.3;

  final ReminderStorage? storage;
  final DateTime Function() clock;
  final Widget? appMenu;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late final ReminderStorage _storage;
  final CalendarService _calendarService = CalendarService();
  final ScrollController _agendaScrollController = ScrollController();

  late DateTime _selectedDate;
  late DateTime _displayedMonth;
  late DateTime _currentDateTime;
  Timer? _clockTimer;
  List<Reminder> _reminders = [];
  Map<DateTime, List<CalendarOccurrence>> _occurrencesByDate = {};
  bool _isLoading = true;
  bool _hasLoadError = false;
  bool _hasScheduledInitialScroll = false;

  @override
  void initState() {
    super.initState();
    _storage = widget.storage ?? ReminderStorage();
    _currentDateTime = widget.clock();
    _selectedDate = _dateOnly(_currentDateTime);
    _displayedMonth = DateTime(_selectedDate.year, _selectedDate.month);
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted || ModalRoute.of(context)?.isCurrent == false) {
        return;
      }
      setState(() {
        _currentDateTime = widget.clock();
      });
    });
    _loadReminders();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _agendaScrollController.dispose();
    super.dispose();
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
      if (!_hasScheduledInitialScroll) {
        _hasScheduledInitialScroll = true;
        _scheduleAgendaScroll();
      }
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
    final endExclusive = firstGridDate.add(
      Duration(days: _monthGridCellCount()),
    );
    _occurrencesByDate = _calendarService.occurrencesBetween(
      _reminders,
      start: firstGridDate,
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
    _scheduleAgendaScroll();
  }

  void _changeYear(int offset) {
    final nextMonth = DateTime(
      _displayedMonth.year + offset,
      _displayedMonth.month,
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
    _scheduleAgendaScroll();
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
        _refreshVisibleOccurrences();
      }
    });
    _scheduleAgendaScroll();
  }

  void _returnToToday() {
    final today = _dateOnly(widget.clock());
    setState(() {
      _currentDateTime = widget.clock();
      _selectedDate = today;
      _displayedMonth = DateTime(today.year, today.month);
      _refreshVisibleOccurrences();
    });
    _scheduleAgendaScroll();
  }

  void _scheduleAgendaScroll({double? targetHour}) {
    final targetTime = _isToday(_selectedDate)
        ? _currentDateTime
        : DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
            8,
          );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_agendaScrollController.hasClients) {
        return;
      }
      final position = _agendaScrollController.position;
      final hour = targetHour ?? targetTime.hour + targetTime.minute / 60;
      final targetOffset = hour * CalendarScreen._agendaHourHeight;
      final target =
          (targetOffset -
                  position.viewportDimension *
                      CalendarScreen._nowViewportFraction)
              .clamp(0.0, position.maxScrollExtent);
      _agendaScrollController.jumpTo(target);
    });
  }

  void _moveAgendaDate(int offset) {
    final date = _selectedDate.add(Duration(days: offset));
    setState(() {
      _selectedDate = date;
      _displayedMonth = DateTime(date.year, date.month);
      _refreshVisibleOccurrences();
    });
    _scheduleAgendaScroll(targetHour: offset > 0 ? 0 : 23);
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

  bool _isToday(DateTime date) => _sameDay(date, _currentDateTime);

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
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          TextButton.icon(
            onPressed: _returnToToday,
            icon: const Icon(Icons.today_outlined),
            label: const Text('Today'),
          ),
          const SizedBox(width: 8),
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
      builder: (context, constraints) {
        final rowCount = _monthGridCellCount() ~/ 7;
        final cellExtent = ((constraints.maxHeight - 176) / rowCount)
            .clamp(38.0, 52.0)
            .toDouble();
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildMonthHeader(context),
                  const SizedBox(height: 8),
                  _buildWeekdayHeader(context),
                  const SizedBox(height: 2),
                  _buildMonthGrid(context, cellExtent),
                  const Divider(height: 20),
                  _buildAgendaHeader(context),
                  const SizedBox(height: 4),
                  if (_occurrencesFor(_selectedDate).isEmpty)
                    _buildEmptyAgenda(context),
                  Expanded(
                    child: SingleChildScrollView(
                      key: const ValueKey('calendar-agenda-scroll'),
                      controller: _agendaScrollController,
                      child: _buildDayTimeline(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMonthHeader(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return Row(
      children: [
        IconButton(
          key: const ValueKey('calendar-previous-year'),
          tooltip: 'Previous year',
          visualDensity: VisualDensity.compact,
          onPressed: () => _changeYear(-1),
          icon: const Icon(Icons.keyboard_double_arrow_left),
        ),
        IconButton(
          tooltip: 'Previous month',
          visualDensity: VisualDensity.compact,
          onPressed: () => _changeMonth(-1),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Semantics(
            header: true,
            child: TextButton(
              key: const ValueKey('calendar-select-date'),
              onPressed: _pickDate,
              child: Text(
                localizations.formatMonthYear(_displayedMonth),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Next month',
          visualDensity: VisualDensity.compact,
          onPressed: () => _changeMonth(1),
          icon: const Icon(Icons.chevron_right),
        ),
        IconButton(
          key: const ValueKey('calendar-next-year'),
          tooltip: 'Next year',
          visualDensity: VisualDensity.compact,
          onPressed: () => _changeYear(1),
          icon: const Icon(Icons.keyboard_double_arrow_right),
        ),
      ],
    );
  }

  Widget _buildWeekdayHeader(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final weekdays = localizations.narrowWeekdays;
    const mondayFirstIndexes = [1, 2, 3, 4, 5, 6, 0];
    return Row(
      children: [
        for (final index in mondayFirstIndexes)
          Expanded(
            child: Semantics(
              label: localizations.narrowWeekdays[index],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  weekdays[index],
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
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

  Widget _buildMonthGrid(BuildContext context, double cellExtent) {
    final firstOfMonth = DateTime(_displayedMonth.year, _displayedMonth.month);
    final leadingDays = firstOfMonth.weekday - DateTime.monday;
    final firstGridDate = firstOfMonth.subtract(Duration(days: leadingDays));

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _monthGridCellCount(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisExtent: cellExtent,
      ),
      itemBuilder: (context, index) =>
          _buildDateCell(context, firstGridDate.add(Duration(days: index))),
    );
  }

  Widget _buildDateCell(BuildContext context, DateTime date) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selected = _sameDay(date, _selectedDate);
    final today = _isToday(date);
    final inDisplayedMonth = date.month == _displayedMonth.month;
    final reminders = _occurrencesFor(date);
    final dayTextColor = selected
        ? colorScheme.onPrimary
        : inDisplayedMonth
        ? colorScheme.onSurface
        : colorScheme.onSurfaceVariant.withValues(alpha: 0.58);
    final dateLabel = MaterialLocalizations.of(context).formatFullDate(date);
    final semanticLabel = reminders.isEmpty
        ? dateLabel
        : '$dateLabel, ${reminders.length} reminder'
              '${reminders.length == 1 ? '' : 's'}';

    return Semantics(
      key: ValueKey('calendar-day-${date.year}-${date.month}-${date.day}'),
      button: true,
      selected: selected,
      label: semanticLabel,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _selectDate(date),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? colorScheme.primary : null,
                borderRadius: BorderRadius.circular(9),
                border: today && !selected
                    ? Border.all(color: colorScheme.primary, width: 1.5)
                    : null,
              ),
              child: Text(
                MaterialLocalizations.of(context).formatDecimal(date.day),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: today && !selected
                      ? colorScheme.primary
                      : dayTextColor,
                  fontWeight: selected || today ? FontWeight.w700 : null,
                ),
              ),
            ),
            SizedBox(
              height: 6,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (
                    var index = 0;
                    index < reminders.length.clamp(0, 3);
                    index++
                  )
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected
                              ? colorScheme.onPrimary
                              : _reminderDotColor(colorScheme, index),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _reminderDotColor(ColorScheme colorScheme, int index) {
    return switch (index) {
      0 => colorScheme.primary,
      1 => colorScheme.secondary,
      _ => colorScheme.tertiary,
    };
  }

  Widget _buildAgendaHeader(BuildContext context) {
    return Row(
      children: [
        IconButton(
          key: const ValueKey('calendar-previous-day'),
          tooltip: 'Previous day',
          onPressed: () => _moveAgendaDate(-1),
          icon: const Icon(Icons.chevron_left),
          visualDensity: VisualDensity.compact,
        ),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              MaterialLocalizations.of(context).formatFullDate(_selectedDate),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        IconButton(
          key: const ValueKey('calendar-next-day'),
          tooltip: 'Next day',
          onPressed: () => _moveAgendaDate(1),
          icon: const Icon(Icons.chevron_right),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  Widget _buildEmptyAgenda(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: CalendarScreen._emptyAgendaHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              Icons.event_available_outlined,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No Reminders today',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayTimeline(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final occurrences = _occurrencesFor(_selectedDate);
        final nowOffset =
            (_currentDateTime.hour * 60 + _currentDateTime.minute) /
            60 *
            CalendarScreen._agendaHourHeight;
        final eventLaneWidth = (constraints.maxWidth - 64)
            .clamp(0.0, double.infinity)
            .toDouble();

        return SizedBox(
          height:
              CalendarScreen._timelineHours * CalendarScreen._agendaHourHeight +
              CalendarScreen._agendaReminderOverflow,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var hour = 0; hour < CalendarScreen._timelineHours; hour++)
                Positioned(
                  top: hour * CalendarScreen._agendaHourHeight,
                  left: 0,
                  right: 0,
                  height: CalendarScreen._agendaHourHeight,
                  child: _buildHourColumn(context, hour),
                ),
              for (var index = 0; index < occurrences.length; index++)
                _buildPositionedReminder(
                  context,
                  occurrences,
                  index,
                  eventLaneWidth,
                ),
              if (_isToday(_selectedDate))
                Positioned(
                  top: nowOffset - 1,
                  left: 64,
                  right: 0,
                  child: IgnorePointer(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            key: const ValueKey('calendar-now-indicator'),
                            height: 2,
                            color: AppColors.azureBlue,
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.azureBlue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            MaterialLocalizations.of(context).formatTimeOfDay(
                              TimeOfDay.fromDateTime(_currentDateTime),
                            ),
                            key: const ValueKey('calendar-now-time'),
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPositionedReminder(
    BuildContext context,
    List<CalendarOccurrence> occurrences,
    int index,
    double eventLaneWidth,
  ) {
    final occurrence = occurrences[index];
    final sameTime = occurrences
        .where(
          (candidate) =>
              candidate.dateTime.hour == occurrence.dateTime.hour &&
              candidate.dateTime.minute == occurrence.dateTime.minute,
        )
        .toList();
    final lane = sameTime.indexOf(occurrence);
    final laneWidth = eventLaneWidth / sameTime.length;
    final minuteOffset =
        (occurrence.dateTime.hour * 60 + occurrence.dateTime.minute) /
        60 *
        CalendarScreen._agendaHourHeight;

    return Positioned(
      top: minuteOffset,
      left: 64 + laneWidth * lane,
      right: laneWidth * (sameTime.length - lane - 1),
      child: _buildReminderTile(context, occurrence),
    );
  }

  Widget _buildHourColumn(BuildContext context, int hour) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      child: Stack(
        key: ValueKey('calendar-hour-$hour'),
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: colorScheme.outlineVariant),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: SizedBox(
              width: 56,
              child: Text(
                TimeOfDay(hour: hour, minute: 0).format(context),
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderTile(
    BuildContext context,
    CalendarOccurrence occurrence,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 4, bottom: 4),
      child: Material(
        key: ValueKey('calendar-reminder-${occurrence.reminder.id}'),
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _openEditReminder(occurrence.reminder),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        occurrence.reminder.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'More actions for ${occurrence.reminder.title}',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      iconSize: 18,
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
                if (occurrence.reminder.description
                    case final String description
                    when description.trim().isNotEmpty)
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                Text(
                  TimeOfDay.fromDateTime(occurrence.dateTime).format(context),
                  textAlign: TextAlign.end,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
