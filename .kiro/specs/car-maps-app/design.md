# Design Document: Car Maps Application

## Overview

The Car Maps Application is a Flutter-based navigation app designed specifically for vehicle driving scenarios. It leverages the agus_maps_flutter plugin to provide offline-first navigation with the CoMaps rendering engine. The application follows clean architecture principles with clear separation between domain, data, and presentation layers.

### Key Design Goals

1. **Offline-First**: All core functionality (map display, routing, search) works without internet
2. **Car-Optimized**: Large touch targets, high contrast, minimal interaction while driving
3. **Memory Efficient**: Stable memory usage during long navigation sessions using memory-mapped files
4. **Clean Architecture**: Testable, maintainable code with clear layer separation
5. **Platform-Native Performance**: Zero-copy GPU rendering on Android via the agus_maps_flutter plugin

### Technology Stack

- **Framework**: Flutter 3.x
- **Map Engine**: CoMaps via agus_maps_flutter plugin
- **State Management**: Bloc/Cubit pattern
- **Dependency Injection**: get_it
- **Local Storage**: shared_preferences, path_provider
- **Location Services**: geolocator
- **HTTP Client**: http (for map downloads)

## Architecture

The application follows Clean Architecture with three distinct layers:

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Screens    │  │    Blocs     │  │   Widgets    │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                      Domain Layer                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Entities   │  │  Use Cases   │  │ Repositories │      │
│  │              │  │              │  │ (Interfaces) │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                       Data Layer                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Repositories │  │ Data Sources │  │    Models    │      │
│  │    (Impl)    │  │              │  │              │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    External Services                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ agus_maps_   │  │  geolocator  │  │    http      │      │
│  │   flutter    │  │              │  │              │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

### Layer Responsibilities

**Presentation Layer**:

- UI screens and widgets
- State management (Blocs/Cubits)
- User input handling
- Display formatting

**Domain Layer**:

- Business entities (Route, MapRegion, Location, etc.)
- Use cases (CalculateRoute, DownloadMap, SearchPlaces, etc.)
- Repository interfaces (contracts)
- Business logic and rules

**Data Layer**:

- Repository implementations
- Data sources (local storage, map engine, location services)
- Data models and mappers
- Caching strategies

## Components and Interfaces

### Domain Layer Components

#### Entities

**Location**

```dart
class Location {
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? accuracy;
  final double? speed;
  final double? heading;
  final DateTime timestamp;
}
```

**Route**

```dart
class Route {
  final List<Location> waypoints;
  final double totalDistanceMeters;
  final int estimatedTimeSeconds;
  final List<RouteSegment> segments;
  final RouteBounds bounds;
}
```

**RouteSegment**

```dart
class RouteSegment {
  final Location start;
  final Location end;
  final TurnDirection turnDirection;
  final double distanceMeters;
  final String? streetName;
  final int? speedLimitKmh;
}
```

**MapRegion**

```dart
class MapRegion {
  final String id;
  final String name;
  final String fileName;
  final int sizeBytes;
  final String snapshotVersion;
  final RegionBounds bounds;
  final bool isDownloaded;
}
```

**NavigationState**

```dart
class NavigationState {
  final Route route;
  final Location currentLocation;
  final RouteSegment? currentSegment;
  final RouteSegment? nextSegment;
  final double distanceToNextTurnMeters;
  final double remainingDistanceMeters;
  final int remainingTimeSeconds;
  final bool isOffRoute;
}
```

**SearchResult**

```dart
class SearchResult {
  final String id;
  final String name;
  final String? address;
  final Location location;
  final SearchResultType type;
  final double? distanceMeters;
}
```

**Bookmark**

```dart
class Bookmark {
  final String id;
  final String name;
  final Location location;
  final BookmarkCategory category;
  final DateTime createdAt;
  final DateTime? lastUsedAt;
}
```

**BookmarkCategory**

```dart
enum BookmarkCategory {
  home,
  work,
  favorite,
  other,
}
```

#### Use Cases

**CalculateRouteUseCase**

