# Navigation Implementation Status

## Overview

This document tracks the implementation of full GPS navigation mode with voice guidance for the Rikera app.

## Completed Work

### 1. Native C++ Navigation Functions ✅

**Location**: `src/agus_maps_flutter.cpp`

Added the following native functions:

- `nativeGetRouteFollowingInfo()` - Returns JSON with real-time navigation data
- `nativeGenerateNotifications()` - Generates voice instruction strings
- `nativeIsRouteFinished()` - Checks if destination reached
- `nativeDisableFollowing()` - Stops following but keeps route visible
- `nativeRemoveRoute()` - Removes route completely

### 2. Android Method Channel Integration ✅

**Location**: `android/src/main/java/app/agus/maps/agus_maps_flutter/AgusMapsFlutterPlugin.java`

Added method declarations and handlers for all navigation methods.

### 3. Dart API Exposure ✅

**Location**: `lib/agus_maps_flutter.dart`

Exposed in `AgusMapController`:

- `getRouteFollowingInfo()` - Returns Map<String, dynamic> with navigation data
- `generateNotifications({bool announceStreets})` - Returns List<String> for TTS
- `isRouteFinished()` - Returns bool
- `disableFollowing()` - Stops following
- `removeRoute()` - Removes route

### 4. NavigationRepositoryImpl Integration ✅

**Location**: `rikera_app/lib/features/map/data/repositories/navigation_repository_impl.dart`

**Changes**:

- Added `AgusMapController?` field (nullable, set via `setMapController()`)
- Replaced mock calculations with native polling via `_pollNavigationState()`
- Polls `getRouteFollowingInfo()` every 1 second during navigation
- Checks `isRouteFinished()` to detect arrival
- Emits NavigationState with real native data

**Key Methods**:

- `setMapController()` - Injects controller from MapCubit
- `_startNavigationPolling()` - Starts 1-second timer
- `_pollNavigationState()` - Fetches data from native engine

### 5. VoiceGuidanceService Integration ✅

**Location**: `rikera_app/lib/core/services/voice_guidance_service.dart`

**Changes**:

- Added `AgusMapController?` field
- Added `_startNotificationPolling()` - Polls native notifications every 2 seconds
- Added `_pollNativeNotifications()` - Calls `generateNotifications()` and queues for TTS
- Integrated with existing TTS queue system

**Dependencies**: `flutter_tts` package (already in pubspec.yaml)

### 6. NavigationBloc Updates ✅

**Location**: `rikera_app/lib/features/map/presentation/blocs/navigation/navigation_bloc.dart`

**Changes**:

- Updated `_onStartNavigation()` to inject map controller into repository
- Casts repository to `NavigationRepositoryImpl` and calls `setMapController()`

### 7. NavigationEvent Updates ✅

**Location**: `rikera_app/lib/features/map/presentation/blocs/navigation/navigation_event.dart`

**Changes**:

- Added `AgusMapController? mapController` field to `StartNavigation` event
- Constructor now accepts optional `mapController` parameter

## Remaining Work

### 1. Wire MapController to Navigation Start 🔄

**What's needed**: Update the place where `StartNavigation` event is dispatched to pass the `mapController` from `MapCubit`.

**Current flow**:

1. User taps map → PlacePageSheet shows
2. User taps "IR AQUI (RUTA)" → `mapController.buildRoute()` called
3. Native engine builds route automatically
4. **MISSING**: Flutter side doesn't start NavigationBloc

**Solution needed**:

- Listen to route build completion in MapCubit
- Dispatch `StartNavigation` event with `mapController` when route is ready
- Navigate to NavigationScreen

**Possible approaches**:
a) Add a callback/stream in native for route build completion
b) Poll route status after `buildRoute()` is called
c) Add a method to check if route exists and start navigation manually

### 2. Map Style Switching 🔄

**What's needed**: Switch map to vehicle mode during navigation.

**Location**: `rikera_app/lib/features/map/presentation/blocs/map/map_cubit.dart`

**Implementation**:

```dart
// In MapCubit, when navigation starts:
setMapStyle(MapStyle.vehicleLight); // or vehicleDark based on theme
```

### 3. Testing & Debugging 🔄

**What's needed**:

- Test native navigation functions return correct data
- Test voice guidance speaks at appropriate times
- Test arrival detection works correctly
- Test off-route detection (if native supports it)
- Test route completion flow

### 4. UI Polish 🔄

**What's needed**:

- Ensure NavigationScreen displays native data correctly
- Add loading state while route is building
- Handle errors gracefully (no route found, etc.)
- Add button to manually start navigation if needed

## Architecture Summary

```
User Action (Tap "IR AQUI")
    ↓
mapController.buildRoute(lat, lon)
    ↓
Native CoMaps Engine
    ├─ Builds route
    ├─ Starts route following
    └─ Provides real-time data via:
        ├─ getRouteFollowingInfo() ← Polled by NavigationRepository
        ├─ generateNotifications() ← Polled by VoiceGuidanceService
        └─ isRouteFinished() ← Checked for arrival
    ↓
NavigationRepository (polls every 1s)
    ├─ Fetches navigation data
    ├─ Emits NavigationState
    └─ Detects arrival
    ↓
NavigationBloc
    ├─ Receives NavigationState
    ├─ Triggers voice guidance
    └─ Updates UI
    ↓
NavigationScreen (displays data)
    ├─ Turn instructions
    ├─ Distance/time remaining
    ├─ Speed display
    └─ Navigation controls
```

## Key Design Decisions

1. **Polling vs Events**: Using polling (1-2 second intervals) instead of native callbacks for simplicity. This is acceptable for navigation use case.

2. **Lazy Controller Injection**: MapController is injected into repositories when navigation starts, not at construction time. This avoids circular dependencies.

3. **Native-First Approach**: Relying on native CoMaps engine for route calculation, following, and turn detection. Flutter side just displays the data.

4. **Dual Voice System**: VoiceGuidanceService can use either:
   - Native notifications (via `generateNotifications()`) - preferred
   - Flutter-side turn detection (existing code) - fallback

## Next Steps (Priority Order)

1. **Add route build completion detection** - Critical for starting navigation
2. **Test native functions** - Verify data format and accuracy
3. **Wire up navigation start flow** - Connect buildRoute → StartNavigation
4. **Test end-to-end** - Full navigation session from start to finish
5. **Add map style switching** - Vehicle mode during navigation
6. **Polish UI** - Loading states, error handling, etc.

## Notes

- The native CoMaps engine already has full navigation capabilities
- Most of the heavy lifting (route following, turn detection, voice instructions) is done natively
- Flutter side is primarily for UI and coordination
- TTS package (`flutter_tts`) is already installed and configured
