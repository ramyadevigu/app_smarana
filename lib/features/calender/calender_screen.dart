import 'package:flutter/material.dart';

import 'models/calendar_view_mode.dart';
import '../reminders/models/reminder.dart';
import '../reminders/screens/add_reminder_screen.dart';
import '../reminders/services/reminder_storage.dart';
import 'services/calendar_service.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    this.storage,
    this.clock = DateTime.now,
    this.viewMode = CalendarViewMode.stacked,
    this.appMenu,
  });

  final ReminderStorage? storage;
  final DateTime Function() clock;
  final CalendarViewMode viewMode;
  final Widget? appMenu;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late final ReminderStorage _storage;
  final CalendarService _calendarService = CalendarService();

  late DateTime _selectedDate;
  late DateTime _displayedMonth;
  List<Reminder> _reminders = [];
  Map<DateTime, List<CalendarOccurrence>> _occurrencesByDate = {};
  bool _isLoading = true;
  bool _hasLoadError = false;

  @override
  void initState() {
    super.initState();
    _storage = widget.storage ?? ReminderStorage();
    final today = _dateOnly(widget.clock());
    _selectedDate = today;
    _displayedMonth = DateTime(today.year, today.month);
    _loadReminders();
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

  List<CalendarOccurrence> _selectedDateOccurrences() {
    final occurrences = List<CalendarOccurrence>.of(
      _occurrencesFor(_selectedDate),
    );
    occurrences.sort((first, second) {
      final byTime = first.dateTime.compareTo(second.dateTime);
      if (byTime != 0) {
        return byTime;
      }
      return first.reminder.title.compareTo(second.reminder.title);
    });
    return occurrences;
  }

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

    return widget.viewMode == CalendarViewMode.split
        ? _buildSplitLayout(context)
        : _buildStackedLayout(context);
  }

  Widget _buildStackedLayout(BuildContext context) {
    return Padding(
      key: const ValueKey('calendar-view-stacked'),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMonthHeader(context),
          const SizedBox(height: 10),
          _buildWeekdayHeader(context),
          const SizedBox(height: 2),
          Expanded(flex: 5, child: _buildMonthGridCard(context)),
          const SizedBox(height: 10),
          _buildSelectedDateHeader(context),
          const SizedBox(height: 6),
          Expanded(flex: 4, child: _buildSelectedDateList(context)),
        ],
      ),
    );
  }

  Widget _buildSplitLayout(BuildContext context) {
    return Padding(
      key: const ValueKey('calendar-view-split'),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildMonthHeader(context, isCompact: true),
                const SizedBox(height: 10),
                _buildWeekdayHeader(context),
                const SizedBox(height: 2),
                Expanded(child: _buildMonthGridCard(context)),
              ],
            ),
          ),
          VerticalDivider(
            key: const ValueKey('calendar-split-divider'),
            width: 14,
            thickness: 0.8,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                _buildSelectedDateHeader(context, includeMonth: false),
                const SizedBox(height: 8),
                Expanded(child: _buildSelectedDateList(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthHeader(BuildContext context, {bool isCompact = false}) {
    final localizations = MaterialLocalizations.of(context);
    final title = localizations.formatMonthYear(_displayedMonth);
    final theme = Theme.of(context);
    final baseTextStyle =
        (isCompact ? theme.textTheme.titleMedium : theme.textTheme.titleLarge)
            ?.copyWith(fontWeight: FontWeight.w700);
    final iconSize = isCompact ? 24.0 : 28.0;
    final minButtonSize = isCompact ? 40.0 : 46.0;

    return Row(
      children: [
        IconButton(
          key: const ValueKey('calendar-previous-month'),
          tooltip: 'Previous month',
          onPressed: () => _changeMonth(-1),
          icon: Icon(Icons.chevron_left, size: iconSize),
          style: IconButton.styleFrom(
            minimumSize: Size(minButtonSize, minButtonSize),
            tapTargetSize: MaterialTapTargetSize.padded,
          ),
        ),
        Expanded(
          child: Semantics(
            header: true,
            child: TextButton(
              key: const ValueKey('calendar-select-date'),
              onPressed: _pickDate,
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 2 : 8,
                  vertical: 6,
                ),
              ),
              child: SizedBox(
                height: isCompact ? 26 : 30,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: baseTextStyle,
                  ),
                ),
              ),
            ),
          ),
        ),
        IconButton(
          key: const ValueKey('calendar-next-month'),
          tooltip: 'Next month',
          onPressed: () => _changeMonth(1),
          icon: Icon(Icons.chevron_right, size: iconSize),
          style: IconButton.styleFrom(
            minimumSize: Size(minButtonSize, minButtonSize),
            tapTargetSize: MaterialTapTargetSize.padded,
          ),
        ),
      ],
    );
  }

  Widget _buildWeekdayHeader(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final weekdays = localizations.narrowWeekdays;
    final textStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    const mondayFirstIndexes = [1, 2, 3, 4, 5, 6, 0];

    return Row(
      children: [
        for (final index in mondayFirstIndexes)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(weekdays[index], style: textStyle),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMonthGridCard(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 0.6,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final rowCount = _monthGridCellCount() ~/ 7;
            final cellExtent = (constraints.maxHeight / rowCount)
                .clamp(44.0, 78.0)
                .toDouble();
            return _buildMonthGrid(context, cellExtent);
          },
        ),
      ),
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
      ? colorScheme.onPrimaryContainer
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _selectDate(date),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final chipHeight = (constraints.maxHeight - 10)
                  .clamp(20.0, 32.0)
                  .toDouble();
              final chipWidth = (constraints.maxWidth - 10)
                  .clamp(20.0, 34.0)
                  .toDouble();
              final dotSize = constraints.maxHeight < 40 ? 3.0 : 4.0;

              return DecoratedBox(
                decoration: BoxDecoration(
                  color: selected ? colorScheme.primaryContainer : null,
                  border: Border.all(
                    color: selected
                        ? colorScheme.primary
                        : today
                        ? colorScheme.primary.withValues(alpha: 0.55)
                        : colorScheme.outlineVariant.withValues(alpha: 0.65),
                    width: selected || today ? 0.9 : 0.35,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 3,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: chipWidth,
                        height: chipHeight,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: today && !selected
                              ? Border.all(
                                  color: colorScheme.primary,
                                  width: 1.2,
                                )
                              : null,
                        ),
                        child: Text(
                          MaterialLocalizations.of(context)
                              .formatDecimal(date.day),
                          style: theme.textTheme.bodyMedium?.copyWith(
                          color: today && !selected
                            ? colorScheme.primary
                            : dayTextColor,
                            fontWeight: selected || today
                                ? FontWeight.w700
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      SizedBox(
                        height: dotSize,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (
                              var index = 0;
                              index < reminders.length.clamp(0, 3);
                              index++
                            )
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                ),
                                child: Container(
                                  width: dotSize,
                                  height: dotSize,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: selected
                                      ? colorScheme.onPrimaryContainer
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
            },
          ),
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

  Widget _buildSelectedDateHeader(
    BuildContext context, {
    bool includeMonth = true,
  }) {
    final localizations = MaterialLocalizations.of(context);
    final fullDate = localizations.formatFullDate(_selectedDate);
    final firstCommaIndex = fullDate.indexOf(',');
    final weekday = firstCommaIndex == -1
        ? fullDate
        : fullDate.substring(0, firstCommaIndex);
    final compactDate =
        '$weekday, '
        '${localizations.formatDecimal(_selectedDate.day)} '
        '${localizations.formatDecimal(_selectedDate.year)}';

    return Semantics(
      header: true,
      child: Text(
        key: const ValueKey('calendar-selected-date-label'),
        includeMonth ? fullDate : compactDate,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildSelectedDateList(BuildContext context) {
    final occurrences = _selectedDateOccurrences();
    if (occurrences.isEmpty) {
      return _buildEmptyAgenda(context);
    }

    return ListView.separated(
      key: const ValueKey('calendar-reminder-list'),
      itemCount: occurrences.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) =>
          _buildReminderListTile(context, occurrences[index]),
    );
  }

  Widget _buildEmptyAgenda(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey('calendar-empty-day'),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
    );
  }

  Widget _buildReminderListTile(
    BuildContext context,
    CalendarOccurrence occurrence,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      key: ValueKey('calendar-reminder-${occurrence.reminder.id}'),
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _openEditReminder(occurrence.reminder),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 72,
                child: Text(
                  TimeOfDay.fromDateTime(occurrence.dateTime).format(context),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                width: 3,
                height: 40,
                margin: const EdgeInsets.only(right: 10, top: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(999),
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
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (occurrence.reminder.description
                        case final String description
                        when description.trim().isNotEmpty)
                      Text(
                        description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'More actions for ${occurrence.reminder.title}',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
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
        ),
      ),
    );
  }
}
