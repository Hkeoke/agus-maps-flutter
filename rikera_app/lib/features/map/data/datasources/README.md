# Data Sources

This directory contains the data source implementations for the Car Maps Application. Data sources provide the interface between the data layer and external services/packages.

## Implemented Data Sources

### 1. MapEngineDataSource

**File:** `map_engine_datasource.dart`

Wraps the agus_maps_flutter APIs for map engine operations.

**Key Methods:**

- `initializeEngine(storagePath)` - Initialize CoMaps engine with storage paths
- `registerMap(filePath, version)` - Register MWM files with the engine
- `setMapView(lat, lon, zoom)` - Set map view to specific coordinates
- `invalidateMap()` - Force tile reload
- `forceRedraw()` - Complete redraw after map registration

**Requirements:** 2.1, 2.6

---

### 2. MapDownloadDataSource

**File:** `map_download_datasource.dart`

Handles downloading map regions from CoMaps CDN using MirrorService.

**Key Methods:**

- `getAvailableRegions()` - Fetch list of downloadable regions from CDN
- `downloadRegion(region, destination)` - Download MWM file with progress streaming
- `currentSnapshotVersion` - Get the current snapshot version being used
- `clearCache()` - Force re-discovery of mirrors and snapshots

**Features:**

- Automatic mirror selection (fastest available)
- Progress tracking via streams
- Direct-to-disk streaming (memory efficient)

**Requirements:** 3.1, 3.2, 3.3

---

### 3. MapStorageDataSource

**File:** `map_storage_datasource.dart`

Manages map metadata persistence using MwmStorage from agus_maps_flutter.

**Key Methods:**

- `getDownloadedMaps()` - Get all downloaded map metadata
- `saveMapMetadata(metadata)` - Save or update map metadata
- `deleteMapMetadata(regionName)` - Remove metadata
- `deleteMapAndFile(regionName)` - Delete both file and metadata
- `getTotalStorageUsed()` - Calculate total storage used
- `validateAll()` - Validate all files against metadata
- `pruneOrphaned()` - Remove metadata for missing files

**Features:**

- File validation (existence, size matching)
- Orphaned metadata detection and cleanup
- Storage usage tracking
- Update detection

**Requirements:** 3.6, 3.7

---

### 4. LocationDataSource

**File:** `location_datasource.dart`

Wraps the geolocator package for GPS location services.

**Key Methods:**

- `getPositionStream()` - Stream of position updates (optimized for navigation)
- `getCurrentPosition()` - Get current position once
- `requestPermission()` - Request location permissions
- `checkPermission()` - Check if permissions are granted
- `isLocationServiceEnabled()` - Check if GPS is enabled
- `openLocationSettings()` - Open device location settings
- `openAppSettings()` - Open app settings for permissions

**Configuration:**

- High accuracy (GPS)
- Distance filter: 5 meters
- Time limit: 10 seconds

**Requirements:** 4.1, 4.2

---

### 5. BookmarkDataSource

**File:** `bookmark_datasource.dart`

Manages bookmark persistence using shared_preferences.

**Key Methods:**

- `getAllBookmarks()` - Get all saved bookmarks
- `getBookmarkById(id)` - Get specific bookmark
- `getBookmarksByCategory(category)` - Filter by category
- `saveBookmark(bookmark)` - Save or update bookmark
- `updateBookmark(bookmark)` - Update existing bookmark
- `deleteBookmark(id)` - Delete bookmark by ID
- `deleteAllBookmarks()` - Clear all bookmarks

**Features:**

- JSON serialization/deserialization
- Category filtering
- In-memory caching for performance
- Automatic persistence on changes

**Requirements:** 16.2, 16.6, 16.8

---

## Usage Example

```dart
// Initialize data sources
final mapEngine = MapEngineDataSource();
final mapDownload = MapDownloadDataSource();
final mapStorage = await MapStorageDataSource.create();
final location = LocationDataSource();
final bookmarks = await BookmarkDataSource.create();

// Initialize map engine
await mapEngine.initializeEngine('/path/to/storage');

// Download a map
final regions = await mapDownload.getAvailableRegions();
final gibraltar = regions.firstWhere((r) => r.name == 'Gibraltar');

await for (final progress in mapDownload.downloadRegion(
  gibraltar,
  File('/path/to/Gibraltar.mwm'),
)) {
  print('Progress: ${(progress.progress * 100).toStringAsFixed(1)}%');
}

// Register the downloaded map
await mapEngine.registerMap('/path/to/Gibraltar.mwm', 251209);

// Track location
await for (final position in location.getPositionStream()) {
  print('Location: ${position.latitude}, ${position.longitude}');
}

// Save a bookmark
final bookmark = Bookmark(
  id: 'home',
  name: 'Home',
  location: Location(
    latitude: 36.1408,
    longitude: -5.3536,
    timestamp: DateTime.now(),
  ),
  category: BookmarkCategory.home,
  createdAt: DateTime.now(),
);
await bookmarks.saveBookmark(bookmark);
```

## Error Handling

All data sources throw specific exceptions:

- `MapEngineException` - Map engine operations
- `MapDownloadException` - Download operations
- `MapStorageException` - Storage operations
- `LocationException` - Location services
- `BookmarkDataSourceException` - Bookmark operations

## Testing

Unit tests for data sources should:

1. Mock external dependencies (agus_maps_flutter, geolocator, shared_preferences)
2. Test error handling and edge cases
3. Verify correct API usage
4. Test serialization/deserialization (for BookmarkDataSource)

## Next Steps

These data sources will be used by repository implementations in the next task:

- Task 6: Data Layer - Repository Implementations
