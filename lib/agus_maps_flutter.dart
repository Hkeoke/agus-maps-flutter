import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:ffi' hide Size;
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:ffi/ffi.dart';

import 'agus_maps_flutter_bindings_generated.dart';

// Export additional services
export 'mwm_storage.dart';
export 'mirror_service.dart';

/// A very short-lived native function.
///
/// For very short-lived functions, it is fine to call them on the main isolate.
/// They will block the Dart execution while running the native function, so
/// only do this for native functions which are guaranteed to be short-lived.
int sum(int a, int b) => _bindings.sum(a, b);

/// A longer lived native function, which occupies the thread calling it.
///
/// Do not call these kind of native functions in the main isolate. They will
/// block Dart execution. This will cause dropped frames in Flutter applications.
/// Instead, call these native functions on a separate isolate.
///
/// Modify this to suit your own use case. Example use cases:
///
/// 1. Reuse a single isolate for various different kinds of requests.
/// 2. Use multiple helper isolates for parallel execution.
Future<int> sumAsync(int a, int b) async {
  final SendPort helperIsolateSendPort = await _helperIsolateSendPort;
  final int requestId = _nextSumRequestId++;
  final _SumRequest request = _SumRequest(requestId, a, b);
  final Completer<int> completer = Completer<int>();
  _sumRequests[requestId] = completer;
  helperIsolateSendPort.send(request);
  return completer.future;
}

// Routing event types from native engine
class RoutingEvent {
  static const int buildStarted = 0;
  static const int buildReady = 1;
  static const int buildFailed = 2;
  static const int rebuildStarted = 3;

  final int type;
  final int code;

  RoutingEvent(this.type, this.code);
}

final _channel = const MethodChannel('agus_maps_flutter');

final StreamController<int> _placePageEventController = StreamController<int>.broadcast();
final StreamController<int> _myPositionModeChangedController = StreamController<int>.broadcast();
final StreamController<RoutingEvent> _routingEventController = StreamController<RoutingEvent>.broadcast();
bool _channelInitialized = false;

void _ensureChannelInitialized() {
  if (_channelInitialized) return;
  _channel.setMethodCallHandler((call) async {
    if (call.method == 'onPlacePageEvent') {
      final int type = call.arguments as int;
      _placePageEventController.add(type);
    } else if (call.method == 'onMyPositionModeChanged') {
      final int mode = call.arguments as int;
      _myPositionModeChangedController.add(mode);
    } else if (call.method == 'onRoutingEvent') {
      final args = call.arguments as Map<dynamic, dynamic>;
      final type = args['type'] as int;
      final code = args['code'] as int;
      _routingEventController.add(RoutingEvent(type, code));
    }
  });
  _channelInitialized = true;
}

Future<String> extractMap(String assetPath) async {
  final String? path = await _channel.invokeMethod('extractMap', {
    'assetPath': assetPath,
  });
  return path!;
}

/// Extract all CoMaps data files (classificator, types, categories, etc.)
/// Returns the path to the directory containing the extracted files.
Future<String> extractDataFiles() async {
  final String? path = await _channel.invokeMethod('extractDataFiles');
  return path!;
}

Future<String> getApkPath() async {
  final String? path = await _channel.invokeMethod('getApkPath');
  return path!;
}

void init(String apkPath, String storagePath) {
  final apkPathPtr = apkPath.toNativeUtf8().cast<Char>();
  final storagePathPtr = storagePath.toNativeUtf8().cast<Char>();
  _bindings.comaps_init(apkPathPtr, storagePathPtr);
  malloc.free(apkPathPtr);
  malloc.free(storagePathPtr);
}

/// Check status of map for given coordinates.
/// Returns:
/// 0 - Undefined
/// 1 - OnDisk (Downloaded)
/// 2 - NotDownloaded
/// 3 - DownloadFailed
/// 4 - Downloading
/// 5 - InQueue
/// 6 - OnDiskOutOfDate
Future<int> checkMapStatus(double lat, double lon) async {
  final int status = await _channel.invokeMethod('checkMapStatus', {
    'lat': lat,
    'lon': lon,
  });
  return status;
}