```dart
class CalculateRouteUseCase {
  final RouteRepository repository;

  Future<Result<Route>> execute({
    required Location origin,
    required Location destination,
    required RoutingMode mode, // always VehicleMode for this app
  });
}
```

**StartNavigationUseCase**

```dart
class StartNavigationUseCase {
  final NavigationRepository repository;
  final LocationRepository locationRepository;

  Future<Result<void>> execute(Route route);
}
```

**DownloadMapRegionUseCase**

```dart
class DownloadMapRegionUseCase {
  final MapRepository repository;

  Stream<DownloadProgress> execute(MapRegion region);
}
```

**SearchPlacesUseCase**

```dart
class SearchPlacesUseCase {
  final SearchRepository repository;

  Future<Result<List<SearchResult>>> execute({
    required String query,
    Location? nearLocation,
    int maxResults = 20,
  });
}
```

**GetAvailableRegionsUseCase**

```dart
class GetAvailableRegionsUseCase {
  final MapRepository repository;

  Future<Result<List<MapRegion>>> execute();
}
```

**TrackLocationUseCase**

```dart
class TrackLocationUseCase {
  final LocationRepository repository;

  Stream<Location> execute();
}
```

**SaveBookmarkUseCase**

```dart
class SaveBookmarkUseCase {
  final BookmarkRepository repository;

  Future<Result<void>> execute(Bookmark bookmark);
}
```

**GetBookmarksUseCase**

```dart
class GetBookmarksUseCase {
  final BookmarkRepository repository;

  Future<Result<List<Bookmark>>> execute({BookmarkCategory? category});
}
```

**DeleteBookmarkUseCase**

```dart
class DeleteBookmarkUseCase {
  final BookmarkRepository repository;

  Future<Result<void>> execute(String bookmarkId);
}
```

#### Repository Interfaces

**RouteRepository**

```dart
abstract class RouteRepository {
  Future<Result<Route>> calculateRoute({
    required Location origin,
    required Location destination,
    required RoutingMode mode,
  });

  Future<Result<Route>> recalculateRoute({
    required Route originalRoute,
    required Location currentLocation,
  });
}
```

**NavigationRepository**

```dart
abstract class NavigationRepository {
  Future<void> startNavigation(Route route);
  Future<void> stopNavigation();
  Stream<NavigationState> getNavigationState();
  Future<void> updateLocation(Location location);
  bool get isNavigating;
}
```

**MapRepository**

```dart
abstract class MapRepository {
  Future<Result<List<MapRegion>>> getAvailableRegions();
  Future<Result<List<MapRegion>>> getDownloadedRegions();
  Stream<DownloadProgress> downloadRegion(MapRegion region);
  Future<Result<void>> deleteRegion(String regionId);
  Future<Result<void>> registerMapFile(String filePath);
  Future<int> getTotalStorageUsed();
}
```

**LocationRepository**

```dart
abstract class LocationRepository {
  Stream<Location> getLocationStream();
  Future<Location?> getCurrentLocation();
  Future<bool> requestPermissions();
  Future<bool> hasPermissions();
}
```

**SearchRepository**

```dart
abstract class SearchRepository {
  Future<Result<List<SearchResult>>> search({
    required String query,
    Location? nearLocation,
    int maxResults,
  });

  Future<Result<List<SearchResult>>> searchByCategory({
    required SearchCategory category,
    Location? nearLocation,
    int maxResults,
  });
}
```

**BookmarkRepository**

```dart
abstract class BookmarkRepository {
  Future<Result<List<Bookmark>>> getAllBookmarks();
  Future<Result<List<Bookmark>>> getBookmarksByCategory(BookmarkCategory category);
  Future<Result<Bookmark?>> getBookmarkById(String id);
  Future<Result<void>> saveBookmark(Bookmark bookmark);
  Future<Result<void>> updateBookmark(Bookmark bookmark);
  Future<Result<void>> deleteBookmark(String id);
}
```

### Data Layer Components

#### Repository Implementations

**RouteRepositoryImpl**

