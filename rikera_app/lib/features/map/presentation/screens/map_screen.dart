import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:agus_maps_flutter/agus_maps_flutter.dart';
import 'package:rikera_app/features/map/presentation/blocs/blocs.dart';
import 'package:rikera_app/features/map/presentation/widgets/widgets.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';

/// Main map screen displaying the interactive map.
///
/// Requirements: 2.1, 2.2, 2.4, 4.3, 4.5, 4.6, 5.2, 9.1
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mapCubit = context.read<MapCubit>();
    
    return Scaffold(
      body: MultiBlocListener(
        listeners: [
          BlocListener<LocationBloc, LocationState>(
            listener: (context, locationState) {
              if (locationState is LocationTracking) {
                // Always update location
                mapCubit.updateLocation(locationState.location);
                
                // Send location to map for "My Position" icon
                final loc = locationState.location;
                mapCubit.mapController.setMyPosition(
                  loc.latitude,
                  loc.longitude,
                  loc.accuracy ?? 0.0,
                  loc.heading ?? 0.0,
                  loc.speed ?? 0.0,
                  loc.timestamp.millisecondsSinceEpoch,
                );
              } else if (locationState is LocationPermissionDenied) {
                // Request permissions if denied
                context.read<LocationBloc>().add(const RequestPermissions());
              }
            },
          ),
          BlocListener<MapDownloadBloc, MapDownloadState>(
            listenWhen: (previous, current) {
              // Only trigger when transitioning from downloading to loaded
              return previous is MapDownloadDownloading && current is MapDownloadLoaded;
            },
            listener: (context, downloadState) {
              // When a download completes, re-register maps
              if (downloadState is MapDownloadLoaded) {
                // Wait a bit for the file system to settle
                Future.delayed(const Duration(milliseconds: 500), () {
                  mapCubit.add(const ReRegisterDownloadedMaps());
                });
              }
            },
          ),
          BlocListener<MapCubit, MapState>(
            listener: (context, mapState) {
              if (mapState is MapDownloadRequired) {
                _showMapDownloadDialog(context, mapState);
              } else if (mapState is MapSelectionAvailable) {
                _showPlacePageSheet(context, mapState);
              } else if (mapState is MapReady && mapState.location != null) {
                mapCubit.mapController.moveToLocation(
                  mapState.location!.latitude,
                  mapState.location!.longitude,
                  mapState.zoom,
                );
              }
            },
          ),
        ],
        child: BlocBuilder<MapCubit, MapState>(
          builder: (context, mapState) {
            final location = mapState is MapReady ? mapState.location : null;
            final zoom = mapState is MapReady ? mapState.zoom : 15;

            return Stack(
              children: [
                AgusMap(
                  controller: mapCubit.mapController,
                  initialLat: location?.latitude ?? 14.5995,
                  initialLon: location?.longitude ?? 120.9842,
                  initialZoom: zoom,
                  onMapReady: () => mapCubit.add(const MapReadyEvent()),
                ),
                BlocBuilder<BookmarkBloc, BookmarkState>(
                  builder: (context, bookmarkState) {
                    if (bookmarkState is BookmarkLoaded) {
                      return BookmarkMarkersWidget(
                        bookmarks: bookmarkState.bookmarks,
                        onBookmarkTap: (bookmark) => _showBookmarkDetails(context, bookmark),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                BlocBuilder<RouteBloc, RouteState>(
                  builder: (context, routeState) {
                    if (routeState is RouteCalculated) {
                      return CustomPaint(
                        painter: RouteOverlayPainter(route: routeState.route),
                        child: const SizedBox.expand(),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                const MapFloatingActions(),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showMapDownloadDialog(BuildContext context, MapDownloadRequired state) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => MapDownloadDialog(
        countryName: state.countryName,
      ),
    );
  }

  void _showPlacePageSheet(BuildContext context, MapSelectionAvailable state) {
    final mapCubit = context.read<MapCubit>();
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => PlacePageSheet(
        info: state.selectionInfo,
        mapController: mapCubit.mapController,
      ),
    );
  }

  void _showBookmarkDetails(BuildContext context, Bookmark bookmark) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => BookmarkDetailsSheet(
        bookmark: bookmark,
      ),
    );
  }
}