Future<String?> getCountryName(double lat, double lon) async {
  return await _channel.invokeMethod('getCountryName', {'lat': lat, 'lon': lon});
}

/// Initialize CoMaps with separate resource and writable paths
void initWithPaths(String resourcePath, String writablePath) {
  final resourcePathPtr = resourcePath.toNativeUtf8().cast<Char>();
  final writablePathPtr = writablePath.toNativeUtf8().cast<Char>();
  _bindings.comaps_init_paths(resourcePathPtr, writablePathPtr);
  malloc.free(resourcePathPtr);
  malloc.free(writablePathPtr);
}

void loadMap(String path) {
  final pathPtr = path.toNativeUtf8().cast<Char>();
  _bindings.comaps_load_map_path(pathPtr);
  malloc.free(pathPtr);
}

/// Register a single MWM map file directly by full path.
///
/// This bypasses the version folder scanning and registers the map file
/// directly with the rendering engine. Use this for MWM files that are
/// not in the standard version directory structure.
///
/// Returns 0 on success, negative values on error:
///   -1: Framework not initialized (call after map surface is created)
///   -2: Exception during registration
///   >0: MwmSet::RegResult error code
int registerSingleMap(String fullPath) {
  // Normalize path separators for Windows (convert / to \)
  String normalizedPath = fullPath;
  if (Platform.isWindows) {
    normalizedPath = fullPath.replaceAll('/', '\\');
  }
  final pathPtr = normalizedPath.toNativeUtf8().cast<Char>();
  try {
    return _bindings.comaps_register_single_map(pathPtr);
  } finally {
    malloc.free(pathPtr);
  }
}

/// Register a single MWM map file directly by full path, with an explicit
/// snapshot version (e.g. 251209).
///
/// This avoids the native side defaulting the LocalCountryFile version to 0,
/// which can cause `VersionTooOld (2)` for World/WorldCoasts and any region
/// where the engine expects a specific snapshot version.
int registerSingleMapWithVersion(String fullPath, int version) {
  String normalizedPath = fullPath;
  if (Platform.isWindows) {
    normalizedPath = fullPath.replaceAll('/', '\\');
  }
  final pathPtr = normalizedPath.toNativeUtf8().cast<Char>();
  try {
    try {
      return _bindings.comaps_register_single_map_with_version(
          pathPtr, version);
    } on ArgumentError {
      // Symbol may not exist on some platforms/binaries. Fall back to legacy API.
      return _bindings.comaps_register_single_map(pathPtr);
    }
  } finally {
    malloc.free(pathPtr);
  }
}

/// Debug: List all registered MWMs and their bounds.
/// Output goes to Android logcat (tag: AgusMapsFlutterNative).
void debugListMwms() {
  _bindings.comaps_debug_list_mwms();
}

/// Debug: Check if a lat/lon point is covered by any registered MWM.
/// Output goes to Android logcat (tag: AgusMapsFlutterNative).
///
/// Use this to verify that a specific location (like Manila) is covered
/// by one of the registered MWM files.
void debugCheckPoint(double lat, double lon) {
  _bindings.comaps_debug_check_point(lat, lon);
}

void setView(double lat, double lon, int zoom) {
  _bindings.comaps_set_view(lat, lon, zoom);
}

/// Invalidate the current viewport to force tile reload.
/// Call this after registering maps to ensure tiles are refreshed.
void invalidateMap() {
  _bindings.comaps_invalidate();
}

/// Map style enum matching CoMaps MapStyle
enum MapStyle {
  defaultLight(0),
  defaultDark(1),
  merged(2),
  vehicleLight(3),
  vehicleDark(4),
  outdoorsLight(5),
  outdoorsDark(6);

  const MapStyle(this.value);
  final int value;

  static MapStyle fromValue(int value) {
    return MapStyle.values.firstWhere(
      (style) => style.value == value,
      orElse: () => MapStyle.defaultLight,
    );
  }
}

