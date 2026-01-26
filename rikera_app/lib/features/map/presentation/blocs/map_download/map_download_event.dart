import 'package:rikera_app/features/map/domain/entities/entities.dart';

/// Base class for map download events.
abstract class MapDownloadEvent {
  const MapDownloadEvent();
}

/// Event to load the list of available map regions.
///
/// This fetches the list of regions from the CDN and merges with
/// locally downloaded regions.
///
/// Requirements: 3.1
class LoadRegions extends MapDownloadEvent {
  const LoadRegions();
}

/// Event to download a specific map region.
///
/// This initiates a download of the region's MWM file with progress streaming.
///
/// Requirements: 3.2, 3.3
class DownloadRegion extends MapDownloadEvent {
  final MapRegion region;

  const DownloadRegion(this.region);
}

/// Event to delete a downloaded map region.
///
/// This removes the MWM file and metadata for the specified region.
///
/// Requirements: 3.7
class DeleteRegion extends MapDownloadEvent {
  final String regionId;

  const DeleteRegion(this.regionId);
}

/// Event to cancel an ongoing download.
class CancelDownload extends MapDownloadEvent {
  final String regionId;

  const CancelDownload(this.regionId);
}
