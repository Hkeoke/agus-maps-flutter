import 'dart:developer' as developer;

/// A simple logger utility for the application.
///
/// This logger wraps the dart:developer log function to provide
/// consistent logging across the application with proper error
/// and stack trace handling.
///
/// Requirements: 13.4
class AppLogger {
  final String _name;

  const AppLogger(this._name);

  /// Logs a debug message.
  void debug(String message) {
    developer.log(
      message,
      name: _name,
      level: 500, // Debug level
    );
  }

  /// Logs an info message.
  void info(String message) {
    developer.log(
      message,
      name: _name,
      level: 800, // Info level
    );
  }

  /// Logs a warning message.
  void warning(String message) {
    developer.log(
      message,
      name: _name,
      level: 900, // Warning level
    );
  }

  /// Logs an error message with optional error object and stack trace.
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      message,
      name: _name,
      level: 1000, // Error level
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Logs a fatal error message with optional error object and stack trace.
  void fatal(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      message,
      name: _name,
      level: 1200, // Fatal level
      error: error,
      stackTrace: stackTrace,
    );
  }
}