/// Set the map style (day/night, vehicle mode, etc.)
///
/// Available styles:
/// - [MapStyle.defaultLight]: Default light theme
/// - [MapStyle.defaultDark]: Default dark theme
/// - [MapStyle.vehicleLight]: Vehicle navigation light theme (recommended for car apps)
/// - [MapStyle.vehicleDark]: Vehicle navigation dark theme (recommended for car apps)
/// - [MapStyle.outdoorsLight]: Outdoor/hiking light theme
/// - [MapStyle.outdoorsDark]: Outdoor/hiking dark theme
///
/// For car navigation apps, use [MapStyle.vehicleLight] for day mode
/// and [MapStyle.vehicleDark] for night mode.
void setMapStyle(MapStyle style) {
  _bindings.comaps_set_map_style(style.value);
}

/// Get the current map style
MapStyle getMapStyle() {
  final styleValue = _bindings.comaps_get_map_style();
  return MapStyle.fromValue(styleValue);
}

/// Force a complete redraw by updating the map style.
///
/// This clears all render groups and forces the BackendRenderer to re-request
/// all tiles from scratch. Use this after registering map files to ensure
/// tiles are loaded for newly registered regions.
///
/// This is more heavy-handed than [invalidateMap] and should be called when
/// maps are registered AFTER the DrapeEngine has been initialized, as the
/// engine may have already calculated tile coverage before the maps were
/// available.
void forceRedraw() {
  _bindings.comaps_force_redraw();
}

/// Touch event types
enum TouchType {
  none, // 0
  down, // 1
  move, // 2
  up, // 3
  cancel, // 4
}

/// Send a touch event to the map engine.
///
/// [type] is the touch event type (down, move, up, cancel).
/// [id1], [x1], [y1] are the first pointer's ID and coordinates.
/// [id2], [x2], [y2] are the second pointer's data (use -1 for id2 if single touch).
void sendTouchEvent(
  TouchType type,
  int id1,
  double x1,
  double y1, {
  int id2 = -1,
  double x2 = 0,
  double y2 = 0,
}) {
  _bindings.comaps_touch(type.index, id1, x1, y1, id2, x2, y2);
}

/// Scale (zoom) the map by a factor, centered on a specific pixel point.
///
/// [factor] is the zoom factor (>1 zooms in, <1 zooms out).
/// Use `exp(scrollDelta)` for smooth Google Maps-like scrolling.
/// [pixelX], [pixelY] are the screen coordinates to zoom towards (in physical pixels).
/// [animated] controls whether to animate the zoom transition.
///
/// This is the preferred method for scroll wheel zoom on desktop platforms,
/// matching the behavior of the Qt implementation.
void scaleMap(
  double factor,
  double pixelX,
  double pixelY, {
  bool animated = false,
}) {
  _bindings.comaps_scale(factor, pixelX, pixelY, animated ? 1 : 0);
}

/// Scroll/pan the map by pixel distance.
///
/// [distanceX], [distanceY] are the distances to scroll in physical pixels.
void scrollMap(double distanceX, double distanceY) {
  _bindings.comaps_scroll(distanceX, distanceY);
}

/// Create a map rendering surface with the given dimensions.
/// If width/height are not specified, uses the screen size.
/// [density] is the device pixel ratio (e.g., 1.5 for 150% scaling on Windows).
Future<int> createMapSurface({int? width, int? height, double? density}) async {
  final int? textureId = await _channel.invokeMethod('createMapSurface', {
    if (width != null) 'width': width,
    if (height != null) 'height': height,
    if (density != null) 'density': density,
  });
  return textureId!;
}

/// Resize the map surface to new dimensions.
///
/// [density] is optional; on Windows it updates visual scale when display DPI changes.
Future<void> resizeMapSurface(int width, int height, {double? density}) async {
  await _channel.invokeMethod('resizeMapSurface', {
    'width': width,
    'height': height,
    if (density != null) 'density': density,
  });
}

