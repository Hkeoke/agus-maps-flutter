import 'dart:io';
import 'package:agus_maps_flutter/agus_maps_flutter.dart';

/// Progress information for a map download.
class DownloadProgress {
  final int bytesReceived;
  final int totalBytes;
  final double progress;

  DownloadProgress({required this.bytesReceived, required this.totalBytes})
    : progress = totalBytes > 0 ? bytesReceived / totalBytes : 0.0;

  @override
  String toString() =>
      'DownloadProgress(${(progress * 100).toStringAsFixed(1)}%, '
      '$bytesReceived/$totalBytes bytes)';
}

/// Data source for downloading map regions using MirrorService.
///
/// This data source handles fetching available regions from the CoMaps CDN
/// and downloading MWM files with progress tracking.
class MapDownloadDataSource {
  final MirrorService _mirrorService;
  Mirror? _cachedFastestMirror;
  Snapshot? _cachedSnapshot;

  MapDownloadDataSource({MirrorService? mirrorService})
    : _mirrorService = mirrorService ?? MirrorService();

  /// Get list of available regions from the CoMaps CDN.
  ///
  /// This method:
  /// 1. Measures latencies to all mirrors
  /// 2. Selects the fastest available mirror
  /// 3. Fetches the latest snapshot
  /// 4. Returns the list of available regions
  ///
  /// Throws [MapDownloadException] if no mirrors are available or
  /// if fetching regions fails.
  Future<List<MwmRegion>> getAvailableRegions() async {
    try {
      // Measure latencies if not already done
      if (_cachedFastestMirror == null) {
        await _mirrorService.measureLatencies();
        _cachedFastestMirror = _mirrorService.getFastestMirror();

        if (_cachedFastestMirror == null) {
          throw MapDownloadException('No available mirrors found');
        }
      }

      // Get latest snapshot if not cached
      if (_cachedSnapshot == null) {
        final snapshots = await _mirrorService.getSnapshots(
          _cachedFastestMirror!,
        );
        if (snapshots.isEmpty) {
          throw MapDownloadException('No snapshots available');
        }
        _cachedSnapshot = snapshots.first; // Latest snapshot
      }

      // Fetch regions from the snapshot
      final regions = await _mirrorService.getRegions(
        _cachedFastestMirror!,
        _cachedSnapshot!,
      );

      return regions;
    } catch (e) {
      if (e is MapDownloadException) rethrow;
      throw MapDownloadException('Failed to fetch available regions: $e');
    }
  }

  /// Download a map region with progress streaming.
  ///
  /// [region] is the region to download.
  /// [destination] is the file where the MWM will be saved.
  ///
  /// Returns a stream of [DownloadProgress] events.
  /// The stream completes when the download finishes successfully.
  ///
  /// Throws [MapDownloadException] if download fails.
  Stream<DownloadProgress> downloadRegion(
    MwmRegion region,
    File destination,
  ) async* {
    try {
      // Ensure we have a mirror and snapshot
      if (_cachedFastestMirror == null || _cachedSnapshot == null) {
        await getAvailableRegions(); // This will initialize them
      }

      // Build download URL
      final url = _mirrorService.getDownloadUrl(
        _cachedFastestMirror!,
        _cachedSnapshot!,
        region,
      );

      // Track progress
      int lastBytesReceived = 0;
      int totalBytes = 0;

      // Download to file with progress callback
      await _mirrorService.downloadToFile(
        url,
        destination,
        onProgress: (received, total) {
          lastBytesReceived = received;
          totalBytes = total;
        },
      );

      // Yield final progress
      yield DownloadProgress(
        bytesReceived: lastBytesReceived,
        totalBytes: totalBytes,
      );
    } catch (e) {
      throw MapDownloadException(
        'Failed to download region ${region.name}: $e',
      );
    }
  }

  /// Get the current snapshot version being used.
  ///
  /// Returns null if no snapshot has been fetched yet.
  String? get currentSnapshotVersion => _cachedSnapshot?.version;

  /// Get the current mirror being used.
  ///
  /// Returns null if no mirror has been selected yet.
  Mirror? get currentMirror => _cachedFastestMirror;

  /// Clear cached mirror and snapshot to force re-discovery.
  ///
  /// Call this to refresh the mirror selection or check for new snapshots.
  void clearCache() {
    _cachedFastestMirror = null;
    _cachedSnapshot = null;
  }

  /// Dispose of resources.
  void dispose() {
    _mirrorService.dispose();
  }
}

/// Exception thrown when map download operations fail.
class MapDownloadException implements Exception {
  final String message;

  MapDownloadException(this.message);

  @override
  String toString() => 'MapDownloadException: $message';
}
