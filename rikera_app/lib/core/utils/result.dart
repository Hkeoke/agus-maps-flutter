/// A type that represents either a success with a value or a failure with an error.
///
/// This is used throughout the application to handle operations that can fail
/// in a type-safe way without throwing exceptions.
sealed class Result<T> {
  const Result();

  /// Creates a successful result with the given value.
  factory Result.success(T value) = Success<T>;

  /// Creates a failed result with the given error.
  factory Result.failure(AppError error) = Failure<T>;

  /// Returns true if this is a success result.
  bool get isSuccess => this is Success<T>;

  /// Returns true if this is a failure result.
  bool get isFailure => this is Failure<T>;

  /// Returns the value if this is a success, or null if this is a failure.
  T? get valueOrNull => switch (this) {
    Success(value: final v) => v,
    Failure() => null,
  };

  /// Returns the error if this is a failure, or null if this is a success.
  AppError? get errorOrNull => switch (this) {
    Success() => null,
    Failure(error: final e) => e,
  };

  /// Transforms the value if this is a success, otherwise returns the failure.
  Result<R> map<R>(R Function(T value) transform) {
    return switch (this) {
      Success(value: final v) => Result.success(transform(v)),
      Failure(error: final e) => Result.failure(e),
    };
  }

  /// Transforms the value if this is a success, otherwise returns the failure.
  /// The transform function returns a Result, allowing for chaining operations.
  Result<R> flatMap<R>(Result<R> Function(T value) transform) {
    return switch (this) {
      Success(value: final v) => transform(v),
      Failure(error: final e) => Result.failure(e),
    };
  }

  /// Executes the appropriate callback based on whether this is a success or failure.
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(AppError error) onFailure,
  }) {
    return switch (this) {
      Success(value: final v) => onSuccess(v),
      Failure(error: final e) => onFailure(e),
    };
  }
}

/// A successful result containing a value.
final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T> &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Success($value)';
}

/// A failed result containing an error.
final class Failure<T> extends Result<T> {
  const Failure(this.error);

  final AppError error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure<T> &&
          runtimeType == other.runtimeType &&
          error == other.error;

  @override
  int get hashCode => error.hashCode;

  @override
  String toString() => 'Failure($error)';
}

/// Base class for all application errors.
abstract class AppError {
  const AppError({required this.message, this.code, this.stackTrace});

  final String message;
  final String? code;
  final StackTrace? stackTrace;

  @override
  String toString() => 'AppError(code: $code, message: $message)';
}
