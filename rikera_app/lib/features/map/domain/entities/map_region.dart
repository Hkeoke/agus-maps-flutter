import 'region_bounds.dart';

/// Represents a downloadable map region.
///
/// Map regions are geographic areas that can be downloaded for offline use.
/// Each region has metadata including size, version, and download status.
class MapRegion {
  /// Unique identifier for the region
  final String id;

  /// Human-readable name of the region (e.g., "Gibraltar", "Spain")
  final String name;

  /// Filename of the MWM file (e.g., "Gibraltar.mwm")
  final String fileName;

  /// Size of the map file in bytes
  final int sizeBytes;

  /// Version/snapshot identifier for the map data
  final String snapshotVersion;

  /// Geographic bounding box of the region
  final RegionBounds bounds;

  /// Whether this region is currently downloaded
  final bool isDownloaded;

  /// Whether this is a bundled asset (included with the app)
  final bool isBundled;

  /// Full path to the MWM file on device (for downloaded/bundled maps)
  final String filePath;

  const MapRegion({
    required this.id,
    required this.name,
    required this.fileName,
    required this.sizeBytes,
    required this.snapshotVersion,
    required this.bounds,
    required this.isDownloaded,
    this.isBundled = false,
    this.filePath = '',
  });

  /// Creates a copy of this region with updated fields
  MapRegion copyWith({
    String? id,
    String? name,
    String? fileName,
    int? sizeBytes,
    String? snapshotVersion,
    RegionBounds? bounds,
    bool? isDownloaded,
    bool? isBundled,
    String? filePath,
  }) {
    return MapRegion(
      id: id ?? this.id,
      name: name ?? this.name,
      fileName: fileName ?? this.fileName,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      snapshotVersion: snapshotVersion ?? this.snapshotVersion,
      bounds: bounds ?? this.bounds,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      isBundled: isBundled ?? this.isBundled,
      filePath: filePath ?? this.filePath,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MapRegion &&
        other.id == id &&
        other.name == name &&
        other.fileName == fileName &&
        other.sizeBytes == sizeBytes &&
        other.snapshotVersion == snapshotVersion &&
        other.bounds == bounds &&
        other.isDownloaded == isDownloaded &&
        other.isBundled == isBundled &&
        other.filePath == filePath;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        fileName.hashCode ^
        sizeBytes.hashCode ^
        snapshotVersion.hashCode ^
        bounds.hashCode ^
        isDownloaded.hashCode ^
        isBundled.hashCode ^
        filePath.hashCode;
  }

  @override
  String toString() {
    return 'MapRegion(id: $id, name: $name, file: $fileName, '
        'size: $sizeBytes bytes, version: $snapshotVersion, downloaded: $isDownloaded)';
  }
}
