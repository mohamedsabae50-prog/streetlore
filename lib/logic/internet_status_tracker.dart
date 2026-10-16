import 'dart:async';

/// Decides whether the app should consider itself offline.
///
/// A single failed or timed-out probe is not proof of an outage (hotel Wi-Fi,
/// 3G, a cold radio all routinely take longer than a couple of seconds), so a
/// failure leaves the status as it was — `null` ("unknown") at start-up — and
/// only [failuresBeforeOffline] consecutive failures flip it to offline. A
/// "no network interface" report from connectivity_plus is definitive and
/// goes offline immediately. Any successful probe goes back online.
class InternetStatusTracker {
  InternetStatusTracker({
    this.failuresBeforeOffline = 2,
    this.retryDelay = const Duration(seconds: 2),
    Future<void> Function(Duration)? delay,
  }) : assert(failuresBeforeOffline >= 1),
       _delay = delay ?? Future<void>.delayed;

  final int failuresBeforeOffline;
  final Duration retryDelay;
  final Future<void> Function(Duration) _delay;

  bool? _status;
  int _failures = 0;

  /// `true` online, `false` offline, `null` not yet known. Only `false` should
  /// ever block the UI.
  bool? get status => _status;

  int get consecutiveFailures => _failures;

  /// connectivity_plus reports no network interface at all.
  bool? recordNoNetwork() {
    _failures = failuresBeforeOffline;
    return _status = false;
  }

  /// Records the outcome of one reachability probe and returns the new status.
  bool? recordProbe({required bool reachable}) {
    if (reachable) {
      _failures = 0;
      return _status = true;
    }
    if (_failures < failuresBeforeOffline) _failures++;
    if (_failures >= failuresBeforeOffline) _status = false;
    return _status;
  }

  /// Probes, and after a failure re-probes (after [retryDelay]) until either
  /// one succeeds or [failuresBeforeOffline] consecutive probes have failed.
  /// Returns the resulting [status].
  Future<bool?> check(Future<bool> Function() probe) async {
    while (true) {
      recordProbe(reachable: await probe());
      if (_failures == 0 || _failures >= failuresBeforeOffline) break;
      await _delay(retryDelay);
    }
    return _status;
  }
}
