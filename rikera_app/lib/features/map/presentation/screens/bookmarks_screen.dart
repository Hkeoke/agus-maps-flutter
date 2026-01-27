import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rikera_app/features/map/presentation/blocs/blocs.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';
import 'package:rikera_app/features/map/presentation/widgets/widgets.dart';
import 'package:rikera_app/core/theme/theme.dart';

/// Screen for managing bookmarks.
///
/// This screen displays all saved bookmarks with filtering by category,
/// and provides options to add, edit, and delete bookmarks.
///
/// Requirements: 16.3, 16.9
class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Load bookmarks when screen is opened
    context.read<BookmarkBloc>().add(const LoadBookmarks());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookmarks'),
        actions: [
          BlocBuilder<BookmarkBloc, BookmarkState>(
            builder: (context, state) {
              final selectedCategory = state is BookmarkLoaded
                  ? state.selectedCategory
                  : null;

              return BookmarkCategoryFilter(
                selectedCategory: selectedCategory,
                onChanged: (category) {
                  context.read<BookmarkBloc>().add(FilterByCategory(category));
                },
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<BookmarkBloc, BookmarkState>(
        listener: (context, state) {
          if (state is BookmarkError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.errorLight,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is BookmarkInitial || state is BookmarkLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is BookmarkError) {
            return _buildErrorState(context, state.message);
          }

          final bookmarks = _getBookmarks(state);

          if (bookmarks.isEmpty) {
            return const BookmarkEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.sm),
            itemCount: bookmarks.length,
            itemBuilder: (context, index) {
              final bookmark = bookmarks[index];
              return BookmarkListItem(
                bookmark: bookmark,
                onTap: () => _onBookmarkTap(context, bookmark),
                onEdit: () => _showEditDialog(context, bookmark),
                onNavigate: () => _navigateToBookmark(context, bookmark),
                onDelete: () => _deleteBookmark(context, bookmark),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Bookmark'),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Error loading bookmarks',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              context.read<BookmarkBloc>().add(const LoadBookmarks());
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  List<Bookmark> _getBookmarks(BookmarkState state) {
    if (state is BookmarkLoaded) {
      return state.filteredBookmarks;
    } else if (state is BookmarkSaving) {
      return state.bookmarks;
    }
    return [];
  }

  void _onBookmarkTap(BuildContext context, Bookmark bookmark) {
    context.read<MapCubit>().moveToLocation(bookmark.location, zoom: 16);
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Viewing ${bookmark.name}'),
        action: SnackBarAction(
          label: 'Navigate',
          onPressed: () => _navigateToBookmark(context, bookmark),
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final locationState = context.read<LocationBloc>().state;
    final currentLocation = locationState is LocationTracking
        ? locationState.location
        : null;

    showDialog(
      context: context,
      builder: (dialogContext) => AddBookmarkDialog(
        currentLocation: currentLocation,
        onSave: (bookmark) {
          context.read<BookmarkBloc>().add(SaveBookmark(bookmark));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Bookmark "${bookmark.name}" added')),
          );
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, Bookmark bookmark) {
    showDialog(
      context: context,
      builder: (dialogContext) => EditBookmarkDialog(
        bookmark: bookmark,
        onSave: (updatedBookmark) {
          context.read<BookmarkBloc>().add(UpdateBookmark(updatedBookmark));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Bookmark "${updatedBookmark.name}" updated')),
          );
        },
      ),
    );
  }

  void _navigateToBookmark(BuildContext context, Bookmark bookmark) {
    final locationState = context.read<LocationBloc>().state;
    if (locationState is! LocationTracking) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location not available. Please enable location services.',
          ),
        ),
      );
      return;
    }

    context.read<RouteBloc>().add(
          CalculateRoute(
            origin: locationState.location,
            destination: bookmark.location,
          ),
        );

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Calculating route to ${bookmark.name}')),
    );
  }

  void _deleteBookmark(BuildContext context, Bookmark bookmark) {
    context.read<BookmarkBloc>().add(DeleteBookmark(bookmark.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${bookmark.name} deleted')),
    );
  }
}