/// Controller for programmatic control of an AgusMap.
///
/// Use this to move the map, change zoom level, and other operations.
class AgusMapController {
  /// Move the map to the specified coordinates and zoom level.
  ///
  /// [lat] and [lon] specify the center point in WGS84 coordinates.
  /// [zoom] is the zoom level (typically 0-20, where higher is more zoomed in).
  void moveToLocation(double lat, double lon, int zoom) {
    setView(lat, lon, zoom);
  }

  /// Animate the map to the specified coordinates.
  /// Currently this is the same as moveToLocation; animation support
  /// will be added in a future version.
  void animateToLocation(double lat, double lon, int zoom) {
    // TODO: Implement animated camera movement
    setView(lat, lon, zoom);
  }

  /// Zoom in by one level.
  void zoomIn() {
    _channel.invokeMethod('scale', {'factor': 2.0});
  }

  /// Zoom out by one level.
  void zoomOut() {
    _channel.invokeMethod('scale', {'factor': 0.5});
  }

  /// Switch to next "My Position" mode (cycles through: off -> follow -> follow+rotate).
  void switchMyPositionMode() {
    _channel.invokeMethod('switchMyPositionMode');
  }

  /// Get current "My Position" mode.
  /// Returns: 0=PENDING, 1=NOT_FOLLOW_NO_POSITION, 2=NOT_FOLLOW, 3=FOLLOW, 4=FOLLOW_AND_ROTATE
  Future<int> getMyPositionMode() async {
    final mode = await _channel.invokeMethod('getMyPositionMode');
    return mode ?? 0;
  }

  /// Set "My Position" mode directly.
  /// mode: 0=PENDING, 1=NOT_FOLLOW_NO_POSITION, 2=NOT_FOLLOW, 3=FOLLOW, 4=FOLLOW_AND_ROTATE
  Future<void> setMyPositionMode(int mode) async {
    await _channel.invokeMethod('setMyPositionMode', {'mode': mode});
  }

  /// Send GPS update to native engine for "My Position" arrow rendering.
  void setMyPosition(double lat, double lon, double accuracy, double bearing, double speed, int time) {
    _channel.invokeMethod('onLocationUpdate', {
      'lat': lat, 
      'lon': lon, 
      'accuracy': accuracy, 
      'bearing': bearing, 
      'speed': speed, 
      'time': time
    });
  }

  /// Send Compass update to native engine for map rotation.
  /// [bearing] is the compass heading in degrees (0-360).
  void setCompass(double bearing) {
    _channel.invokeMethod('onCompassUpdate', {
      'bearing': bearing,
    });
  }

  /// Set map style (Light vs Dark).
  /// [isDark] true for Night/Dark mode, false for Day/Light mode.
  Future<void> setMapStyle(bool isDark) async {
    await _channel.invokeMethod('setMapStyle', {'style': isDark ? 1 : 0});
  }

  /// Stream of selection events from the map.
  /// True = Object selected (PlacePage Open)
  /// False = Object deselected (PlacePage Close)
  Stream<bool> get onSelectionChanged => 
      _placePageEventController.stream.map((type) => type == 0);

  /// Stream of My Position mode changes.
  /// Emits the new mode whenever it changes:
  /// 0=PENDING_POSITION, 1=NOT_FOLLOW_NO_POSITION, 2=NOT_FOLLOW, 3=FOLLOW, 4=FOLLOW_AND_ROTATE
  Stream<int> get onMyPositionModeChanged {
    _ensureChannelInitialized();
    return _myPositionModeChangedController.stream;
  }

  /// Stream of Routing events.
  /// Events include:
  /// - buildStarted (0)
  /// - buildReady (1)
  /// - buildFailed (2)
  /// - rebuildStarted (3) - Triggered when engine recommends rebuild (e.g. off-route)
  Stream<RoutingEvent> get onRoutingEvent {
    _ensureChannelInitialized();
    return _routingEventController.stream;
  }

