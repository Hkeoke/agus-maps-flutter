import 'package:rikera_app/core/utils/result.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';

/// Repository interface for map data management.
///
/// This repository handles downloading, storing, and managing offline map regions.
/// It coordinates between map storage, download services, and the CoMaps engine.
///
/// Requirements: 3.1, 3.2, 3.7
abstract class MapRepository {
  /// Fetches the list of available map regions from CDN mirrors.
  ///
  /// Returns a [Result] containing a list of [MapRegion] objects representing
  /// all regions available for download.
  ///
  /// Requirements: 3.1
  Future<Result<List<MapRegion>>> getAvailableRegions();

  /// Gets the list of map regions that are already downloaded.
  ///
  /// Returns a [Result] containing a list of [MapRegion] objects for regions
  /// that have been downloaded and are available for offline use.
  ///
  /// Requirements: 3.1
  Future<Result<List<MapRegion>>> getDownloadedRegions();

  /// Downloads a map region and registers it with the CoMaps engine.
  ///
  /// Returns a stream of [DownloadProgress] events that report:
  /// - Bytes received
  /// - Total bytes
  /// - Download status
  ///
  /// On successful completion:
  /// - The MWM file is saved to local storage
  /// - Metadata is persisted (region name, version, size, date)
  /// - The file is registered with the CoMaps engine
  /// - The region is marked as downloaded
  ///
  /// On failure:
  /// - The stream emits an error
  /// - Incomplete files and metadata are cleaned up
  ///
  /// Requirements: 3.2, 3.3, 3.4, 3.5, 3.6
  Stream<DownloadProgress> downloadRegion(MapRegion region);

  /// Deletes a downloaded map region.
  ///
  /// This removes:
  /// - The MWM file from disk
  /// - The metadata from storage
  ///
  /// After deletion, the region will appear as not downloaded.
  ///
  /// Requirements: 3.7
  Future<Result<void>> deleteRegion(String regionId);

  /// Registers a map file with the CoMaps engine.
  ///
  /// This makes the map data available for rendering, routing, and search.
  /// Typically called after downloading a new region or on app startup
  /// for bundled maps.
  ///
  /// Requirements: 3.4
  Future<Result<void>> registerMapFile(String filePath);

  /// Calculates the total storage used by all downloaded maps.
  ///
  /// Returns the total size in bytes of all downloaded MWM files.
  ///
  /// Requirements: 3.8
  Future<int> getTotalStorageUsed();
}

/// Represents the progress of a map download operation.
class DownloadProgress {
  const DownloadProgress({
    required this.bytesReceived,
    required this.totalBytes,
    required this.status,
  });

  /// Number of bytes downloaded so far.
  final int bytesReceived;

  /// Total number of bytes to download.
  final int totalBytes;

  /// Current status of the download.
  final DownloadStatus status;

  /// Progress as a percentage (0.0 to 1.0).
  double get progress => totalBytes > 0 ? bytesReceived / totalBytes : 0.0;

  @override
  String toString() =>
      'DownloadProgress(received: $bytesReceived, total: $totalBytes, status: $status)';
}

/// Status of a download operation.
enum DownloadStatus {
  /// Download is in progress.
  downloading,

  /// Download completed successfully.
  completed,

  /// Download failed.
  failed,

  /// Download was cancelled.
  cancelled,
}
