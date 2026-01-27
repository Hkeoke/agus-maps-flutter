/// Exception thrown when map engine operations fail.
class MapEngineException implements Exception {
  final String message;
  final dynamic originalError;
  final StackTrace? stackTrace;

  MapEngineException(
    this.message, {
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() {
    if (originalError != null) {
      return 'MapEngineException: $message (caused by: $originalError)';
    }
    return 'MapEngineException: $message';
  }
}