  /// Get details of the currently selected object.
  Future<Map<String, dynamic>?> getSelectionInfo() async {
    final String? jsonStr = await _channel.invokeMethod('getPlacePageInfo');
    if (jsonStr == null) return null;
    try {
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error decoding PlacePage info: $e');
      return null;
    }
  }

  /// Build a route from My Position to the target coordinates.
  Future<void> buildRoute(double lat, double lon) async {
    await _channel.invokeMethod('buildRoute', {'lat': lat, 'lon': lon});
  }

  /// Stop current navigation/routing.
  Future<void> stopRouting() async {
    await _channel.invokeMethod('stopRouting');
  }

  /// Get real-time route following information during navigation.
  /// Returns a Map with navigation data including:
  /// - distanceToTarget: Remaining distance to destination
  /// - timeToTarget: Estimated time to arrival (seconds)
  /// - distanceToTurn: Distance to next turn
  /// - turn: Current turn instruction
  /// - nextTurn: Next turn instruction
  /// - speedMps: Current speed in meters per second
  /// - speedLimitMps: Speed limit in meters per second
  /// - completionPercent: Route completion percentage
  Future<Map<String, dynamic>?> getRouteFollowingInfo() async {
    final String? jsonStr = await _channel.invokeMethod('getRouteFollowingInfo');
    if (jsonStr == null) return null;
    try {
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error decoding route following info: $e');
      return null;
    }
  }

  /// Generate turn-by-turn voice notifications.
  /// Returns an array of strings to be spoken by TTS.
  /// [announceStreets]: Whether to include street names in notifications.
  Future<List<String>?> generateNotifications({bool announceStreets = true}) async {
    final List<dynamic>? notifications = await _channel.invokeMethod(
      'generateNotifications',
      {'announceStreets': announceStreets},
    );
    return notifications?.cast<String>();
  }

  /// Check if the route has been completed.
  Future<bool> isRouteFinished() async {
    final bool? finished = await _channel.invokeMethod('isRouteFinished');
    return finished ?? false;
  }

  /// Disable route following mode (but keep the route displayed).
  Future<void> disableFollowing() async {
    await _channel.invokeMethod('disableFollowing');
  }

  /// Remove the current route completely.
  Future<void> removeRoute() async {
    await _channel.invokeMethod('removeRoute');
  }

  /// Activate route following mode (navigation mode).
  /// This should be called after a route has been successfully built.
  Future<void> followRoute() async {
    await _channel.invokeMethod('followRoute');
  }
}

/// A Flutter widget that displays a CoMaps map.
///
/// The widget handles initialization, sizing, and gesture events.
class AgusMap extends StatefulWidget {
  /// Initial latitude for the map center.
  final double? initialLat;

  /// Initial longitude for the map center.
  final double? initialLon;

  /// Initial zoom level (0-20).
  final int? initialZoom;

  /// Callback when the map is ready.
  final VoidCallback? onMapReady;

  /// Controller for programmatic map control.
  /// If not provided, the map can only be controlled via gestures.
  final AgusMapController? controller;

  /// Whether the map is currently visible.
  ///
  /// When false, resize operations are skipped to avoid unnecessary
  /// memory allocations (e.g., CVPixelBuffer recreation on iOS).
  /// This is important when using IndexedStack where the map widget
  /// remains in the tree but is not visible.
  ///
  /// The resize will be applied when the map becomes visible again.
  final bool isVisible;

  /// User-defined scale multiplier for labels/icons.
  ///
  /// This does not change zoom; it adjusts visual scale only.
  final double userScale;

  const AgusMap({
    super.key,
    this.initialLat,
    this.initialLon,
    this.initialZoom,
    this.onMapReady,
    this.controller,
    this.isVisible = true,
    this.userScale = 1.0,
  });

  @override
  State<AgusMap> createState() => _AgusMapState();
}

class _AgusMapState extends State<AgusMap> {
  int? _textureId;
  Size? _currentSize; // Logical size
  bool _surfaceCreated = false;
  double _devicePixelRatio = 1.0;
  double _userScale = 1.0;

