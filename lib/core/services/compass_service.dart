import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';

class CompassService {
  CompassService._();
  static final CompassService instance = CompassService._();

  StreamSubscription<CompassEvent>? _subscription;
  Timer? _staleTimer;
  double _heading = 0;
  double _smoothedHeading = 0;
  bool _eventsExist = false;
  bool _firstEventReceived = false;
  DateTime _lastUpdateAt = DateTime.fromMillisecondsSinceEpoch(0);

  double get heading => _smoothedHeading;
  double get rawHeading => _heading;
  bool get isAvailable => _eventsExist;
  bool get isActuallyWorking => _firstEventReceived &&
      DateTime.now().difference(_lastUpdateAt).inSeconds < 4;

  Stream<double> get headingStream => _controller.stream;

  final _controller = StreamController<double>.broadcast();

  void start() {
    if (_subscription != null) return;
    final events = FlutterCompass.events;
    if (events == null) {
      _eventsExist = false;
      return;
    }
    _eventsExist = true;
    _subscription = events.listen(
      (event) {
        final h = event.heading;
        if (h == null) return;
        _firstEventReceived = true;
        _heading = h;
        _smoothedHeading = _smoothAngle(_smoothedHeading, h);
        _lastUpdateAt = DateTime.now();
        if (!_controller.isClosed) {
          _controller.add(_smoothedHeading);
        }
      },
      onError: (e) {
        debugPrint('CompassService: stream error: $e');
      },
      cancelOnError: false,
    );
    _staleTimer?.cancel();
    _staleTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!_firstEventReceived) return;
      final sinceUpdate = DateTime.now().difference(_lastUpdateAt);
      if (sinceUpdate.inSeconds >= 4 && !_controller.isClosed) {
        _controller.add(_smoothedHeading);
      }
    });
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _staleTimer?.cancel();
    _staleTimer = null;
  }

  double _smoothAngle(double from, double to) {
    double diff = to - from;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return (from + diff) % 360;
  }
}
