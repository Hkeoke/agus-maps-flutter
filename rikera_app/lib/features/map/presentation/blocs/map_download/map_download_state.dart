import 'package:rikera_app/features/map/domain/entities/entities.dart';
import 'package:rikera_app/features/map/domain/repositories/repositories.dart';

/// Base class for map download states.
abstract class MapDownloadState {
  const MapDownloadState();
}

/// Initial state before regions have been loaded.
class MapDownloadInitial extends MapDownloadState {
  const MapDownloadInitial();

  @override
  bool operator ==(Object other) => other is MapDownloadInitial;

  @override
  int get hashCode => 0;
}

/// State when loading the list of available regions.
///
/// Requirements: 3.1
class MapDownloadLoading extends MapDownloadState {
  const MapDownloadLoading();

  @override
  bool operator ==(Object other) => other is MapDownloadLoading;

  @override
  int get hashCode => 1;
}

/// State when regions have been successfully loaded.
///
/// This state contains the list of all available regions, including
/// their download status.
///
/// Requirements: 3.1
class MapDownloadLoaded extends MapDownloadState {
  final List<MapRegion> regions;
  final int totalStorageUsed;

  const MapDownloadLoaded({
    required this.regions,
    required this.totalStorageUsed,
  });

  /// Returns only the downloaded regions
  List<MapRegion> get downloadedRegions =>
      regions.where((r) => r.isDownloaded).toList();

  /// Returns only the available (not downloaded) regions
  List<MapRegion> get availableRegions =>
      regions.where((r) => !r.isDownloaded).toList();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MapDownloadLoaded &&
        _listEquals(other.regions, regions) &&
        other.totalStorageUsed == totalStorageUsed;
  }

  @override
  int get hashCode => regions.hashCode ^ totalStorageUsed.hashCode;

  @override
  String toString() =>
      'MapDownloadLoaded(regions: ${regions.length}, storage: $totalStorageUsed bytes)';

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// State when a region is being downloaded.
///
/// This state contains the download progress information.
///
/// Requirements: 3.2, 3.3
class MapDownloadDownloading extends MapDownloadState {
  final MapRegion region;
  final DownloadProgress progress;
  final List<MapRegion> regions;
  final int totalStorageUsed;

  const MapDownloadDownloading({
    required this.region,
    required this.progress,
    required this.regions,
    required this.totalStorageUsed,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MapDownloadDownloading &&
        other.region == region &&
        other.progress.bytesReceived == progress.bytesReceived &&
        other.progress.totalBytes == progress.totalBytes;
  }

  @override
  int get hashCode =>
      region.hashCode ^
      progress.bytesReceived.hashCode ^
      progress.totalBytes.hashCode;

  @override
  String toString() =>
      'MapDownloadDownloading(region: ${region.name}, progress: ${progress.progress * 100}%)';
}

/// State when a download or deletion operation fails.
class MapDownloadError extends MapDownloadState {
  final String message;
  final List<MapRegion> regions;
  final int totalStorageUsed;

  const MapDownloadError({
    required this.message,
    required this.regions,
    required this.totalStorageUsed,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MapDownloadError && other.message == message;
  }

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => 'MapDownloadError($message)';
}