  // Track pending resize to apply when becoming visible
  Size? _pendingResizeSize;
  double? _pendingResizePixelRatio;
  double? _pendingResizeUserScale;

  @override
  void initState() {
    super.initState();
    _ensureChannelInitialized();
  }

  @override
  void didUpdateWidget(AgusMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Apply pending resize when becoming visible
    if (widget.isVisible && !oldWidget.isVisible) {
      if (_pendingResizeSize != null && _pendingResizePixelRatio != null) {
        debugPrint('[AgusMap] Applying deferred resize on visibility change');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleResize(
            _pendingResizeSize!,
            _pendingResizePixelRatio!,
            _pendingResizeUserScale ?? widget.userScale,
          );
          _pendingResizeSize = null;
          _pendingResizePixelRatio = null;
          _pendingResizeUserScale = null;
        });
      }
    }
  }

  Future<void> _createSurface(
    Size logicalSize,
    double pixelRatio,
    double userScale,
  ) async {
    if (_surfaceCreated) return;
    _surfaceCreated = true;
    _devicePixelRatio = pixelRatio;
    _userScale = userScale;

    // Convert logical pixels to physical pixels for crisp rendering
    final physicalWidth = Platform.isWindows
        ? (logicalSize.width * pixelRatio).round()
        : (logicalSize.width * pixelRatio).toInt();
    final physicalHeight = Platform.isWindows
        ? (logicalSize.height * pixelRatio).round()
        : (logicalSize.height * pixelRatio).toInt();

    final visualScale = pixelRatio * userScale;
    debugPrint(
      '[AgusMap] Creating surface: ${logicalSize.width.toInt()}x${logicalSize.height.toInt()} logical, ${physicalWidth}x$physicalHeight physical (ratio: $pixelRatio, userScale: ${userScale.toStringAsFixed(2)}, visual: ${visualScale.toStringAsFixed(3)})',
    );
    if (Platform.isWindows) {
      debugPrint(
        '[AgusMap] Windows DPR diagnostic: logical=${logicalSize.width.toStringAsFixed(2)}x${logicalSize.height.toStringAsFixed(2)} '
        'dpr=${pixelRatio.toStringAsFixed(3)} userScale=${userScale.toStringAsFixed(2)} physical=${physicalWidth}x$physicalHeight',
      );
    }

    final textureId = await createMapSurface(
      width: physicalWidth,
      height: physicalHeight,
      density: visualScale,
    );

    if (!mounted) return;

    setState(() {
      _textureId = textureId;
      _currentSize = logicalSize;
    });

    // Set initial view if specified
    if (widget.initialLat != null && widget.initialLon != null) {
      setView(widget.initialLat!, widget.initialLon!, widget.initialZoom ?? 14);
    }

    widget.onMapReady?.call();
  }

  Future<void> _handleResize(
    Size newLogicalSize,
    double pixelRatio,
    double userScale,
  ) async {
    if (_currentSize == newLogicalSize &&
        _devicePixelRatio == pixelRatio &&
        _userScale == userScale) {
      return;
    }
    if (_textureId == null) return;

    _devicePixelRatio = pixelRatio;
    _userScale = userScale;

    // Convert logical pixels to physical pixels
    final physicalWidth = Platform.isWindows
        ? (newLogicalSize.width * pixelRatio).round()
        : (newLogicalSize.width * pixelRatio).toInt();
    final physicalHeight = Platform.isWindows
        ? (newLogicalSize.height * pixelRatio).round()
        : (newLogicalSize.height * pixelRatio).toInt();

    if (physicalWidth <= 0 || physicalHeight <= 0) return;

    final visualScale = pixelRatio * userScale;
    debugPrint(
      '[AgusMap] Resizing: ${newLogicalSize.width.toInt()}x${newLogicalSize.height.toInt()} logical, ${physicalWidth}x$physicalHeight physical (ratio: $pixelRatio, userScale: ${userScale.toStringAsFixed(2)}, visual: ${visualScale.toStringAsFixed(3)})',
    );
    if (Platform.isWindows) {
      debugPrint(
        '[AgusMap] Windows DPR diagnostic (resize): logical=${newLogicalSize.width.toStringAsFixed(2)}x${newLogicalSize.height.toStringAsFixed(2)} '
        'dpr=${pixelRatio.toStringAsFixed(3)} userScale=${userScale.toStringAsFixed(2)} physical=${physicalWidth}x$physicalHeight',
      );
    }

    await resizeMapSurface(physicalWidth, physicalHeight, density: visualScale);

    if (mounted) {
      setState(() {
        _currentSize = newLogicalSize;
      });
    }
  }

  // Track active pointers for multitouch
  final Map<int, Offset> _activePointers = {};

  void _handlePointerDown(PointerDownEvent event) {
    _activePointers[event.pointer] = event.localPosition;
    _sendTouchEvent(TouchType.down, event.pointer, event.localPosition);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    _activePointers[event.pointer] = event.localPosition;
    _sendTouchEvent(TouchType.move, event.pointer, event.localPosition);
  }

  void _handlePointerUp(PointerUpEvent event) {
    _sendTouchEvent(TouchType.up, event.pointer, event.localPosition);
    _activePointers.remove(event.pointer);
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _sendTouchEvent(TouchType.cancel, event.pointer, event.localPosition);
    _activePointers.remove(event.pointer);
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) return;
    if (_activePointers.isNotEmpty)
      return; // don't interfere with real drag/pinch

    if (event is PointerScrollEvent) {
      // Use direct scale API similar to Qt CoMaps implementation
      // Qt uses: factor = angleDelta.y() / 3.0 / 360.0, then exp(factor)
      // Flutter's scrollDelta.dy is typically ~100 per notch (platform-dependent)
      // We tune the divisor for a good zoom feel similar to Google Maps
      final dy = event.scrollDelta.dy;

      // Calculate zoom factor - larger divisor = slower zoom
      // 3.0 * 360.0 = 1080 matches Qt behavior
      // We use a slightly smaller value for faster, more responsive zoom
      final factor = -dy / 600.0; // Negative because scroll down = zoom out

      // Convert logical position to physical pixels
      final pixelX = event.localPosition.dx * _devicePixelRatio;
      final pixelY = event.localPosition.dy * _devicePixelRatio;

      // Apply exponential zoom factor for smooth, proportional zooming
      // exp(factor) ensures zoom rate is consistent regardless of current zoom level
      scaleMap(exp(factor), pixelX, pixelY, animated: false);
    }
  }

  void _sendTouchEvent(TouchType type, int pointerId, Offset position) {
    // Use cached pixel ratio for coordinate conversion (matches surface dimensions)
    final pixelRatio = _devicePixelRatio;

    // Convert logical coordinates to physical pixels
    final x1 = position.dx * pixelRatio;
    final y1 = position.dy * pixelRatio;

    // Check for second pointer (multitouch)
    int id2 = -1;
    double x2 = 0;
    double y2 = 0;

    for (final entry in _activePointers.entries) {
      if (entry.key != pointerId) {
        id2 = entry.key;
        x2 = entry.value.dx * pixelRatio;
        y2 = entry.value.dy * pixelRatio;
        break;
      }
    }

    sendTouchEvent(type, pointerId, x1, y1, id2: id2, x2: x2, y2: y2);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final pixelRatio = MediaQuery.of(context).devicePixelRatio;
        final userScale = widget.userScale;

        // Create surface on first layout (only if visible)
        if (!_surfaceCreated && size.width > 0 && size.height > 0) {
          if (widget.isVisible) {
            // Use post-frame callback to avoid calling during build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _createSurface(size, pixelRatio, userScale);
            });
          }
        } else if (_surfaceCreated &&
            (_currentSize != size ||
                _devicePixelRatio != pixelRatio ||
                _userScale != userScale)) {
          // Handle resize or pixel ratio change
          if (widget.isVisible) {
            // Apply resize immediately when visible
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _handleResize(size, pixelRatio, userScale);
            });
          } else {
            // Defer resize until visible to avoid unnecessary memory allocations
            // (e.g., keyboard open/close causing CVPixelBuffer recreation on iOS)
            _pendingResizeSize = size;
            _pendingResizePixelRatio = pixelRatio;
            _pendingResizeUserScale = userScale;
          }
        }

        if (_textureId == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return Listener(
          onPointerDown: _handlePointerDown,
          onPointerMove: _handlePointerMove,
          onPointerUp: _handlePointerUp,
          onPointerCancel: _handlePointerCancel,
          onPointerSignal: _handlePointerSignal,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: Texture(
              textureId: _textureId!,
              filterQuality:
                  Platform.isWindows ? FilterQuality.none : FilterQuality.low,
            ),
          ),
        );
      },
    );
  }
}