- Uses agus_maps_flutter native routing APIs
- Caches calculated routes
- Handles route recalculation on deviation

**NavigationRepositoryImpl**

- Manages navigation session state
- Tracks progress along route
- Detects off-route conditions
- Triggers route recalculation when needed

**MapRepositoryImpl**

- Uses MwmStorage from agus_maps_flutter for metadata
- Uses MirrorService from agus_maps_flutter for downloads
- Registers downloaded maps with CoMaps engine
- Validates map file integrity

**LocationRepositoryImpl**

- Wraps geolocator package
- Filters and smooths location updates
- Handles permission requests
- Provides location stream with error handling

**SearchRepositoryImpl**

- Uses CoMaps search APIs via agus_maps_flutter
- Searches within downloaded map regions
- Ranks results by relevance and distance
- Caches recent searches

#### Data Sources

**MapEngineDataSource**

```dart
class MapEngineDataSource {
  // Wraps agus_maps_flutter APIs
  Future<void> initializeEngine(String storagePath);
  Future<void> registerMap(String filePath, int version);
  Future<void> setMapView(double lat, double lon, int zoom);
  void invalidateMap();
  void forceRedraw();
}
```

**MapDownloadDataSource**

```dart
class MapDownloadDataSource {
  // Uses MirrorService from agus_maps_flutter
  final MirrorService mirrorService;

  Future<List<MwmRegion>> getAvailableRegions();
  Stream<DownloadProgress> downloadRegion(MwmRegion region, File destination);
}
```

**MapStorageDataSource**

```dart
class MapStorageDataSource {
  // Uses MwmStorage from agus_maps_flutter
  final MwmStorage storage;

  Future<List<MwmMetadata>> getDownloadedMaps();
  Future<void> saveMapMetadata(MwmMetadata metadata);
  Future<void> deleteMapMetadata(String regionName);
}
```

**LocationDataSource**

```dart
class LocationDataSource {
  // Wraps geolocator
  Stream<Position> getPositionStream();
  Future<Position> getCurrentPosition();
  Future<bool> requestPermission();
}
```

**BookmarkDataSource**

```dart
class BookmarkDataSource {
  // Uses shared_preferences for bookmark storage
  Future<List<Bookmark>> getAllBookmarks();
  Future<void> saveBookmark(Bookmark bookmark);
  Future<void> deleteBookmark(String id);
}
```

### Presentation Layer Components

#### Screens

**MapScreen**

- Displays the map using AgusMap widget
- Shows user location marker
- Handles map gestures (pan, zoom, rotate)
- Displays route overlay when route is calculated
- Shows navigation UI when navigation is active

**NavigationScreen**

- Full-screen navigation view
- Large turn indicators
- Speed and speed limit display
- Distance to next turn
- ETA and remaining distance
- Voice guidance controls

**SearchScreen**

- Search input field
- Search results list
- Recent searches
- Category filters
- Result selection triggers route calculation

**BookmarksScreen**

- List of all saved bookmarks
- Category filter (home, work, favorites, other)
- Bookmark details (name, location, category)
- Edit and delete options
- Navigate to bookmark option
- Add new bookmark button

**MapDownloadsScreen**

- List of available regions
- Download status indicators
- Storage usage display
- Delete downloaded maps
- Download progress for active downloads

**SettingsScreen**

- Theme selection (day/night/auto)
- Voice guidance settings
- Units (metric/imperial)
- Map data management
- About/version info

#### Blocs/Cubits

**MapCubit**

```dart
class MapCubit extends Cubit<MapState> {
  final AgusMapController mapController;

  void moveToLocation(Location location);
  void setZoom(int zoom);
  void showRoute(Route route);
  void clearRoute();
}
```

**NavigationBloc**

```dart
class NavigationBloc extends Bloc<NavigationEvent, NavigationState> {
  final StartNavigationUseCase startNavigation;
  final TrackLocationUseCase trackLocation;

  // Events: StartNavigation, UpdateLocation, StopNavigation
  // States: Idle, Navigating, OffRoute, Arrived
}
```

**RouteBloc**

