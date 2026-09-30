import 'dart:async';

class NoteEditorAutosaveService {
  NoteEditorAutosaveService({this.delay = const Duration(milliseconds: 700)});

  final Duration delay;
  Timer? _timer;

  void queue(Future<void> Function() saveOperation) {
    _timer?.cancel();
    _timer = Timer(delay, () {
      unawaited(saveOperation());
    });
  }

  Future<void> flush(Future<void> Function() saveOperation) async {
    _timer?.cancel();
    await saveOperation();
  }

  void dispose() {
    _timer?.cancel();
  }
}
