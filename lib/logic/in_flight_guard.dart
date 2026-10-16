/// Lets an async action run one at a time.
///
/// A second call made while the first is still running is ignored, which stops
/// a double-tap on a slow action (e.g. a GPS-verified check-in that takes many
/// seconds) from running it twice. [onChange] fires when the busy state flips
/// so a widget can rebuild with a spinner / disabled button.
class InFlightGuard {
  InFlightGuard({this.onChange});

  final void Function()? onChange;
  bool _busy = false;

  bool get isBusy => _busy;

  /// Runs [action] unless one is already in flight; returns whether it ran.
  /// The guard is released when [action] finishes, however it ends (normal
  /// return, early `return`, or an exception).
  Future<bool> run(Future<void> Function() action) async {
    if (_busy) return false;
    _busy = true;
    onChange?.call();
    try {
      await action();
      return true;
    } finally {
      _busy = false;
      onChange?.call();
    }
  }
}