```dart
class RouteBloc extends Bloc<RouteEvent, RouteState> {
  final CalculateRouteUseCase calculateRoute;

  // Events: CalculateRoute, RecalculateRoute, ClearRoute
  // States: Initial, Calculating, Calculated, Error
}
```

**MapDownloadBloc**

```dart
class MapDownloadBloc extends Bloc<MapDownloadEvent, MapDownloadState> {
  final DownloadMapRegionUseCase downloadRegion;
  final GetAvailableRegionsUseCase getAvailableRegions;

  // Events: LoadRegions, DownloadRegion, DeleteRegion
  // States: Loading, Loaded, Downloading, Error
}
```

**SearchBloc**

```dart
class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final SearchPlacesUseCase searchPlaces;

  // Events: SearchQuery, SelectResult, ClearSearch
  // States: Initial, Searching, Results, Error
}
```

**LocationBloc**

```dart
class LocationBloc extends Bloc<LocationEvent, LocationState> {
  final TrackLocationUseCase trackLocation;

  // Events: StartTracking, StopTracking, UpdateLocation
  // States: Idle, Tracking, PermissionDenied, Error
}
```

**BookmarkBloc**

```dart
class BookmarkBloc extends Bloc<BookmarkEvent, BookmarkState> {
  final GetBookmarksUseCase getBookmarks;
  final SaveBookmarkUseCase saveBookmark;
  final DeleteBookmarkUseCase deleteBookmark;

  // Events: LoadBookmarks, SaveBookmark, UpdateBookmark, DeleteBookmark, FilterByCategory
  // States: Initial, Loading, Loaded, Saving, Error
}
```

## Data Models

### Map Data Flow

```
User Location (GPS)
    ↓
LocationRepository → Location entity
    ↓
NavigationBloc → NavigationState
    ↓
NavigationScreen → UI Update
```

### Route Calculation Flow

```
User selects destination
    ↓
SearchBloc → SearchResult
    ↓
RouteBloc.calculateRoute(origin, destination)
    ↓
RouteRepository → CoMaps routing engine
    ↓
Route entity
    ↓
MapCubit.showRoute(route)
    ↓
Map displays route overlay
```

### Map Download Flow

```
User selects region
    ↓
MapDownloadBloc.downloadRegion(region)
    ↓
MapRepository → MirrorService
    ↓
Stream<DownloadProgress>
    ↓
MapDownloadBloc emits progress states
    ↓
UI shows progress bar
    ↓
On completion: MapRepository.registerMapFile()
    ↓
CoMaps engine loads new map
```

### Navigation Flow

```
Route calculated
    ↓
NavigationBloc.startNavigation(route)
    ↓
NavigationRepository.startNavigation()
    ↓
LocationBloc streams location updates
    ↓
NavigationRepository.updateLocation()
    ↓
Calculate current segment, distance to turn
    ↓
NavigationBloc emits NavigationState
    ↓
NavigationScreen updates UI
    ↓
Voice guidance triggered at turn points
```

## Correctness Properties

_A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees._

### Property 1: Vehicle Mode Routing

_For any_ route calculation request, the routing mode parameter SHALL be set to VehicleMode (not pedestrian mode), ensuring all routes are optimized for driving.
**Validates: Requirements 2.3, 5.1**

### Property 2: Map State Persistence Across Orientation Changes

_For any_ map view state (location, zoom level), when the device orientation changes, the map SHALL restore the same view state after the orientation change completes.
**Validates: Requirements 2.5**

### Property 3: Map Download Completeness

_For any_ map region download, when the download completes successfully, the application SHALL: (1) save the MWM file to local storage, (2) persist metadata (region name, version, size, date), (3) register the file with the CoMaps engine, and (4) mark the region as downloaded.
**Validates: Requirements 3.2, 3.4, 3.5, 3.6**

### Property 4: Download Progress Reporting

_For any_ map download in progress, the download stream SHALL emit progress events containing bytes received and total bytes, with bytes received monotonically increasing until it equals total bytes.
**Validates: Requirements 3.3**

