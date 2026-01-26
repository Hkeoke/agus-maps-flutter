import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';
import 'package:rikera_app/features/map/domain/usecases/usecases.dart';
import 'bookmark_event.dart';
import 'bookmark_state.dart';

/// Bloc for managing bookmarks.
///
/// This bloc handles:
/// - Loading bookmarks from storage
/// - Saving new bookmarks
/// - Updating existing bookmarks
/// - Deleting bookmarks
/// - Filtering bookmarks by category
///
/// Requirements: 16.1, 16.2, 16.3, 16.6, 16.7, 16.9
class BookmarkBloc extends Bloc<BookmarkEvent, BookmarkState> {
  final GetBookmarksUseCase _getBookmarksUseCase;
  final SaveBookmarkUseCase _saveBookmarkUseCase;
  final DeleteBookmarkUseCase _deleteBookmarkUseCase;

  BookmarkBloc({
    required GetBookmarksUseCase getBookmarksUseCase,
    required SaveBookmarkUseCase saveBookmarkUseCase,
    required DeleteBookmarkUseCase deleteBookmarkUseCase,
  }) : _getBookmarksUseCase = getBookmarksUseCase,
       _saveBookmarkUseCase = saveBookmarkUseCase,
       _deleteBookmarkUseCase = deleteBookmarkUseCase,
       super(const BookmarkInitial()) {
    on<LoadBookmarks>(_onLoadBookmarks);
    on<SaveBookmark>(_onSaveBookmark);
    on<UpdateBookmark>(_onUpdateBookmark);
    on<DeleteBookmark>(_onDeleteBookmark);
    on<FilterByCategory>(_onFilterByCategory);
  }

  /// Handles the LoadBookmarks event.
  ///
  /// This loads all bookmarks from storage.
  ///
  /// Requirements: 16.1, 16.3
  Future<void> _onLoadBookmarks(
    LoadBookmarks event,
    Emitter<BookmarkState> emit,
  ) async {
    emit(const BookmarkLoading());

    try {
      // Get current filter if any
      final currentFilter = _getCurrentFilter();

      // Load bookmarks
      final result = await _getBookmarksUseCase.execute(
        category: currentFilter,
      );

      if (result.isSuccess) {
        emit(
          BookmarkLoaded(
            bookmarks: result.valueOrNull ?? [],
            filterCategory: currentFilter,
          ),
        );
      } else {
        emit(
          BookmarkError(
            message: result.errorOrNull?.message ?? 'Unknown error',
            bookmarks: const [],
            filterCategory: currentFilter,
          ),
        );
      }
    } catch (e) {
      emit(
        BookmarkError(
          message: 'Failed to load bookmarks: $e',
          bookmarks: const [],
        ),
      );
    }
  }

  /// Handles the SaveBookmark event.
  ///
  /// This saves a new bookmark to storage.
  ///
  /// Requirements: 16.2
  Future<void> _onSaveBookmark(
    SaveBookmark event,
    Emitter<BookmarkState> emit,
  ) async {
    final currentBookmarks = _getCurrentBookmarks();
    final currentFilter = _getCurrentFilter();

    emit(
      BookmarkSaving(
        bookmarks: currentBookmarks,
        filterCategory: currentFilter,
      ),
    );

    try {
      final result = await _saveBookmarkUseCase.execute(event.bookmark);

      if (result.isSuccess) {
        // Reload bookmarks to reflect the new bookmark
        add(const LoadBookmarks());
      } else {
        emit(
          BookmarkError(
            message: result.errorOrNull?.message ?? 'Unknown error',
            bookmarks: currentBookmarks,
            filterCategory: currentFilter,
          ),
        );
      }
    } catch (e) {
      emit(
        BookmarkError(
          message: 'Failed to save bookmark: $e',
          bookmarks: currentBookmarks,
          filterCategory: currentFilter,
        ),
      );
    }
  }

  /// Handles the UpdateBookmark event.
  ///
  /// This updates an existing bookmark in storage.
  ///
  /// Requirements: 16.6
  Future<void> _onUpdateBookmark(
    UpdateBookmark event,
    Emitter<BookmarkState> emit,
  ) async {
    final currentBookmarks = _getCurrentBookmarks();
    final currentFilter = _getCurrentFilter();

    emit(
      BookmarkSaving(
        bookmarks: currentBookmarks,
        filterCategory: currentFilter,
      ),
    );

    try {
      final result = await _saveBookmarkUseCase.execute(event.bookmark);

      if (result.isSuccess) {
        // Reload bookmarks to reflect the update
        add(const LoadBookmarks());
      } else {
        emit(
          BookmarkError(
            message: result.errorOrNull?.message ?? 'Unknown error',
            bookmarks: currentBookmarks,
            filterCategory: currentFilter,
          ),
        );
      }
    } catch (e) {
      emit(
        BookmarkError(
          message: 'Failed to update bookmark: $e',
          bookmarks: currentBookmarks,
          filterCategory: currentFilter,
        ),
      );
    }
  }

  /// Handles the DeleteBookmark event.
  ///
  /// This deletes a bookmark from storage.
  ///
  /// Requirements: 16.7
  Future<void> _onDeleteBookmark(
    DeleteBookmark event,
    Emitter<BookmarkState> emit,
  ) async {
    final currentBookmarks = _getCurrentBookmarks();
    final currentFilter = _getCurrentFilter();

    try {
      final result = await _deleteBookmarkUseCase.execute(event.bookmarkId);

      if (result.isSuccess) {
        // Reload bookmarks to reflect the deletion
        add(const LoadBookmarks());
      } else {
        emit(
          BookmarkError(
            message: result.errorOrNull?.message ?? 'Unknown error',
            bookmarks: currentBookmarks,
            filterCategory: currentFilter,
          ),
        );
      }
    } catch (e) {
      emit(
        BookmarkError(
          message: 'Failed to delete bookmark: $e',
          bookmarks: currentBookmarks,
          filterCategory: currentFilter,
        ),
      );
    }
  }

  /// Handles the FilterByCategory event.
  ///
  /// This filters the displayed bookmarks by category.
  ///
  /// Requirements: 16.9
  Future<void> _onFilterByCategory(
    FilterByCategory event,
    Emitter<BookmarkState> emit,
  ) async {
    final currentBookmarks = _getCurrentBookmarks();

    // Update the filter and emit new state
    emit(
      BookmarkLoaded(
        bookmarks: currentBookmarks,
        filterCategory: event.category,
      ),
    );
  }

  /// Gets the current bookmarks list from the current state.
  List<Bookmark> _getCurrentBookmarks() {
    final currentState = state;
    if (currentState is BookmarkLoaded) {
      return currentState.bookmarks;
    } else if (currentState is BookmarkSaving) {
      return currentState.bookmarks;
    } else if (currentState is BookmarkError) {
      return currentState.bookmarks;
    }
    return const [];
  }

  /// Gets the current category filter from the current state.
  BookmarkCategory? _getCurrentFilter() {
    final currentState = state;
    if (currentState is BookmarkLoaded) {
      return currentState.filterCategory;
    } else if (currentState is BookmarkSaving) {
      return currentState.filterCategory;
    } else if (currentState is BookmarkError) {
      return currentState.filterCategory;
    }
    return null;
  }
}
