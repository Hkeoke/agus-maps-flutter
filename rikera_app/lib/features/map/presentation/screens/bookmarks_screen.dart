import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rikera_app/features/map/presentation/blocs/blocs.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';

/// Screen for managing bookmarks.
///
/// This screen displays all saved bookmarks with filtering by category,
/// and provides options to add, edit, and delete bookmarks.
///
/// Requirements: 16.3, 16.9
class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  BookmarkCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    // Load bookmarks when screen is opened
    context.read<BookmarkBloc>().add(const LoadBookmarks());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookmarks'),
        actions: [
          // Category filter dropdown
          _buildCategoryFilter(),
        ],
      ),
      body: BlocBuilder<BookmarkBloc, BookmarkState>(
        builder: (context, state) {
          if (state is BookmarkInitial || state is BookmarkLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is BookmarkError) {
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
                    state.message,
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

          final bookmarks = state is BookmarkLoaded
              ? state.filteredBookmarks
              : state is BookmarkSaving
              ? state.bookmarks
              : <Bookmark>[];

          if (bookmarks.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: bookmarks.length,
            itemBuilder: (context, index) {
              final bookmark = bookmarks[index];
              return _buildBookmarkListItem(bookmark);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddBookmarkDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Bookmark'),
      ),
    );
  }

  /// Builds the category filter dropdown.
  ///
  /// Requirements: 16.9
  Widget _buildCategoryFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: DropdownButton<BookmarkCategory?>(
        value: _selectedCategory,
        hint: const Text('All Categories'),
        underline: const SizedBox.shrink(),
        items: [
          const DropdownMenuItem<BookmarkCategory?>(
            value: null,
            child: Text('All Categories'),
          ),
          ...BookmarkCategory.values.map((category) {
            return DropdownMenuItem<BookmarkCategory?>(
              value: category,
              child: Text(_getCategoryDisplayName(category)),
            );
          }),
        ],
        onChanged: (category) {
          setState(() {
            _selectedCategory = category;
          });
          context.read<BookmarkBloc>().add(FilterByCategory(category));
        },
      ),
    );
  }

  /// Builds the empty state when no bookmarks exist.
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_border,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No bookmarks yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Add your favorite locations to quickly access them later',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Builds a bookmark list item with swipe-to-delete and tap-to-view.
  ///
  /// Requirements: 16.3, 16.4, 9.1
  Widget _buildBookmarkListItem(Bookmark bookmark) {
    return Dismissible(
      key: Key(bookmark.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white, size: 32),
      ),
      confirmDismiss: (direction) async {
        // Show confirmation dialog before deleting
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Bookmark'),
            content: Text(
              'Are you sure you want to delete "${bookmark.name}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        context.read<BookmarkBloc>().add(DeleteBookmark(bookmark.id));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${bookmark.name} deleted')));
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: InkWell(
          onTap: () => _onBookmarkTap(bookmark),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                // Category icon with color
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getCategoryColor(
                      bookmark.category,
                    ).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getCategoryIcon(bookmark.category),
                    color: _getCategoryColor(bookmark.category),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),

                // Bookmark details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bookmark.name,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getCategoryDisplayName(bookmark.category),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _getCategoryColor(bookmark.category),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${bookmark.location.latitude.toStringAsFixed(4)}, '
                        '${bookmark.location.longitude.toStringAsFixed(4)}',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Action buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Edit button
                    IconButton(
                      icon: const Icon(Icons.edit),
                      iconSize: 24,
                      tooltip: 'Edit',
                      onPressed: () => _showEditBookmarkDialog(bookmark),
                    ),
                    // Navigate button
                    IconButton(
                      icon: const Icon(Icons.navigation),
                      iconSize: 24,
                      tooltip: 'Navigate',
                      onPressed: () => _navigateToBookmark(bookmark),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Shows dialog to add a new bookmark.
  ///
  /// Requirements: 16.2
  void _showAddBookmarkDialog() {
    final nameController = TextEditingController();
    final latController = TextEditingController();
    final lonController = TextEditingController();
    BookmarkCategory selectedCategory = BookmarkCategory.favorite;

    // Pre-fill with current location if available
    final locationState = context.read<LocationBloc>().state;
    if (locationState is LocationTracking) {
      latController.text = locationState.location.latitude.toStringAsFixed(6);
      lonController.text = locationState.location.longitude.toStringAsFixed(6);
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Bookmark'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Name field
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Enter bookmark name',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),

              // Category dropdown
              StatefulBuilder(
                builder: (context, setState) =>
                    DropdownButtonFormField<BookmarkCategory>(
                      value: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: BookmarkCategory.values.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Row(
                            children: [
                              Icon(
                                _getCategoryIcon(category),
                                color: _getCategoryColor(category),
                              ),
                              const SizedBox(width: 8),
                              Text(_getCategoryDisplayName(category)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (category) {
                        if (category != null) {
                          setState(() => selectedCategory = category);
                        }
                      },
                    ),
              ),
              const SizedBox(height: 16),

              // Latitude field
              TextField(
                controller: latController,
                decoration: const InputDecoration(
                  labelText: 'Latitude',
                  hintText: 'Enter latitude',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
              ),
              const SizedBox(height: 16),

              // Longitude field
              TextField(
                controller: lonController,
                decoration: const InputDecoration(
                  labelText: 'Longitude',
                  hintText: 'Enter longitude',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final latText = latController.text.trim();
              final lonText = lonController.text.trim();

              if (name.isEmpty || latText.isEmpty || lonText.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all fields')),
                );
                return;
              }

              final lat = double.tryParse(latText);
              final lon = double.tryParse(lonText);

              if (lat == null || lon == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Invalid latitude or longitude'),
                  ),
                );
                return;
              }

              // Create and save bookmark
              final bookmark = Bookmark(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: name,
                location: Location(
                  latitude: lat,
                  longitude: lon,
                  timestamp: DateTime.now(),
                ),
                category: selectedCategory,
                createdAt: DateTime.now(),
              );

              context.read<BookmarkBloc>().add(SaveBookmark(bookmark));
              Navigator.of(dialogContext).pop();

              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Bookmark "$name" added')));
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  /// Gets the display name for a bookmark category.
  String _getCategoryDisplayName(BookmarkCategory category) {
    switch (category) {
      case BookmarkCategory.home:
        return 'Home';
      case BookmarkCategory.work:
        return 'Work';
      case BookmarkCategory.favorite:
        return 'Favorite';
      case BookmarkCategory.other:
        return 'Other';
    }
  }

  /// Gets the icon for a bookmark category.
  IconData _getCategoryIcon(BookmarkCategory category) {
    switch (category) {
      case BookmarkCategory.home:
        return Icons.home;
      case BookmarkCategory.work:
        return Icons.work;
      case BookmarkCategory.favorite:
        return Icons.star;
      case BookmarkCategory.other:
        return Icons.place;
    }
  }

  /// Gets the color for a bookmark category.
  Color _getCategoryColor(BookmarkCategory category) {
    switch (category) {
      case BookmarkCategory.home:
        return Colors.blue;
      case BookmarkCategory.work:
        return Colors.orange;
      case BookmarkCategory.favorite:
        return Colors.red;
      case BookmarkCategory.other:
        return Colors.green;
    }
  }

  /// Handles tap on a bookmark to view it on the map.
  ///
  /// Requirements: 16.4
  void _onBookmarkTap(Bookmark bookmark) {
    // Center map on bookmark location
    context.read<MapCubit>().moveToLocation(bookmark.location, zoom: 16);

    // Navigate back to map screen
    Navigator.of(context).pop();

    // Show snackbar with navigation option
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Viewing ${bookmark.name}'),
        action: SnackBarAction(
          label: 'Navigate',
          onPressed: () => _navigateToBookmark(bookmark),
        ),
      ),
    );
  }

  /// Shows dialog to edit a bookmark.
  ///
  /// Requirements: 16.6, 16.7
  void _showEditBookmarkDialog(Bookmark bookmark) {
    final nameController = TextEditingController(text: bookmark.name);
    BookmarkCategory selectedCategory = bookmark.category;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Bookmark'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Name field
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Enter bookmark name',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),

              // Category dropdown
              StatefulBuilder(
                builder: (context, setState) =>
                    DropdownButtonFormField<BookmarkCategory>(
                      value: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: BookmarkCategory.values.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Row(
                            children: [
                              Icon(
                                _getCategoryIcon(category),
                                color: _getCategoryColor(category),
                              ),
                              const SizedBox(width: 8),
                              Text(_getCategoryDisplayName(category)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (category) {
                        if (category != null) {
                          setState(() => selectedCategory = category);
                        }
                      },
                    ),
              ),
              const SizedBox(height: 16),

              // Location info (read-only)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Location (cannot be changed):',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lat: ${bookmark.location.latitude.toStringAsFixed(6)}',
                    ),
                    Text(
                      'Lon: ${bookmark.location.longitude.toStringAsFixed(6)}',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();

              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name cannot be empty')),
                );
                return;
              }

              // Update bookmark
              final updatedBookmark = bookmark.copyWith(
                name: name,
                category: selectedCategory,
              );

              context.read<BookmarkBloc>().add(UpdateBookmark(updatedBookmark));
              Navigator.of(dialogContext).pop();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Bookmark "$name" updated')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Navigates to a bookmark location.
  ///
  /// Requirements: 16.4, 16.5
  void _navigateToBookmark(Bookmark bookmark) {
    // Get current location
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

    // Calculate route to bookmark
    context.read<RouteBloc>().add(
      CalculateRoute(
        origin: locationState.location,
        destination: bookmark.location,
      ),
    );

    // Navigate back to map screen
    Navigator.of(context).pop();

    // Show snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Calculating route to ${bookmark.name}')),
    );
  }
}