### Property 5: Map Deletion Completeness

_For any_ downloaded map region, when deletion is requested, the application SHALL remove both the MWM file from disk and the metadata from storage, such that subsequent queries show the region as not downloaded.
**Validates: Requirements 3.7**

### Property 6: Storage Calculation Accuracy

_For any_ set of downloaded maps, the total storage used SHALL equal the sum of all individual map file sizes from their metadata.
**Validates: Requirements 3.8**

### Property 7: Metadata Persistence Round-Trip

_For any_ map metadata (region name, version, size, date), if saved to storage and then retrieved, the retrieved metadata SHALL be equivalent to the original metadata.
**Validates: Requirements 3.6, 12.1**

### Property 8: Location Updates Affect Map State

_For any_ location update received while tracking is active, the application SHALL update the map to reflect: (1) the new position marker location, (2) the map orientation if heading is available, and (3) trigger accuracy indicators if accuracy is below threshold.
**Validates: Requirements 4.2, 4.3, 4.4, 4.6**

### Property 9: Route Calculation Produces Complete Data

_For any_ successful route calculation from origin to destination, the resulting Route SHALL contain: (1) waypoints, (2) total distance > 0, (3) estimated time > 0, (4) at least one route segment, and (5) the route SHALL be displayed on the map.
**Validates: Requirements 5.2, 5.3**

### Property 10: Route Calculation Error Handling

_For any_ route calculation that fails, the application SHALL display an error message containing the failure reason (e.g., "no map data for region", "destination unreachable").
**Validates: Requirements 5.6, 13.3**

### Property 11: Navigation State Transitions

_For any_ route, when navigation starts, the application SHALL transition to NavigationState with: (1) isNavigating = true, (2) current location tracking active, (3) screen wake lock enabled, and (4) voice guidance enabled by default.
**Validates: Requirements 6.1, 9.4, 14.1**

### Property 12: Turn Instruction Progression

_For any_ navigation session, when the user's location passes a turn point (within threshold distance), the application SHALL advance to the next route segment and update the turn instruction display.
**Validates: Requirements 6.4**

### Property 13: Off-Route Detection and Recalculation

_For any_ navigation session, when the user's location deviates from the route by more than a threshold distance, the application SHALL: (1) set isOffRoute = true, (2) trigger automatic route recalculation from current location to original destination.
**Validates: Requirements 6.5**

### Property 14: Navigation Speed Display

_For any_ navigation state with location data, the application SHALL display: (1) current speed from GPS, (2) speed limit from map data (if available), and (3) highlight the speed limit warning when current speed exceeds the limit.
**Validates: Requirements 6.6, 15.1, 15.2, 15.3**

### Property 15: Navigation Arrival Detection

_For any_ navigation session, when the user's location is within arrival threshold distance of the destination, the application SHALL: (1) end the navigation session, (2) set isNavigating = false, (3) notify the user of arrival.
**Validates: Requirements 6.7**

### Property 16: Search Within Downloaded Regions

_For any_ search query, all returned results SHALL come from regions that are marked as downloaded, ensuring offline search capability.
**Validates: Requirements 7.1**

### Property 17: Search Result Selection Updates Map

_For any_ search result selected by the user, the application SHALL: (1) center the map on the result's location, (2) display a marker at the location, (3) optionally trigger route calculation to that location.
**Validates: Requirements 7.3**

### Property 18: Empty Search Results Handling

_For any_ search query that returns zero results, the application SHALL display a "no matches found" message instead of an empty list.
**Validates: Requirements 7.5**

### Property 19: Theme Synchronization

_For any_ system theme change event (light to dark or dark to light), the application SHALL update the map style to match within one frame.
**Validates: Requirements 8.2**

### Property 20: Touch Target Minimum Size

_For all_ interactive UI elements (buttons, list items, controls), the touch target size SHALL be at least 48dp in both width and height.
**Validates: Requirements 9.1**

### Property 21: User Preferences Persistence Round-Trip

