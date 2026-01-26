import 'package:agus_maps_flutter/agus_maps_flutter.dart';

/// Data source for managing map metadata using MwmStorage.
///
/// This data source provides persistence for downloaded map metadata,
/// including region names, versions, file sizes, and download dates.
class MapStorageDataSource {
  final MwmStorage _storage;

  MapStorageDataSource(this._storage);

  /// Create and initialize the storage data source.
  ///
  /// This is an async factory method that creates the MwmStorage instance.
  static Future<MapStorageDataSource> create() async {
    final storage = await MwmStorage.create();
    return MapStorageDataSource(storage);
  }

  /// Get all downloaded maps metadata.
  ///
  /// Returns a list of [MwmMetadata] for all stored maps.
  List<MwmMetadata> getDownloadedMaps() {
    return _storage.getAll();
  }

  /// Get metadata for a specific region.
  ///
  /// Returns null if the region is not found.
  MwmMetadata? getMapMetadata(String regionName) {
    return _storage.getByRegion(regionName);
  }

  /// Check if a region is downloaded.
  ///
  /// Returns true if metadata exists for the region.
  bool isDownloaded(String regionName) {
    return _storage.isDownloaded(regionName);
  }

  /// Save or update metadata for a map.
  ///
  /// If metadata already exists for the region, it will be replaced.
  Future<void> saveMapMetadata(MwmMetadata metadata) async {
    try {
      await _storage.upsert(metadata);
    } catch (e) {
      throw MapStorageException('Failed to save map metadata: $e');
    }
  }

  /// Delete metadata for a region.
  ///
  /// This only removes the metadata, not the actual MWM file.
  /// Use [deleteMapAndFile] to delete both.
  Future<void> deleteMapMetadata(String regionName) async {
    try {
      await _storage.remove(regionName);
    } catch (e) {
      throw MapStorageException('Failed to delete map metadata: $e');
    }
  }

  /// Delete both the map file and its metadata.
  ///
  /// Returns a [DeleteResult] with success status and details.
  /// Will not delete bundled maps.
  Future<DeleteResult> deleteMapAndFile(String regionName) async {
    try {
      return await _storage.deleteMap(regionName);
    } catch (e) {
      throw MapStorageException('Failed to delete map: $e');
    }
  }

  /// Get total storage used by all downloaded maps in bytes.
  int getTotalStorageUsed() {
    return _storage.totalDownloadedSize;
  }

  /// Get count of downloaded maps (excluding bundled).
  int getDownloadedCount() {
    return _storage.downloadedCount;
  }

  /// Get count of bundled maps.
  int getBundledCount() {
    return _storage.bundledCount;
  }

  /// Check if a region's file exists on disk.
  ///
  /// Returns false if metadata doesn't exist or file is missing.
  Future<bool> fileExists(String regionName) async {
    return await _storage.fileExists(regionName);
  }

  /// Validate that a region's file exists and matches expected size.
  ///
  /// Returns a [FileValidationResult] with validation details.
  Future<FileValidationResult> validateFile(String regionName) async {
    return await _storage.validateFile(regionName);
  }

  /// Validate all stored metadata against actual files on disk.
  ///
  /// [pruneOrphaned] - if true, automatically removes metadata for missing files.
  /// [onProgress] - optional callback for progress updates.
  ///
  /// Returns a list of [FileValidationResult] for each stored region.
  Future<List<FileValidationResult>> validateAll({
    bool pruneOrphaned = false,
    void Function(int current, int total)? onProgress,
  }) async {
    return await _storage.validateAll(
      pruneOrphaned: pruneOrphaned,
      onProgress: onProgress,
    );
  }

  /// Check if there are any orphaned metadata entries (missing files).
  Future<bool> hasOrphanedMetadata() async {
    return await _storage.hasOrphanedMetadata();
  }

  /// Get list of regions with orphaned metadata (missing files).
  Future<List<String>> getOrphanedRegions() async {
    return await _storage.getOrphanedRegions();
  }

  /// Remove all metadata for files that no longer exist.
  ///
  /// Returns the list of region names that were pruned.
  Future<List<String>> pruneOrphaned() async {
    return await _storage.pruneOrphaned();
  }

  /// Clear all metadata.
  ///
  /// This does not delete the actual map files.
  Future<void> clearAll() async {
    try {
      await _storage.clear();
    } catch (e) {
      throw MapStorageException('Failed to clear metadata: $e');
    }
  }

  /// Check if an update is available for a region.
  ///
  /// Compares the stored snapshot version with the latest available version.
  /// Returns false for bundled files (they don't get updated).
  bool hasUpdate(String regionName, String latestSnapshotVersion) {
    return _storage.hasUpdate(regionName, latestSnapshotVersion);
  }
}

/// Exception thrown when map storage operations fail.
class MapStorageException implements Exception {
  final String message;

  MapStorageException(this.message);

  @override
  String toString() => 'MapStorageException: $message';
}
