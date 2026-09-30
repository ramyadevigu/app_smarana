import 'dart:async';

class NoteEditorAutosaveService {
  NoteEditorAutosaveService({this.delay = const Duration(milliseconds: 700)});

  final Duration delay;
  Timer? _timer;
  Future<void> _saveQueue = Future<void>.value();

  void queue(Future<void> Function() saveOperation) {
    _timer?.cancel();
    _timer = Timer(delay, () {
      unawaited(_runSerialized(saveOperation));
    });
  }

  Future<void> flush(Future<void> Function() saveOperation) async {
    _timer?.cancel();
    await _runSerialized(saveOperation);
  }

  void dispose() {
    _timer?.cancel();
  }

  Future<void> _runSerialized(Future<void> Function() saveOperation) {
    final save = _saveQueue.then((_) => saveOperation());
    _saveQueue = save.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return save;
  }
}
