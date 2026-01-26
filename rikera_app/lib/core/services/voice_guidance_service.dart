import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';

/// Service for providing voice guidance during navigation.
///
/// This service wraps text-to-speech functionality and provides:
/// - Voice announcements for turn-by-turn navigation
/// - Support for multiple languages
/// - Announcement queueing to prevent overlapping speech
/// - Enable/disable voice guidance
///
/// Requirements: 14.2, 14.3, 14.5
class VoiceGuidanceService {
  final FlutterTts _tts;
  final List<String> _announcementQueue = [];
  bool _isSpeaking = false;
  bool _isEnabled = true;
  String _currentLanguage = 'en-US';

  VoiceGuidanceService({FlutterTts? tts}) : _tts = tts ?? FlutterTts() {
    _initializeTts();
  }

  /// Initializes the text-to-speech engine with default settings.
  Future<void> _initializeTts() async {
    await _tts.setLanguage(_currentLanguage);
    await _tts.setSpeechRate(0.5); // Slightly slower for clarity while driving
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    // Set up completion handler to process queue
    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      _processQueue();
    });

    // Set up error handler
    _tts.setErrorHandler((message) {
      _isSpeaking = false;
      _processQueue();
    });
  }

  /// Enables or disables voice guidance.
  ///
  /// When disabled, announcements are not spoken but the queue is still processed.
  ///
  /// Requirements: 14.4
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (!enabled && _isSpeaking) {
      _tts.stop();
      _isSpeaking = false;
      _announcementQueue.clear();
    }
  }

  /// Gets the current enabled state.
  bool get isEnabled => _isEnabled;

  /// Sets the language for voice guidance.
  ///
  /// Supported languages include:
  /// - 'en-US' (English - US)
  /// - 'en-GB' (English - UK)
  /// - 'es-ES' (Spanish - Spain)
  /// - 'fr-FR' (French)
  /// - 'de-DE' (German)
  /// - 'it-IT' (Italian)
  /// - 'pt-PT' (Portuguese)
  ///
  /// Requirements: 14.3
  Future<void> setLanguage(String languageCode) async {
    _currentLanguage = languageCode;
    await _tts.setLanguage(languageCode);
  }

  /// Gets the current language code.
  String get currentLanguage => _currentLanguage;

  /// Announces a turn instruction with direction and distance.
  ///
  /// This is the main method for turn-by-turn voice guidance.
  /// The announcement is queued and spoken when the TTS engine is ready.
  ///
  /// Requirements: 6.3, 14.2
  void announceTurn({
    required TurnDirection direction,
    required double distanceMeters,
    String? streetName,
  }) {
    if (!_isEnabled) return;

    final announcement = _buildTurnAnnouncement(
      direction: direction,
      distanceMeters: distanceMeters,
      streetName: streetName,
    );

    _queueAnnouncement(announcement);
  }

  /// Announces arrival at the destination.
  ///
  /// Requirements: 6.7
  void announceArrival() {
    if (!_isEnabled) return;
    _queueAnnouncement('You have arrived at your destination');
  }

  /// Announces that the route is being recalculated.
  ///
  /// Requirements: 6.5
  void announceRerouting() {
    if (!_isEnabled) return;
    _queueAnnouncement('Recalculating route');
  }

  /// Builds a natural language announcement for a turn instruction.
  String _buildTurnAnnouncement({
    required TurnDirection direction,
    required double distanceMeters,
    String? streetName,
  }) {
    final distance = _formatDistance(distanceMeters);
    final turnInstruction = _getTurnInstruction(direction);

    if (streetName != null && streetName.isNotEmpty) {
      return 'In $distance, $turnInstruction onto $streetName';
    } else {
      return 'In $distance, $turnInstruction';
    }
  }

  /// Formats distance in a human-readable way.
  String _formatDistance(double meters) {
    if (meters < 50) {
      return 'now';
    } else if (meters < 100) {
      return '50 meters';
    } else if (meters < 200) {
      return '100 meters';
    } else if (meters < 400) {
      return '200 meters';
    } else if (meters < 600) {
      return '500 meters';
    } else if (meters < 1000) {
      return '${(meters / 100).round() * 100} meters';
    } else {
      final km = (meters / 1000).toStringAsFixed(1);
      return '$km kilometers';
    }
  }

  /// Converts turn direction enum to natural language instruction.
  String _getTurnInstruction(TurnDirection direction) {
    switch (direction) {
      case TurnDirection.straight:
        return 'continue straight';
      case TurnDirection.slightLeft:
        return 'turn slightly left';
      case TurnDirection.left:
        return 'turn left';
      case TurnDirection.sharpLeft:
        return 'turn sharply left';
      case TurnDirection.uTurnLeft:
        return 'make a U-turn';
      case TurnDirection.slightRight:
        return 'turn slightly right';
      case TurnDirection.right:
        return 'turn right';
      case TurnDirection.sharpRight:
        return 'turn sharply right';
      case TurnDirection.uTurnRight:
        return 'make a U-turn';
      case TurnDirection.roundabout:
        return 'enter the roundabout';
      case TurnDirection.exitRoundabout:
        return 'exit the roundabout';
      case TurnDirection.destination:
        return 'arrive at your destination';
    }
  }

  /// Queues an announcement to be spoken.
  void _queueAnnouncement(String text) {
    _announcementQueue.add(text);
    if (!_isSpeaking) {
      _processQueue();
    }
  }

  /// Processes the announcement queue.
  Future<void> _processQueue() async {
    if (_announcementQueue.isEmpty || _isSpeaking || !_isEnabled) {
      return;
    }

    _isSpeaking = true;
    final announcement = _announcementQueue.removeAt(0);

    try {
      await _tts.speak(announcement);
    } catch (e) {
      // If speaking fails, mark as not speaking and try next in queue
      _isSpeaking = false;
      _processQueue();
    }
  }

  /// Stops any current speech and clears the queue.
  Future<void> stop() async {
    _announcementQueue.clear();
    if (_isSpeaking) {
      await _tts.stop();
      _isSpeaking = false;
    }
  }

  /// Disposes of the service and releases resources.
  Future<void> dispose() async {
    await stop();
  }
}