const String _libName = 'agus_maps_flutter';

/// The dynamic library in which the symbols for [AgusMapsFlutterBindings] can be found.
final DynamicLibrary _dylib = () {
  if (Platform.isMacOS) {
    return DynamicLibrary.open('$_libName.framework/$_libName');
  }
  if (Platform.isIOS) {
    // On iOS, the plugin is linked into the main executable
    // Use process() to look up symbols from the app itself
    return DynamicLibrary.process();
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();

/// The bindings to the native functions in [_dylib].
final AgusMapsFlutterBindings _bindings = AgusMapsFlutterBindings(_dylib);

/// A request to compute `sum`.
///
/// Typically sent from one isolate to another.
class _SumRequest {
  final int id;
  final int a;
  final int b;

  const _SumRequest(this.id, this.a, this.b);
}

/// A response with the result of `sum`.
///
/// Typically sent from one isolate to another.
class _SumResponse {
  final int id;
  final int result;

  const _SumResponse(this.id, this.result);
}

/// Counter to identify [_SumRequest]s and [_SumResponse]s.
int _nextSumRequestId = 0;

/// Mapping from [_SumRequest] `id`s to the completers corresponding to the correct future of the pending request.
final Map<int, Completer<int>> _sumRequests = <int, Completer<int>>{};

/// The SendPort belonging to the helper isolate.
Future<SendPort> _helperIsolateSendPort = () async {
  // The helper isolate is going to send us back a SendPort, which we want to
  // wait for.
  final Completer<SendPort> completer = Completer<SendPort>();

  // Receive port on the main isolate to receive messages from the helper.
  // We receive two types of messages:
  // 1. A port to send messages on.
  // 2. Responses to requests we sent.
  final ReceivePort receivePort = ReceivePort()
    ..listen((dynamic data) {
      if (data is SendPort) {
        // The helper isolate sent us the port on which we can sent it requests.
        completer.complete(data);
        return;
      }
      if (data is _SumResponse) {
        // The helper isolate sent us a response to a request we sent.
        final Completer<int> completer = _sumRequests[data.id]!;
        _sumRequests.remove(data.id);
        completer.complete(data.result);
        return;
      }
      throw UnsupportedError('Unsupported message type: ${data.runtimeType}');
    });

  // Start the helper isolate.
  await Isolate.spawn((SendPort sendPort) async {
    final ReceivePort helperReceivePort = ReceivePort()
      ..listen((dynamic data) {
        // On the helper isolate listen to requests and respond to them.
        if (data is _SumRequest) {
          final int result = _bindings.sum_long_running(data.a, data.b);
          final _SumResponse response = _SumResponse(data.id, result);
          sendPort.send(response);
          return;
        }
        throw UnsupportedError('Unsupported message type: ${data.runtimeType}');
      });

    // Send the port to the main isolate on which we can receive requests.
    sendPort.send(helperReceivePort.sendPort);
  }, receivePort.sendPort);

  // Wait until the helper isolate has sent us back the SendPort on which we
  // can start sending requests.
  return completer.future;
}();
