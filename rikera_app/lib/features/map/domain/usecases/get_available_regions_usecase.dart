import 'package:rikera_app/core/utils/result.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';
import 'package:rikera_app/features/map/domain/repositories/repositories.dart';

/// Use case for fetching the list of available map regions.
///
/// This use case retrieves all map regions that are available for download
/// from the CDN mirrors, including information about which regions are
/// already downloaded.
///
/// Requirements: 3.1
class GetAvailableRegionsUseCase {
  final MapRepository _repository;

  const GetAvailableRegionsUseCase(this._repository);

  /// Fetches the list of available map regions from CDN mirrors.
  ///
  /// Returns a [Result] containing a list of [MapRegion] objects representing
  /// all regions available for download. Each region includes:
  /// - Region ID and name
  /// - File name and size
  /// - Snapshot version
  /// - Geographic bounds
  /// - Download status (isDownloaded flag)
  ///
  /// The repository handles:
  /// - Fetching the region list from CDN
  /// - Merging with locally downloaded regions
  /// - Marking downloaded regions appropriately
  ///
  /// Returns an error if the region list cannot be fetched
  /// (e.g., network unavailable, CDN unreachable).
  ///
  /// Requirements: 3.1
  Future<Result<List<MapRegion>>> execute() async {
    return await _repository.getAvailableRegions();
  }
}
