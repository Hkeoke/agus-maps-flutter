import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rikera_app/core/services/haptic_feedback_service.dart';
import 'package:rikera_app/core/services/voice_guidance_service.dart';
import 'package:rikera_app/features/map/data/repositories/navigation_repository_impl.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';
import 'package:rikera_app/features/map/domain/repositories/repositories.dart';
import 'package:rikera_app/features/map/domain/usecases/usecases.dart';
import 'package:rikera_app/features/settings/domain/repositories/settings_repository.dart';
import 'navigation_event.dart';
import 'navigation_bloc_state.dart';

/// Bloc for managing navigation sessions.
///
/// This bloc handles:
/// - Starting and stopping navigation
/// - Processing location updates during navigation
/// - Detecting off-route conditions
/// - Detecting arrival at destination
/// - Triggering voice guidance at turn points
/// - Providing haptic feedback for navigation events
///
/// Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.7
class NavigationBloc extends Bloc<NavigationEvent, NavigationBlocState> {
  final StartNavigationUseCase _startNavigationUseCase;
  final NavigationRepository _navigationRepository;
  final TrackLocationUseCase _trackLocationUseCase;
  final VoiceGuidanceService _voiceGuidanceService;
  final HapticFeedbackService _hapticFeedbackService;
  final SettingsRepository _settingsRepository;

  StreamSubscription<NavigationState>? _navigationStateSubscription;
  StreamSubscription<Location>? _locationSubscription;

  // Threshold distance for arrival detection (meters)
  static const double _arrivalThresholdMeters = 50.0;

  // Threshold distance for voice guidance (meters)
  static const double _voiceGuidanceThresholdMeters = 500.0;
  static const double _voiceGuidanceSecondThresholdMeters = 100.0;

  // Track which turns have been announced to avoid repeating
  final Set<int> _announcedTurns = {};

  NavigationBloc({
    required StartNavigationUseCase startNavigationUseCase,
    required NavigationRepository navigationRepository,
    required TrackLocationUseCase trackLocationUseCase,
    required VoiceGuidanceService voiceGuidanceService,
    required HapticFeedbackService hapticFeedbackService,
    required SettingsRepository settingsRepository,
  }) : _startNavigationUseCase = startNavigationUseCase,
       _navigationRepository = navigationRepository,
       _trackLocationUseCase = trackLocationUseCase,
       _voiceGuidanceService = voiceGuidanceService,
       _hapticFeedbackService = hapticFeedbackService,
       _settingsRepository = settingsRepository,
       super(const NavigationIdle()) {
    on<StartNavigation>(_onStartNavigation);
    on<UpdateLocation>(_onUpdateLocation);
    on<StopNavigation>(_onStopNavigation);
  }

  /// Handles the StartNavigation event.
  ///
  /// This starts a navigation session with the given route, enabling
  /// location tracking and subscribing to navigation state updates.
  ///
  /// Requirements: 6.1, 14.1
  Future<void> _onStartNavigation(
    StartNavigation event,
    Emitter<NavigationBlocState> emit,
  ) async {
    try {
      // Inject map controller into navigation repository if available
      if (_navigationRepository is NavigationRepositoryImpl && event.mapController != null) {
        (_navigationRepository as NavigationRepositoryImpl).setMapController(event.mapController!);
      }
      
      // Inject map controller into voice guidance service
      if (_voiceGuidanceService is VoiceGuidanceService && event.mapController != null) {
        // Voice guidance will use native notifications when controller is available
        // The service already has the controller from initialization
      }

      // Start navigation using the use case
      final result = await _startNavigationUseCase.execute(event.route);

      if (result.isFailure) {
        emit(NavigationError(result.errorOrNull?.message ?? 'Unknown error'));
        return;
      }

      // Clear announced turns for new navigation session
      _announcedTurns.clear();

      // Get voice guidance settings and apply them
      final settingsResult = await _settingsRepository.getSettings();
      if (settingsResult.isSuccess) {
        final settings = settingsResult.valueOrNull!;
        // Enable service - this starts the native notification polling
        _voiceGuidanceService.setEnabled(settings.voiceGuidanceEnabled);
      } else {
        // Default to enabled if settings fail
        _voiceGuidanceService.setEnabled(true);
      }

      // Subscribe to navigation state updates
      _navigationStateSubscription = _navigationRepository
          .getNavigationState()
          .listen(
            (navigationState) {
              _handleNavigationStateUpdate(navigationState);
            },
            onError: (error) {
              add(const StopNavigation());
              emit(NavigationError('Navigation error: $error'));
            },
          );

      // Subscribe to location updates
      _locationSubscription = _trackLocationUseCase.execute().listen(
        (location) {
          add(UpdateLocation(location));
        },
        onError: (error) {
          // Location errors are handled but don't stop navigation
          // The navigation state will handle missing location updates
        },
      );
    } catch (e) {
      emit(NavigationError('Failed to start navigation: $e'));
    }
  }