_For any_ user preference (theme setting, voice guidance enabled, unit preference), if saved and then the app is restarted, the retrieved preference SHALL equal the saved value.
**Validates: Requirements 12.2**

### Property 22: Map View State Restoration

_For any_ map view state (latitude, longitude, zoom), when the app is closed and reopened, the map SHALL restore to the same view state (within tolerance).
**Validates: Requirements 12.3**

### Property 23: Search History Persistence

_For any_ search query executed, the query SHALL appear in search history, and SHALL persist across app restarts.
**Validates: Requirements 12.4**

### Property 24: Favorite Locations Persistence Round-Trip

_For any_ location marked as favorite, the location SHALL persist across app restarts and SHALL be retrievable with the same coordinates and name.
**Validates: Requirements 12.5**

### Property 25: Download Error Handling

_For any_ map download that fails, the application SHALL: (1) display an error message with the failure reason, (2) provide a retry button, (3) not save incomplete metadata.
**Validates: Requirements 13.1**

### Property 26: Permission Error Guidance

_For any_ location permission denial, the application SHALL display a message explaining: (1) why location is needed, (2) how to enable it in system settings.
**Validates: Requirements 13.2**

### Property 27: General Error Handling

_For any_ unexpected error caught by the application, the error SHALL be: (1) logged with stack trace, (2) displayed to user with a friendly message, (3) not crash the application.
**Validates: Requirements 13.4**

### Property 28: Map File Validation

_For any_ downloaded map file, validation SHALL detect: (1) file existence, (2) file size matches metadata, (3) file is not corrupted (can be opened by CoMaps engine).
**Validates: Requirements 13.5**

### Property 29: Voice Guidance Toggle

_For any_ voice guidance toggle action, the voice enabled state SHALL change from enabled to disabled or vice versa, and subsequent turn announcements SHALL respect the new state.
**Validates: Requirements 14.4**

### Property 30: Turn Voice Announcements

_For any_ navigation session with voice enabled, when approaching a turn (within announcement distance threshold), the application SHALL trigger a voice announcement containing the turn direction and distance.
**Validates: Requirements 6.3, 14.2**

### Property 31: Speed Unit Display

_For any_ speed value displayed (current speed or speed limit), the value SHALL be converted to and displayed in the user's preferred units (km/h or mph) according to their settings.
**Validates: Requirements 15.4**

### Property 32: Speed Limit Conditional Display

_For any_ navigation state, the speed limit display SHALL be visible if and only if speed limit data is available for the current road segment.
**Validates: Requirements 15.5**

### Property 33: Bookmark Persistence Round-Trip

_For any_ bookmark saved with name, location, and category, retrieving the bookmark SHALL return the same data, and the bookmark SHALL persist across app restarts.
**Validates: Requirements 16.2, 16.8**

### Property 34: Bookmark Display on Map

_For any_ saved bookmark, when viewing the map, a bookmark marker SHALL be displayed at the bookmark's location.
**Validates: Requirements 16.10**

### Property 35: Bookmark Selection Navigation

_For any_ bookmark selected by the user, the application SHALL: (1) center the map on the bookmark location, (2) offer to calculate a route to that location.
**Validates: Requirements 16.4, 16.5**

### Property 36: Bookmark Deletion Completeness

_For any_ bookmark, when deletion is requested, the bookmark SHALL be removed from storage such that subsequent queries do not return it, and its marker SHALL be removed from the map.
**Validates: Requirements 16.6**

### Property 37: Bookmark Category Filtering

_For any_ bookmark category filter applied, only bookmarks matching that category SHALL be displayed in the bookmarks list.
**Validates: Requirements 16.9**

## Error Handling

### Error Categories

**Network Errors**

- Mirror unavailable during map download
- Timeout during region list fetch
- Strategy: Retry with exponential backoff, fallback to alternative mirrors

**Location Errors**

- Permission denied
- GPS unavailable
- Low accuracy
- Strategy: Display clear messages, guide user to settings, degrade gracefully

**Routing Errors**

- No map data for region
- Destination unreachable
- Route calculation timeout
- Strategy: Display specific error messages, suggest downloading required maps

