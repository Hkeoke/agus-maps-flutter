import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:agus_maps_flutter/agus_maps_flutter.dart';
import 'package:rikera_app/features/map/presentation/blocs/blocs.dart';
import 'package:rikera_app/features/map/presentation/widgets/widgets.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';
import 'package:rikera_app/features/settings/presentation/screens/settings_screen.dart';
import 'search_screen.dart';
import 'bookmarks_screen.dart';
import 'map_downloads_screen.dart';

/// Main map screen displaying the interactive map.
///
/// This screen integrates the AgusMap widget with location tracking,
/// route display, and navigation controls.
///
/// Requirements: 2.1, 2.2, 2.4, 4.3, 4.5, 4.6, 5.2, 9.1
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late final AgusMapController _mapController;
  bool _isMapReady = false;
  bool _hasCheckedMapDownload = false; // Prevent spamming dialog

  @override
  void initState() {
    super.initState();
    _mapController = AgusMapController();

    // Restore map view state after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MapCubit>().restoreMapViewState();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isMapReady) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      _mapController.setMapStyle(isDark);
    }
  }

  /// Called when the map is ready for interaction.
  ///
  /// This initializes location tracking and sets up the initial map view.
  ///
  /// Requirements: 2.1, 2.2, 2.6
  void _onMapReady() {
    _isMapReady = true;
    
    // Sync theme
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _mapController.setMapStyle(isDark);

    // Register bundled maps with the engine
    context.read<MapCubit>().registerBundledMaps();

    // Start location tracking when map is ready
    context.read<LocationBloc>().add(const StartTracking());

    // Load bookmarks to display markers
    context.read<BookmarkBloc>().add(const LoadBookmarks());

    // Listen to native map selections (taps)
    _mapController.onSelectionChanged.listen((selected) {
      if (selected) {
        _handleMapSelection();
      }
    });

    debugPrint('[MapScreen] Map is ready');
  }

  Future<void> _checkMapDownload(Location loc) async {
    if (_hasCheckedMapDownload) return;
    
    // Check map status: 2 = NotDownloaded
    final status = await checkMapStatus(loc.latitude, loc.longitude);
    debugPrint('[MapScreen] CheckMapStatus: lat=${loc.latitude} lon=${loc.longitude} -> Status $status');
    
    if (status == 2 && mounted) {
      _hasCheckedMapDownload = true;
      
      // Get country info
      final countryName = await getCountryName(loc.latitude, loc.longitude);
      
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Download ${countryName ?? "Map"}?'),
          content: Text('The map for ${countryName ?? "this area"} is not downloaded. Download it now to see details and navigate.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Not Now'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                if (countryName != null) {
                  // Try to find region object in Bloc to star download directly
                  final state = context.read<MapDownloadBloc>().state;
                  if (state is MapDownloadLoaded) {
                    try {
                      // Match by ID (preferred) or Name
                      final region = state.regions.firstWhere(
                        (r) => r.id == countryName || r.name == countryName,
                        orElse: () => throw Exception('Not found'),
                      );
                      context.read<MapDownloadBloc>().add(DownloadRegion(region));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Downloading $countryName...')),
                      );
                      return;
                    } catch (_) {}
                  }
                }
                // Fallback: Check list manually
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const MapDownloadsScreen())
                );
              },
              child: const Text('Download'),
            ),
          ],
        ),
      );
    } else if (status == 1) {
        // Map exists, mark as checked so we don't check again unnecessarily
        _hasCheckedMapDownload = true;
    }
  }

  Future<void> _handleMapSelection() async {
    final info = await _mapController.getSelectionInfo();
    if (info != null && mounted) {
      showModalBottomSheet(
        context: context,
        builder: (context) => _buildPlacePage(info),
      );
    }
  }

  Widget _buildPlacePage(Map<String, dynamic> info) {
    final title = info['title'] ?? 'Unknown Place';
    final subtitle = info['subtitle'] ?? '';
    final lat = info['lat']; // dynamic, might be double or string 
    final lon = info['lon'];

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          if (subtitle.isNotEmpty) 
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.directions),
                label: const Text('IR AQUI (RUTA)'),
                onPressed: () {
                  Navigator.pop(context);
                  if (lat != null && lon != null) {
                    // Convert to double securely
                    final dLat = lat is String ? double.parse(lat) : (lat as num).toDouble();
                    final dLon = lon is String ? double.parse(lon) : (lon as num).toDouble();
                    _mapController.buildRoute(dLat, dLon);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Ensure map theme matches app theme on every rebuild
    if (_isMapReady) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      _mapController.setMapStyle(isDark);
    }

    return Scaffold(
      body: MultiBlocListener(
        listeners: [
          // Listen to location updates and feed native engine
          BlocListener<LocationBloc, LocationState>(
            listener: (context, locationState) {
              if (locationState is LocationTracking && _isMapReady) {
                final loc = locationState.location;
                // Feed location to native engine for rendering the arrow
                _mapController.setMyPosition(
                  loc.latitude, 
                  loc.longitude, 
                  loc.accuracy ?? 0, 
                  loc.heading ?? 0, 
                  loc.speed ?? 0, 
                  loc.timestamp.millisecondsSinceEpoch
                );
                
                // Prompt user if map is missing for current location
                _checkMapDownload(loc);
              }
            },
          ),
          // Load bookmarks when map is ready
          BlocListener<BookmarkBloc, BookmarkState>(
            listener: (context, bookmarkState) {
              // Reload bookmarks when they change
              if (bookmarkState is BookmarkLoaded && _isMapReady) {
                // Trigger map redraw to show updated bookmarks
                setState(() {});
              }
            },
          ),
        ],
        child: Stack(
          children: [
            // Map widget
            _buildMap(),

            // Bookmark markers overlay
            _buildBookmarkMarkers(),

            // Floating action buttons (Left & Right)
            _buildFloatingActions(),
          ],
        ),
      ),
    );
  }

  /// Builds the main map widget.
  ///
  /// The AgusMap widget handles all gesture interactions internally:
  /// - Pan: Single finger drag to move the map
  /// - Zoom: Pinch with two fingers or scroll wheel (desktop)
  /// - Rotate: Two-finger rotation gesture
  /// - Double-tap: Quick zoom in (handled by native engine)
  ///
  /// Requirements: 2.1, 2.2, 2.4
  Widget _buildMap() {
    return BlocConsumer<MapCubit, MapState>(
      listener: (context, mapState) {
        // Update map view when state changes
        if (_isMapReady && mapState.location != null) {
          _mapController.moveToLocation(
            mapState.location!.latitude,
            mapState.location!.longitude,
            mapState.zoom,
          );
        }
      },
      builder: (context, mapState) {
        return AgusMap(
          controller: _mapController,
          initialLat: mapState.location?.latitude ?? 14.5995, // Manila default
          initialLon: mapState.location?.longitude ?? 120.9842,
          initialZoom: mapState.zoom,
          onMapReady: _onMapReady,
        );
      },
    );
  }

  /// Builds the location marker overlay.
  ///
  /// Displays the user's current position with a marker and accuracy circle.
  ///
  /// Requirements: 4.3, 4.5, 4.6
  Widget _buildLocationMarker() {
    return BlocBuilder<LocationBloc, LocationState>(
      builder: (context, locationState) {
        if (locationState is! LocationTracking) {
          return const SizedBox.shrink();
        }

        final location = locationState.location;
        final accuracy = location.accuracy ?? 0;
        final showAccuracyCircle = accuracy > 50; // Show if accuracy > 50m

        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Accuracy circle (shown when accuracy is low)
              if (showAccuracyCircle)
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue.withOpacity(0.1),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                ),

              // Position marker
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),

              // Heading indicator (if available)
              if (location.heading != null && location.heading! > 0)
                Transform.rotate(
                  angle:
                      location.heading! * 3.14159 / 180, // Convert to radians
                  child: Icon(
                    Icons.navigation,
                    color: Colors.blue,
                    size: 24,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Builds the route overlay.
  ///
  /// Displays the calculated route on the map with turn markers.
  ///
  /// Requirements: 5.2
  Widget _buildRouteOverlay() {
    return BlocBuilder<MapCubit, MapState>(
      builder: (context, mapState) {
        if (mapState.routeOverlay == null) {
          return const SizedBox.shrink();
        }

        // Get current segment from navigation state if navigating
        return BlocBuilder<NavigationBloc, NavigationBlocState>(
          builder: (context, navState) {
            RouteSegment? currentSegment;
            if (navState is NavigationNavigating) {
              currentSegment = navState.navigationState.currentSegment;
            }

            return RouteOverlayWidget(
              route: mapState.routeOverlay!,
              currentSegment: currentSegment,
            );
          },
        );
      },
    );
  }

  /// Builds the bookmark markers overlay.
  ///
  /// Displays markers for all saved bookmarks on the map.
  ///
  /// Requirements: 16.10
  Widget _buildBookmarkMarkers() {
    return BlocBuilder<BookmarkBloc, BookmarkState>(
      builder: (context, bookmarkState) {
        List<Bookmark> bookmarks = [];

        if (bookmarkState is BookmarkLoaded) {
          bookmarks = bookmarkState.bookmarks;
        } else if (bookmarkState is BookmarkSaving) {
          bookmarks = bookmarkState.bookmarks;
        } else if (bookmarkState is BookmarkError) {
          bookmarks = bookmarkState.bookmarks;
        }

        if (bookmarks.isEmpty) {
          return const SizedBox.shrink();
        }

        return BookmarkMarkersWidget(
          bookmarks: bookmarks,
          onBookmarkTap: (bookmark) {
            _showBookmarkDetails(bookmark);
          },
        );
      },
    );
  }

  /// Builds the floating action buttons.
  ///
  /// Provides quick access to:
  /// - Search functionality
  /// - Map downloads
  /// - Settings
  ///
  /// All buttons use large touch targets (minimum 48dp) and high contrast colors
  /// for driving safety. Layout adjusts for landscape orientation.
  ///
  /// Requirements: 9.1, 2.5
  Widget _buildFloatingActions() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Stack(
          children: [
            // Left side controls (Navigation & Zoom)
            Align(
              alignment: Alignment.bottomLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildActionButton(
                    icon: Icons.my_location,
                    label: 'My Location',
                    onPressed: () => _mapController.switchMyPositionMode(),
                  ),
                  const SizedBox(height: 16),
                  _buildActionButton(
                    icon: Icons.add,
                    label: 'Zoom In',
                    onPressed: () => _mapController.zoomIn(),
                  ),
                  const SizedBox(height: 8),
                  _buildActionButton(
                    icon: Icons.remove,
                    label: 'Zoom Out',
                    onPressed: () => _mapController.zoomOut(),
                  ),
                ],
              ),
            ),

            // Right side controls (Menu & Tools)
            Align(
              alignment: Alignment.bottomRight,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildActionButton(
                    icon: Icons.search,
                    label: 'Search',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const SearchScreen())
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildActionButton(
                    icon: Icons.bookmarks,
                    label: 'Bookmarks',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const BookmarksScreen())
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildActionButton(
                    icon: Icons.download,
                    label: 'Maps',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const MapDownloadsScreen())
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildActionButton(
                    icon: Icons.settings,
                    label: 'Settings',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const SettingsScreen())
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a single action button with consistent styling.
  ///
  /// Ensures minimum 48dp touch target and high contrast colors.
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 56, // Minimum 48dp + padding
      height: 56,
      child: FloatingActionButton(
        heroTag: label, // Unique tag for each button
        onPressed: onPressed,
        tooltip: label,
        child: Icon(icon, size: 28),
      ),
    );
  }

  /// Shows bookmark details when a marker is tapped.
  ///
  /// Requirements: 16.10
  void _showBookmarkDetails(Bookmark bookmark) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getBookmarkCategoryIcon(bookmark.category),
                  color: _getBookmarkCategoryColor(bookmark.category),
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bookmark.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        _getBookmarkCategoryName(bookmark.category),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _getBookmarkCategoryColor(bookmark.category),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Location: ${bookmark.location.latitude.toStringAsFixed(4)}, '
              '${bookmark.location.longitude.toStringAsFixed(4)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    this.context.read<MapCubit>().moveToLocation(
                      bookmark.location,
                      zoom: 16,
                    );
                  },
                  icon: const Icon(Icons.center_focus_strong),
                  label: const Text('Center'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    final locationState = this.context
                        .read<LocationBloc>()
                        .state;
                    if (locationState is LocationTracking) {
                      this.context.read<RouteBloc>().add(
                        CalculateRoute(
                          origin: locationState.location,
                          destination: bookmark.location,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.navigation),
                  label: const Text('Navigate'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Gets the icon for a bookmark category.
  IconData _getBookmarkCategoryIcon(BookmarkCategory category) {
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
  Color _getBookmarkCategoryColor(BookmarkCategory category) {
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

  /// Gets the display name for a bookmark category.
  String _getBookmarkCategoryName(BookmarkCategory category) {
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
}
