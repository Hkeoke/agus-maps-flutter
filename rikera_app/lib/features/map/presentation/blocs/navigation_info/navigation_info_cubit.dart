import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:agus_maps_flutter/agus_maps_flutter.dart';
import 'package:rikera_app/core/utils/logger.dart';
import 'navigation_info_state.dart';

/// Simple Cubit for polling navigation info from the motor.
/// 
/// The motor (C++ engine) handles everything:
/// - Route building
/// - Navigation mode activation
/// - Real-time calculations
/// 
/// This cubit just READS the data and displays it.
/// 
/// IMPORTANT: Navigation stays active even when user moves the map
/// (mode changes from 4 to 3), so we check routing status, not mode!
class NavigationInfoCubit extends Cubit<NavigationInfoState> {
  final AppLogger _logger = const AppLogger('NavigationInfoCubit');
  AgusMapController? _mapController;
  Timer? _pollTimer;
  bool _isNavigating = false;

  NavigationInfoCubit() : super(const NavigationInfoIdle());

  /// Set the map controller
  void setMapController(AgusMapController controller) {
    _logger.info('Map controller set');
    _mapController = controller;
  }

  /// Start navigation - called when route is built
  void startNavigation() {
    if (_isNavigating) {
      _logger.info('Navigation already active');
      return;
    }
    
    _logger.info('Starting navigation');
    _isNavigating = true;
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) => _poll());
    _logger.info('Polling started');
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _isNavigating = false;
    emit(const NavigationInfoIdle());
    _logger.info('Polling stopped, navigation ended');
  }

  Future<void> _poll() async {
    if (_mapController == null || !_isNavigating) return;

    try {
      // Check if route is finished
      final isFinished = await _mapController!.isRouteFinished();
      if (isFinished) {
        _logger.info('Route finished');
        _stopPolling();
        return;
      }

      // Get navigation info from motor
      final info = await _mapController!.getRouteFollowingInfo();
      if (info != null) {
        _logger.debug('Navigation info: $info');
        emit(NavigationInfoActive(info));
      } else {
        // No info means routing is not active anymore
        _logger.info('No navigation info available, stopping');
        _stopPolling();
      }
    } catch (e, stackTrace) {
      _logger.error('Error polling navigation info', error: e, stackTrace: stackTrace);
    }
  }

  /// Stop navigation - calls motor's stopRouting
  Future<void> stopNavigation() async {
    if (_mapController == null) return;
    
    _logger.info('Stopping navigation');
    try {
      await _mapController!.stopRouting();
      _stopPolling();
    } catch (e, stackTrace) {
      _logger.error('Error stopping navigation', error: e, stackTrace: stackTrace);
    }
  }

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    return super.close();
  }
}