**Storage Errors**

- Insufficient disk space
- File write failure
- Corrupted map file
- Strategy: Check available space before download, validate files, provide cleanup options

**Engine Errors**

- CoMaps initialization failure
- Map registration failure
- Rendering errors
- Strategy: Log detailed errors, attempt recovery, fallback to error screen

### Error Recovery Strategies

**Automatic Recovery**

- Off-route detection → automatic reroute
- Network loss during navigation → continue with offline data
- Temporary GPS loss → dead reckoning with last known heading

**User-Initiated Recovery**

- Download failure → retry button
- Route calculation failure → suggest alternative destinations
- Permission denial → guide to settings

**Graceful Degradation**

- No map data → show blank map with message
- No GPS → allow manual location selection
- Low accuracy → show accuracy indicator, continue navigation

## Testing Strategy

### Dual Testing Approach

The application will use both unit tests and property-based tests for comprehensive coverage:

**Unit Tests** focus on:

- Specific examples of correct behavior (e.g., "downloading Gibraltar.mwm succeeds")
- Edge cases (e.g., empty search query, zero-byte file)
- Integration points between layers (e.g., repository calling data source)
- Error conditions (e.g., network timeout, permission denied)

**Property-Based Tests** focus on:

- Universal properties that hold for all inputs (e.g., "for any route, distance > 0")
- Comprehensive input coverage through randomization
- Invariants that must always hold (e.g., "downloaded regions always have metadata")
- Round-trip properties (e.g., "save then load returns same data")

### Property-Based Testing Configuration

**Framework**: Use `test` package with custom property test helpers (Flutter doesn't have a mature PBT library like QuickCheck, so we'll implement basic property testing patterns)

**Test Configuration**:

- Minimum 100 iterations per property test
- Each property test references its design document property number
- Tag format: `@Tags(['feature:car-maps-app', 'property:N'])`

**Example Property Test Structure**:

```dart
@Tags(['feature:car-maps-app', 'property:7'])
test('Property 7: Metadata Persistence Round-Trip', () async {
  // Run 100 iterations with random metadata
  for (int i = 0; i < 100; i++) {
    final metadata = generateRandomMetadata();

    await storage.saveMetadata(metadata);
    final retrieved = await storage.getMetadata(metadata.regionName);

    expect(retrieved, equals(metadata));
  }
});
```

### Test Coverage Goals

- **Unit Test Coverage**: 80%+ line coverage
- **Property Test Coverage**: All 32 correctness properties implemented
- **Integration Test Coverage**: Critical user flows (download map, calculate route, navigate)
- **Widget Test Coverage**: All screens and major widgets

### Testing Layers

**Domain Layer Tests**:

- Use case logic (pure business logic)
- Entity validation
- Repository interface contracts

**Data Layer Tests**:

- Repository implementations
- Data source interactions
- Model serialization/deserialization
- Caching behavior

**Presentation Layer Tests**:

- Bloc state transitions
- Widget rendering
- User interaction handling
- Navigation flows

### Mock Strategy

**What to Mock**:

- External services (agus_maps_flutter, geolocator, http)
- Platform channels
- File system operations
- Time-dependent operations

**What NOT to Mock**:

- Domain entities (test with real objects)
- Value objects
- Pure functions
- Simple data transformations

### Integration Testing

**Critical Flows to Test**:

1. App startup → map initialization → location tracking
2. Search place → calculate route → start navigation
3. Download map → register with engine → verify rendering
4. Navigate route → go off-route → automatic reroute
5. Change theme → map style updates → persist preference

**Integration Test Environment**:

- Use Flutter integration_test package
- Run on real devices or emulators
- Test with actual map files (small test regions)
- Simulate location updates with mock GPS data

### Performance Testing

**Metrics to Monitor**:

- Memory usage during navigation (should remain stable)
- Frame rate during map rendering (target 60fps)
- Route calculation time (< 2 seconds for typical routes)
- Map download speed (limited by network, not app)
- App startup time (< 3 seconds to map display)

**Performance Test Scenarios**:

