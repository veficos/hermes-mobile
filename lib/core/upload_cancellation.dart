/// Cooperative cancellation for an in-flight attachment upload.
class UploadCancellation {
  bool _cancelled = false;
  void Function()? _onCancel;
  bool get isCancelled => _cancelled;
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _onCancel?.call();
  }

  void bind(void Function() callback) {
    _onCancel = callback;
    if (_cancelled) callback();
  }
}
