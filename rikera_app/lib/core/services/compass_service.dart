import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_compass/flutter_compass.dart';

/// Service for managing compass/orientation sensor data.
///
/// Provides heading information from device sensors for map rotation.
/// Includes smoothing to prevent jerky rotation.
class CompassService {
  StreamSubscription<CompassEvent>? _compassSubscription;
  final _headingController = StreamController<double>.broadcast();
  
  /// Stream of compass heading values in degrees (0-360).
  /// 0 = North, 90 = East, 180 = South, 270 = West
  Stream<double> get headingStream => _headingController.stream;
  
  double? _lastHeading;
  Timer? _smoothingTimer;
  
  // Smoothing parameters
  final List<double> _headingBuffer = [];
  static const int _bufferSize = 5; // Number of samples to average
  static const Duration _updateInterval = Duration(milliseconds: 200); // Update every 200ms
  
  /// Get the last known heading value, or null if not available.
  double? get lastHeading => _lastHeading;
  
  /// Start listening to compass sensor updates.
  Future<void> start() async {
    if (_compassSubscription != null) {
      return; // Already started
    }
    
    _compassSubscription = FlutterCompass.events?.listen((CompassEvent event) {
      // Get heading from compass event
      final heading = event.heading;
      
      if (heading != null && !heading.isNaN) {
        // Normalize heading to 0-360 range
        final normalizedHeading = _normalizeHeading(heading);
        
        // Add to buffer for smoothing
        _addToBuffer(normalizedHeading);
      }
    });
    
    // Start smoothing timer
    _smoothingTimer = Timer.periodic(_updateInterval, (_) {
      if (_headingBuffer.isNotEmpty) {
        final smoothedHeading = _calculateSmoothedHeading();
        _lastHeading = smoothedHeading;
        _headingController.add(smoothedHeading);
      }
    });
  }
  
  /// Stop listening to compass sensor updates.
  void stop() {
    _compassSubscription?.cancel();
    _compassSubscription = null;
    _smoothingTimer?.cancel();
    _smoothingTimer = null;
    _headingBuffer.clear();
  }
  
  /// Add heading to buffer for smoothing.
  void _addToBuffer(double heading) {
    _headingBuffer.add(heading);
    
    // Keep buffer size limited
    if (_headingBuffer.length > _bufferSize) {
      _headingBuffer.removeAt(0);
    }
  }
  
  /// Calculate smoothed heading using circular mean.
  /// This handles the 0/360 degree wrap-around correctly.
  double _calculateSmoothedHeading() {
    if (_headingBuffer.isEmpty) return 0.0;
    
    // Convert to radians and calculate circular mean
    double sinSum = 0.0;
    double cosSum = 0.0;
    
    for (final heading in _headingBuffer) {
      final radians = heading * math.pi / 180.0;
      sinSum += math.sin(radians);
      cosSum += math.cos(radians);
    }
    
    final avgSin = sinSum / _headingBuffer.length;
    final avgCos = cosSum / _headingBuffer.length;
    
    // Calculate mean angle
    var meanAngle = math.atan2(avgSin, avgCos) * 180.0 / math.pi;
    
    // Normalize to 0-360
    return _normalizeHeading(meanAngle);
  }
  
  /// Normalize heading to 0-360 degree range.
  double _normalizeHeading(double heading) {
    var normalized = heading % 360;
    if (normalized < 0) {
      normalized += 360;
    }
    return normalized;
  }
  
  /// Dispose of resources.
  void dispose() {
    stop();
    _headingController.close();
  }
}