- Long navigation session (2+ hours)
- Large map file download (500MB+)
- Rapid zoom/pan gestures
- Multiple route recalculations
- Low-end device testing

### Test Data

**Map Files**:

- Use small test regions (Gibraltar, Monaco) for fast tests
- Include World.mwm and WorldCoasts.mwm for basic functionality
- Test with corrupted files for validation tests

**Location Data**:

- Generate realistic GPS tracks for navigation tests
- Include edge cases (tunnels, GPS loss, rapid direction changes)
- Test with various accuracy levels

**Search Queries**:

- Common place names
- Addresses in different formats
- Category searches
- Empty queries
- Very long queries
- Special characters

## Implementation Notes

### Dependency Injection Setup

Use `get_it` for service locator pattern:

```dart
final getIt = GetIt.instance;

void setupDependencies() {
  // External services
  getIt.registerLazySingleton(() => MwmStorage.create());
  getIt.registerLazySingleton(() => MirrorService());

  // Data sources
  getIt.registerLazySingleton(() => MapEngineDataSource());
  getIt.registerLazySingleton(() => LocationDataSource());

  // Repositories
  getIt.registerLazySingleton<MapRepository>(
    () => MapRepositoryImpl(
      engineDataSource: getIt(),
      storageDataSource: getIt(),
      downloadDataSource: getIt(),
    ),
  );

  // Use cases
  getIt.registerLazySingleton(
    () => DownloadMapRegionUseCase(getIt()),
  );

  // Blocs
  getIt.registerFactory(
    () => MapDownloadBloc(
      downloadRegion: getIt(),
      getAvailableRegions: getIt(),
    ),
  );
}
```

### State Management Pattern

Use Bloc pattern with clear event/state definitions:

```dart
// Events are user actions or system events
abstract class MapDownloadEvent {}
class LoadAvailableRegions extends MapDownloadEvent {}
class DownloadRegion extends MapDownloadEvent {
  final MapRegion region;
}

// States represent UI states
abstract class MapDownloadState {}
class MapDownloadInitial extends MapDownloadState {}
class MapDownloadLoading extends MapDownloadState {}
class MapDownloadLoaded extends MapDownloadState {
  final List<MapRegion> regions;
}
class MapDownloadDownloading extends MapDownloadState {
  final MapRegion region;
  final double progress;
}
```

### File Organization

```
lib/
├── main.dart
├── app/
│   ├── app.dart
│   └── di/
│       └── injection.dart
├── core/
│   ├── error/
│   ├── utils/
│   └── constants/
├── features/
│   ├── map/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   ├── repositories/
│   │   │   └── usecases/
│   │   ├── data/
│   │   │   ├── models/
│   │   │   ├── datasources/
│   │   │   └── repositories/
│   │   └── presentation/
│   │       ├── blocs/
│   │       ├── screens/
│   │       └── widgets/
│   ├── navigation/
│   │   └── [same structure]
│   ├── search/
│   │   └── [same structure]
|   ├── bookmarks/
│   |    └── [same structure]
│   └── downloads/
│       └── [same structure]
└── shared/
    ├── widgets/
    └── utils/
```

### Platform-Specific Considerations

**Android**:

- Request location permissions at runtime
- Handle background location for navigation
- Manage wake lock during navigation
- Handle app lifecycle (pause/resume)

**iOS** (future):

- Request "Always" location permission for background navigation
- Handle background modes
- Manage battery usage during navigation

### Performance Optimizations

1. **Lazy Loading**: Load map regions on demand
2. **Caching**: Cache calculated routes and search results
3. **Debouncing**: Debounce search input and map gestures
4. **Memory Management**: Release resources when not navigating
5. **Background Processing**: Use isolates for heavy computations

### Accessibility Considerations

1. **Screen Reader Support**: Label all interactive elements
2. **High Contrast**: Support system high contrast mode
3. **Font Scaling**: Respect system font size settings
4. **Voice Control**: Ensure all actions are accessible via voice
5. **Haptic Feedback**: Provide tactile feedback for important actions
