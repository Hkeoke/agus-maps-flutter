import 'package:rikera_app/features/map/domain/entities/entities.dart';

/// Base class for bookmark states.
abstract class BookmarkState {
  const BookmarkState();
}

/// Initial state before bookmarks have been loaded.
class BookmarkInitial extends BookmarkState {
  const BookmarkInitial();

  @override
  bool operator ==(Object other) => other is BookmarkInitial;

  @override
  int get hashCode => 0;
}

/// State when loading bookmarks from storage.
class BookmarkLoading extends BookmarkState {
  const BookmarkLoading();

  @override
  bool operator ==(Object other) => other is BookmarkLoading;

  @override
  int get hashCode => 1;
}

/// State when bookmarks have been successfully loaded.
///
/// This state contains the list of bookmarks, optionally filtered by category.
///
/// Requirements: 16.1, 16.3, 16.9
class BookmarkLoaded extends BookmarkState {
  final List<Bookmark> bookmarks;
  final BookmarkCategory? filterCategory;

  const BookmarkLoaded({required this.bookmarks, this.filterCategory});

  /// Alias for filterCategory for UI compatibility
  BookmarkCategory? get selectedCategory => filterCategory;

  /// Returns bookmarks filtered by the current category filter
  List<Bookmark> get filteredBookmarks {
    if (filterCategory == null) {
      return bookmarks;
    }
    return bookmarks.where((b) => b.category == filterCategory).toList();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BookmarkLoaded &&
        _listEquals(other.bookmarks, bookmarks) &&
        other.filterCategory == filterCategory;
  }

  @override
  int get hashCode => bookmarks.hashCode ^ filterCategory.hashCode;

  @override
  String toString() =>
      'BookmarkLoaded(count: ${bookmarks.length}, filter: $filterCategory)';

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// State when saving a bookmark.
///
/// This state is emitted while a bookmark save operation is in progress.
///
/// Requirements: 16.2, 16.6
class BookmarkSaving extends BookmarkState {
  final List<Bookmark> bookmarks;
  final BookmarkCategory? filterCategory;

  const BookmarkSaving({required this.bookmarks, this.filterCategory});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BookmarkSaving &&
        _listEquals(other.bookmarks, bookmarks) &&
        other.filterCategory == filterCategory;
  }

  @override
  int get hashCode => bookmarks.hashCode ^ filterCategory.hashCode;

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// State when a bookmark operation fails.
class BookmarkError extends BookmarkState {
  final String message;
  final List<Bookmark> bookmarks;
  final BookmarkCategory? filterCategory;

  const BookmarkError({
    required this.message,
    required this.bookmarks,
    this.filterCategory,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BookmarkError && other.message == message;
  }

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => 'BookmarkError($message)';
}
