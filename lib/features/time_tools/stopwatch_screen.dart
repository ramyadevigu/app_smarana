import 'dart:async';

import 'package:flutter/material.dart';

class StopwatchScreen extends StatefulWidget {
  const StopwatchScreen({super.key, required this.appMenu});

  final Widget appMenu;

  @override
  State<StopwatchScreen> createState() => _StopwatchScreenState();
}

class _StopwatchScreenState extends State<StopwatchScreen> {
  final Stopwatch _stopwatch = Stopwatch();
  final List<Duration> _laps = [];
  Timer? _ticker;

  bool get _isRunning => _stopwatch.isRunning;
  bool get _hasElapsed => _stopwatch.elapsed > Duration.zero;

  @override
  void dispose() {
    _ticker?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  void _start() {
    _stopwatch.start();
    _ticker ??= Timer.periodic(const Duration(milliseconds: 30), (_) {
      if (mounted) {
        setState(() {});
      }
    });
    setState(() {});
  }

  void _pause() {
    _stopwatch.stop();
    setState(() {});
  }

  void _lap() {
    if (!_isRunning) {
      return;
    }
    _laps.insert(0, _stopwatch.elapsed);
    setState(() {});
  }

  void _reset() {
    _stopwatch
      ..stop()
      ..reset();
    _laps.clear();
    setState(() {});
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    final hundredths = (duration.inMilliseconds % 1000 ~/ 10)
        .toString()
        .padLeft(2, '0');
    return '$hours:$minutes:$seconds.$hundredths';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Stopwatch'), actions: [widget.appMenu]),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: Semantics(
                          label:
                              'Elapsed time ${_formatDuration(_stopwatch.elapsed)}',
                          liveRegion: true,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _formatDuration(_stopwatch.elapsed),
                              key: const ValueKey('stopwatch-display'),
                              style: theme.textTheme.displayMedium?.copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                                fontWeight: FontWeight.w300,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_laps.isNotEmpty) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Laps', style: theme.textTheme.titleMedium),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 180,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListView.separated(
                            key: const ValueKey('stopwatch-laps'),
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: _laps.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) => ListTile(
                              dense: true,
                              leading: Text('Lap ${_laps.length - index}'),
                              trailing: Text(
                                _formatDuration(_laps[index]),
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('stopwatch-secondary-action'),
                      onPressed: _isRunning
                          ? _lap
                          : (_hasElapsed ? _reset : null),
                      icon: Icon(
                        _isRunning ? Icons.flag_outlined : Icons.restart_alt,
                      ),
                      label: Text(_isRunning ? 'Lap' : 'Reset'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('stopwatch-primary-action'),
                      onPressed: _isRunning ? _pause : _start,
                      icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                      label: Text(_isRunning ? 'Pause' : 'Start'),
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
}
