import 'package:rikera_app/features/map/domain/entities/entities.dart';
import 'package:rikera_app/features/map/domain/repositories/repositories.dart';

/// Use case for downloading a map region with progress streaming.
///
/// This use case handles the download of offline map regions, providing
/// real-time progress updates through a stream. On successful completion,
/// the map is registered with the CoMaps engine and marked as downloaded.
///
/// Requirements: 3.2, 3.3
class DownloadMapRegionUseCase {
  final MapRepository _repository;

  const DownloadMapRegionUseCase(this._repository);

  /// Downloads the specified [region] and streams progress updates.
  ///
  /// Returns a stream of [DownloadProgress] events that report:
  /// - Bytes received (monotonically increasing)
  /// - Total bytes
  /// - Download status (downloading, completed, failed, cancelled)
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
  /// Requirements: 3.2, 3.3
  Stream<DownloadProgress> execute(MapRegion region) {
    // Delegate to the repository which handles:
    // - Downloading the MWM file with direct-to-disk streaming
    // - Emitting progress events
    // - Saving metadata on completion
    // - Registering the map with the CoMaps engine
    // - Cleanup on failure
    return _repository.downloadRegion(region);
  }
}