  /// Handles navigation state updates from the repository.
  ///
  /// This processes state changes to:
  /// - Detect off-route conditions
  /// - Detect arrival at destination
  /// - Trigger voice guidance at turn points
  ///
  /// Requirements: 6.2, 6.3, 6.4, 6.5, 6.7, 14.2
  void _handleNavigationStateUpdate(NavigationState navigationState) {
    // Check for arrival
    if (navigationState.remainingDistanceMeters <= _arrivalThresholdMeters) {
      _voiceGuidanceService.announceArrival();
      _hapticFeedbackService.vibrateArrival(); // Haptic feedback on arrival
      add(const StopNavigation());
      emit(NavigationArrived(navigationState.currentLocation));
      return;
    }

    // Check for off-route condition
    if (navigationState.isOffRoute) {
      _voiceGuidanceService.announceRerouting();
      _hapticFeedbackService.vibrateOffRoute(); // Haptic feedback on off-route
      emit(NavigationOffRoute(navigationState));
      return;
    }

    // Voice guidance is handled by VoiceGuidanceService polling native notifications
    // We don't need manual distance checks here anymore
    // _checkVoiceGuidance(navigationState);

    // Emit normal navigating state
    emit(NavigationNavigating(navigationState));
  }

  /// Checks if voice guidance should be triggered based on distance to turn.
  ///
  /// Voice announcements are made at:
  /// - 500m before turn (first announcement)
  /// - 100m before turn (second announcement)
  /// - At the turn point (final announcement)
  ///
  /// Requirements: 6.3, 14.2
  void _checkVoiceGuidance(NavigationState navigationState) {
    if (navigationState.nextSegment == null) return;

    final distanceToTurn = navigationState.distanceToNextTurnMeters;
    final nextSegment = navigationState.nextSegment!;
    final segmentIndex = navigationState.route.segments.indexOf(nextSegment);

    // First announcement at 500m
    if (distanceToTurn <= _voiceGuidanceThresholdMeters &&
        distanceToTurn > _voiceGuidanceSecondThresholdMeters &&
        !_announcedTurns.contains(segmentIndex * 3)) {
      _announcedTurns.add(segmentIndex * 3);
      _voiceGuidanceService.announceTurn(
        direction: nextSegment.turnDirection,
        distanceMeters: distanceToTurn,
        streetName: nextSegment.streetName,
      );
    }

    // Second announcement at 100m
    if (distanceToTurn <= _voiceGuidanceSecondThresholdMeters &&
        distanceToTurn > 10 &&
        !_announcedTurns.contains(segmentIndex * 3 + 1)) {
      _announcedTurns.add(segmentIndex * 3 + 1);
      _voiceGuidanceService.announceTurn(
        direction: nextSegment.turnDirection,
        distanceMeters: distanceToTurn,
        streetName: nextSegment.streetName,
      );
      _hapticFeedbackService
          .vibrateTurnApproach(); // Haptic feedback on turn approach
    }

    // Final announcement at turn point
    if (distanceToTurn <= 10 &&
        !_announcedTurns.contains(segmentIndex * 3 + 2)) {
      _announcedTurns.add(segmentIndex * 3 + 2);
      _voiceGuidanceService.announceTurn(
        direction: nextSegment.turnDirection,
        distanceMeters: distanceToTurn,
        streetName: nextSegment.streetName,
      );
    }
  }

  /// Handles the UpdateLocation event.
  ///
  /// This updates the navigation repository with the new location,
  /// which triggers recalculation of navigation state.
  ///
  /// Requirements: 6.2, 6.4
  Future<void> _onUpdateLocation(
    UpdateLocation event,
    Emitter<NavigationBlocState> emit,
  ) async {
    if (!_navigationRepository.isNavigating) return;

    try {
      await _navigationRepository.updateLocation(event.location);
    } catch (e) {
      // Location update errors are logged but don't stop navigation
      // The navigation will continue with the last known good location
    }
  }

  /// Handles the StopNavigation event.
  ///
  /// This ends the navigation session, cancels subscriptions,
  /// stops voice guidance, and returns to idle state.
  ///
  /// Requirements: 6.7
  Future<void> _onStopNavigation(
    StopNavigation event,
    Emitter<NavigationBlocState> emit,
  ) async {
    try {
      // Cancel subscriptions
      await _navigationStateSubscription?.cancel();
      await _locationSubscription?.cancel();
      _navigationStateSubscription = null;
      _locationSubscription = null;

      // Stop navigation in repository
      await _navigationRepository.stopNavigation();

      // Stop voice guidance
      await _voiceGuidanceService.stop();

      // Clear announced turns
      _announcedTurns.clear();

      // Return to idle state
      emit(const NavigationIdle());
    } catch (e) {
      emit(NavigationError('Failed to stop navigation: $e'));
    }
  }

  @override
  Future<void> close() async {
    await _navigationStateSubscription?.cancel();
    await _locationSubscription?.cancel();
    await _voiceGuidanceService.dispose();
    return super.close();
  }
}
