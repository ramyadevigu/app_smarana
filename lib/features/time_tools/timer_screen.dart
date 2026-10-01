import 'dart:async';

import 'package:flutter/material.dart';

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key, required this.appMenu});

  final Widget appMenu;

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  static const _presets = <Duration>[
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 10),
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(hours: 1),
  ];

  final _hoursController = TextEditingController(text: '00');
  final _minutesController = TextEditingController(text: '05');
  final _secondsController = TextEditingController(text: '00');
  Timer? _ticker;
  Duration _totalDuration = const Duration(minutes: 5);
  Duration _remaining = const Duration(minutes: 5);
  DateTime? _deadline;
  bool _isRunning = false;
  bool _isFinished = false;

  @override
  void dispose() {
    _ticker?.cancel();
    _hoursController.dispose();
    _minutesController.dispose();
    _secondsController.dispose();
    super.dispose();
  }

  void _start() {
    _applyFields();
    if (_remaining <= Duration.zero) {
      return;
    }
    _deadline = DateTime.now().add(_remaining);
    _isRunning = true;
    _isFinished = false;
    _ticker ??= Timer.periodic(const Duration(milliseconds: 100), (_) {
      _updateRemaining();
    });
    setState(() {});
  }

  void _pause() {
    _updateRemaining();
    _ticker?.cancel();
    _ticker = null;
    _deadline = null;
    setState(() => _isRunning = false);
  }

  void _updateRemaining() {
    final deadline = _deadline;
    if (!_isRunning || deadline == null) {
      return;
    }
    final remaining = deadline.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      _ticker?.cancel();
      _ticker = null;
      _deadline = null;
      if (mounted) {
        setState(() {
          _remaining = Duration.zero;
          _isRunning = false;
          _isFinished = true;
        });
      }
      return;
    }
    if (mounted) {
      setState(() => _remaining = remaining);
    }
  }

  void _reset() {
    _ticker?.cancel();
    _ticker = null;
    _deadline = null;
    setState(() {
      _remaining = _totalDuration;
      _isRunning = false;
      _isFinished = false;
    });
    _syncFields(_remaining);
  }

  void _addMinute() {
    _applyFields();
    final updated = _remaining + const Duration(minutes: 1);
    _totalDuration += const Duration(minutes: 1);
    if (_isRunning) {
      _deadline = DateTime.now().add(updated);
    }
    setState(() {
      _remaining = updated;
      _isFinished = false;
    });
    _syncFields(updated);
  }

  void _choosePreset(Duration duration) {
    _ticker?.cancel();
    _ticker = null;
    _deadline = null;
    setState(() {
      _totalDuration = duration;
      _remaining = duration;
      _isRunning = false;
      _isFinished = false;
    });
    _syncFields(duration);
  }

  void _applyFields() {
    final hours = int.tryParse(_hoursController.text) ?? 0;
    final minutes = int.tryParse(_minutesController.text) ?? 0;
    final seconds = int.tryParse(_secondsController.text) ?? 0;
    final duration = Duration(
      hours: hours.clamp(0, 99),
      minutes: minutes.clamp(0, 59),
      seconds: seconds.clamp(0, 59),
    );
    _choosePreset(duration);
  }

  void _syncFields(Duration duration) {
    _hoursController.text = duration.inHours.toString().padLeft(2, '0');
    _minutesController.text = (duration.inMinutes % 60).toString().padLeft(
      2,
      '0',
    );
    _secondsController.text = (duration.inSeconds % 60).toString().padLeft(
      2,
      '0',
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  Widget _timeField({
    required TextEditingController controller,
    required String label,
    required String keyName,
  }) {
    return SizedBox(
      width: 76,
      child: TextField(
        key: ValueKey(keyName),
        controller: controller,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 2,
        onSubmitted: (_) => _applyFields(),
        decoration: InputDecoration(labelText: label, counterText: ''),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final progress = _totalDuration.inMilliseconds == 0
        ? 0.0
        : (_remaining.inMilliseconds / _totalDuration.inMilliseconds).clamp(
            0.0,
            1.0,
          );

    return Scaffold(
      appBar: AppBar(title: const Text('Timer'), actions: [widget.appMenu]),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  _timeField(
                    controller: _hoursController,
                    label: 'Hours',
                    keyName: 'timer-hours-field',
                  ),
                  _timeField(
                    controller: _minutesController,
                    label: 'Minutes',
                    keyName: 'timer-minutes-field',
                  ),
                  _timeField(
                    controller: _secondsController,
                    label: 'Seconds',
                    keyName: 'timer-seconds-field',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  for (final preset in _presets)
                    ChoiceChip(
                      key: ValueKey('timer-preset-${preset.inMinutes}'),
                      label: Text(
                        preset.inHours > 0
                            ? '${preset.inHours} hr'
                            : '${preset.inMinutes} min',
                      ),
                      selected: _totalDuration == preset && !_isRunning,
                      onSelected: (_) => _choosePreset(preset),
                    ),
                ],
              ),
              const SizedBox(height: 28),
              Semantics(
                label: _isFinished
                    ? 'Timer finished'
                    : 'Timer ${_formatDuration(_remaining)} remaining',
                liveRegion: true,
                child: SizedBox(
                  width: 260,
                  height: 260,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.square(
                        dimension: 248,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 12,
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          color: _isFinished
                              ? colorScheme.error
                              : colorScheme.primary,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isFinished
                                ? Icons.notifications_active_outlined
                                : Icons.timer_outlined,
                            color: _isFinished
                                ? colorScheme.error
                                : colorScheme.primary,
                            size: 28,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isFinished
                                ? "Time's up"
                                : _formatDuration(_remaining),
                            key: const ValueKey('timer-display'),
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    key: const ValueKey('timer-add-minute'),
                    tooltip: 'Add one minute',
                    onPressed: _addMinute,
                    icon: const Icon(Icons.add),
                  ),
                  const SizedBox(width: 20),
                  FilledButton.icon(
                    key: const ValueKey('timer-primary-action'),
                    onPressed: _isRunning
                        ? _pause
                        : (_remaining > Duration.zero ? _start : _reset),
                    icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                    label: Text(
                      _isRunning
                          ? 'Pause'
                          : (_isFinished ? 'Restart' : 'Start'),
                    ),
                  ),
                  const SizedBox(width: 20),
                  IconButton.filledTonal(
                    key: const ValueKey('timer-reset'),
                    tooltip: 'Reset timer',
                    onPressed: _reset,
                    icon: const Icon(Icons.restart_alt),
                  ),
                ],
              ),
              if (_isFinished) ...[
                const SizedBox(height: 12),
                Text(
                  'Timer finished',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
