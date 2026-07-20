import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';

class CompassService {
  CompassService._();
  static final CompassService instance = CompassService._();

  StreamSubscription<CompassEvent>? _subscription;
  double _heading = 0;
  double _smoothedHeading = 0;
  bool _available = false;

  double get heading => _smoothedHeading;
  double get rawHeading => _heading;
  bool get isAvailable => _available;

  Stream<double> get headingStream => _controller.stream;

  final _controller = StreamController<double>.broadcast();

  void start() {
    if (_subscription != null) return;
    final events = FlutterCompass.events;
    if (events == null) {
      _available = false;
      return;
    }
    _available = true;
    _subscription = events.listen(
      (event) {
        final h = event.heading;
        if (h == null) return;
        _heading = h;
        _smoothedHeading = _smoothAngle(_smoothedHeading, h);
        if (!_controller.isClosed) {
          _controller.add(_smoothedHeading);
        }
      },
      onError: (e) {
        debugPrint('CompassService: stream error: $e');
      },
      cancelOnError: false,
    );
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }

  double _smoothAngle(double from, double to) {
    double diff = to - from;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return (from + diff) % 360;
  }
}
